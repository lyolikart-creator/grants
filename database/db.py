import asyncpg
from typing import Dict, List, Any, Optional


class Database:
    def __init__(self, dsn: str):
        self.dsn = dsn
        self.pool: Optional[asyncpg.Pool] = None

    async def connect(self):
        self.pool = await asyncpg.create_pool(dsn=self.dsn, min_size=1, max_size=10)

    async def close(self):
        if self.pool:
            await self.pool.close()

    async def get_criterion_weights(self, mode_code: str) -> Dict[str, float]:
        """Загрузка весов критериев для выбранного режима."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT c.code, gw.weight
                FROM global_weights gw
                JOIN modes m ON gw.mode_id = m.id
                JOIN criteria c ON gw.criterion_id = c.id
                WHERE m.code = $1
            """, mode_code)
            return {row['code']: float(row['weight']) for row in rows}

    async def get_fund_criteria_scores(self) -> Dict[int, Dict[str, float]]:
        """Загрузка локальных приоритетов фондов по критериям."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT fcs.fund_id, c.code, fcs.local_priority
                FROM fund_criteria_scores fcs
                JOIN criteria c ON fcs.criterion_id = c.id
            """)
            scores: Dict[int, Dict[str, float]] = {}
            for row in rows:
                scores.setdefault(row['fund_id'], {})[row['code']] = float(row['local_priority'])
            return scores

    async def get_all_fund_profiles(self) -> Dict[int, str]:
        """Загрузка семантических профилей фондов."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch("SELECT fund_id, keywords FROM fund_profiles")
            return {row['fund_id']: row['keywords'] for row in rows}

    async def get_all_funds(self) -> List[Dict[str, Any]]:
        """Получение списка всех фондов."""
        async with self.pool.acquire() as conn:
            return [dict(r) for r in await conn.fetch("SELECT id, name FROM funds ORDER BY id")]

    async def get_fund_by_id(self, fund_id: int) -> Optional[Dict[str, Any]]:
        """Получение фонда по ID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow("SELECT id, name FROM funds WHERE id = $1", fund_id)
            return dict(row) if row else None

    async def get_contests_by_fund(self, fund_id: int) -> List[Dict[str, Any]]:
        """Получение актуальных конкурсов фонда (дедлайн в будущем)."""
        async with self.pool.acquire() as conn:
            rows = await conn.fetch("""
                SELECT id, title, min_funding, max_funding, deadline, application_link
                FROM contests
                WHERE fund_id = $1 AND deadline > CURRENT_DATE
                ORDER BY deadline ASC
            """, fund_id)
            return [dict(r) for r in rows]