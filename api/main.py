import os
from fastapi import FastAPI, Request, Form, HTTPException
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from contextlib import asynccontextmanager
from database.db import Database
from core.calculator import FundRatingCalculator

# Подключение к БД (для Railway используется переменная окружения)
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://postgres:12345@localhost:5432/grann"
)
db = Database(DATABASE_URL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    await db.connect()
    yield
    await db.close()


app = FastAPI(title="GrantFinder", lifespan=lifespan)
templates = Jinja2Templates(directory="templates")


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Главная страница с формой выбора параметров."""
    return templates.TemplateResponse("index.html", {"request": request})


@app.post("/result", response_class=HTMLResponse)
async def result(
    request: Request,
    scenario: str = Form(...),
    direction: str = Form(...)
):
    """Обработка формы и расчёт рейтинга."""
    try:
        weights = await db.get_criterion_weights(scenario)
        criteria_scores = await db.get_fund_criteria_scores()
        fund_profiles = await db.get_all_fund_profiles()
        funds = await db.get_all_funds()

        results = FundRatingCalculator.calculate_rating(
            funds, weights, criteria_scores, fund_profiles, direction
        )

        scenario_names = {'science': 'Наука', 'implementation': 'Внедрение'}
        direction_names = {
            'it': 'IT',
            'ecology': 'Экология',
            'chemistry': 'Химия / Материалы',
            'energy': 'Энергетика'
        }

        return templates.TemplateResponse("results.html", {
            "request": request,
            "scenario": scenario_names.get(scenario, scenario),
            "direction": direction_names.get(direction, direction),
            "results": results
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/fund/{fund_id}", response_class=HTMLResponse)
async def fund_page(request: Request, fund_id: int):
    """Страница конкретного фонда с конкурсами."""
    fund = await db.get_fund_by_id(fund_id)
    if not fund:
        raise HTTPException(status_code=404, detail="Фонд не найден")
    grants = await db.get_contests_by_fund(fund_id)
    return templates.TemplateResponse("fund.html", {
        "request": request,
        "fund_name": fund['name'],
        "grants": grants
    })