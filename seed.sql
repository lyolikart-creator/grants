-- ==========================================
-- СОЗДАНИЕ ТАБЛИЦ
-- ==========================================

CREATE TABLE IF NOT EXISTS funds (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

CREATE TABLE IF NOT EXISTS criteria (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS modes (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE IF NOT EXISTS contests (
    id SERIAL PRIMARY KEY,
    fund_id INTEGER NOT NULL REFERENCES funds(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    min_funding DECIMAL(12,2),
    max_funding DECIMAL(12,2),
    application_link VARCHAR(500),
    deadline DATE,
    CONSTRAINT chk_funding_range CHECK (min_funding <= max_funding)
);

CREATE TABLE IF NOT EXISTS fund_profiles (
    fund_id INTEGER PRIMARY KEY REFERENCES funds(id) ON DELETE CASCADE,
    keywords TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS global_weights (
    mode_id INTEGER NOT NULL REFERENCES modes(id) ON DELETE CASCADE,
    criterion_id INTEGER NOT NULL REFERENCES criteria(id) ON DELETE CASCADE,
    weight DECIMAL(5,4) NOT NULL,
    PRIMARY KEY (mode_id, criterion_id),
    CONSTRAINT chk_weight_range CHECK (weight >= 0 AND weight <= 1)
);

CREATE TABLE IF NOT EXISTS fund_criteria_scores (
    fund_id INTEGER NOT NULL REFERENCES funds(id) ON DELETE CASCADE,
    criterion_id INTEGER NOT NULL REFERENCES criteria(id) ON DELETE CASCADE,
    local_priority DECIMAL(5,4) NOT NULL,
    PRIMARY KEY (fund_id, criterion_id),
    CONSTRAINT chk_priority_range CHECK (local_priority >= 0 AND local_priority <= 1)
);

-- Индекс для оптимизации фильтрации по дедлайну
CREATE INDEX IF NOT EXISTS idx_contests_fund_deadline
ON contests (fund_id, deadline);

-- ==========================================
-- ЗАПОЛНЕНИЕ СПРАВОЧНИКОВ
-- ==========================================

INSERT INTO funds (name, description) VALUES
('Российский научный фонд', 'Поддержка фундаментальных и поисковых научных исследований'),
('Фонд содействия инновациям', 'Поддержка малых инновационных предприятий и прикладных разработок'),
('Минобрнауки РФ', 'Государственные программы развития науки и технологического сотрудничества'),
('Фонд Потанина', 'Поддержка образования, социальных проектов и талантливых специалистов'),
('РФРИТ', 'Развитие отечественных IT-технологий и цифровых решений')
ON CONFLICT (name) DO NOTHING;

INSERT INTO criteria (code, name) VALUES
('publ', 'Публикации'),
('nov', 'Новизна'),
('comm', 'Коммерциализация'),
('part', 'Партнерство'),
('reporting', 'Отчетность')
ON CONFLICT (code) DO NOTHING;

INSERT INTO modes (code, name) VALUES
('science', 'Наука'),
('implementation', 'Внедрение')
ON CONFLICT (code) DO NOTHING;

-- ==========================================
-- ВЕСА КРИТЕРИЕВ (AHP)
-- ==========================================

INSERT INTO global_weights (mode_id, criterion_id, weight)
SELECT m.id, c.id, w FROM modes m CROSS JOIN criteria c,
LATERAL (VALUES
    ('science', 'publ', 0.35), ('science', 'nov', 0.30), ('science', 'comm', 0.10),
    ('science', 'part', 0.10), ('science', 'reporting', 0.15),
    ('implementation', 'publ', 0.10), ('implementation', 'nov', 0.15),
    ('implementation', 'comm', 0.35), ('implementation', 'part', 0.25),
    ('implementation', 'reporting', 0.15)
) AS v(mc, cc, w)
WHERE m.code = v.mc AND c.code = v.cc
ON CONFLICT (mode_id, criterion_id) DO UPDATE SET weight = EXCLUDED.weight;

-- ==========================================
-- ЛОКАЛЬНЫЕ ПРИОРИТЕТЫ ФОНДОВ (AHP)
-- ==========================================

INSERT INTO fund_criteria_scores (fund_id, criterion_id, local_priority)
SELECT f.id, c.id, p FROM funds f CROSS JOIN criteria c,
LATERAL (VALUES
    (1,'publ',0.30),(1,'nov',0.35),(1,'comm',0.10),(1,'part',0.15),(1,'reporting',0.10),
    (2,'publ',0.15),(2,'nov',0.10),(2,'comm',0.35),(2,'part',0.25),(2,'reporting',0.15),
    (3,'publ',0.25),(3,'nov',0.20),(3,'comm',0.20),(3,'part',0.20),(3,'reporting',0.15),
    (4,'publ',0.10),(4,'nov',0.05),(4,'comm',0.20),(4,'part',0.30),(4,'reporting',0.35),
    (5,'publ',0.20),(5,'nov',0.15),(5,'comm',0.30),(5,'part',0.20),(5,'reporting',0.15)
) AS v(fid, cc, p)
WHERE f.id = v.fid AND c.code = v.cc
ON CONFLICT (fund_id, criterion_id) DO UPDATE SET local_priority = EXCLUDED.local_priority;

-- ==========================================
-- СЕМАНТИЧЕСКИЕ ПРОФИЛИ ФОНДОВ (TF-IDF)
-- ==========================================

INSERT INTO fund_profiles (fund_id, keywords) VALUES
(5, 'IT информационные технологии разработка ПО цифровизация цифровые продукты гранты внедрение отечественных ИТ-решений'),
(1, 'научные исследования фундаментальные исследования поисковые исследования химия энергетика экология публикации лаборатории экспериментальная база'),
(2, 'инновации стартапы малые предприятия коммерциализация научных разработок прототипы патенты высокотехнологичные отрасли'),
(3, 'образование наука молодёжь научные исследования государственные программы федеральные проекты инфраструктура исследований экология энергетика'),
(4, 'образование молодёжь развитие навыки социальные проекты стипендии культурные инициативы стипендиаты преподаватели студенты')
ON CONFLICT (fund_id) DO UPDATE SET keywords = EXCLUDED.keywords;

-- ==========================================
-- КОНКУРСЫ (актуальные на 2026 год)
-- ==========================================

-- РНФ (fund_id = 1)
INSERT INTO contests (fund_id, title, min_funding, max_funding, application_link, deadline) VALUES
(1, 'Конкурс малых отдельных научных групп', 1000000, 1500000, 'https://rscf.ru/competitions/', '2026-06-16'),
(1, 'Региональный конкурс малых отдельных научных групп', 1000000, 1500000, 'https://rscf.ru/competitions/', '2026-09-15'),
(1, 'Региональный конкурс отдельных научных групп', 2000000, 3500000, 'https://rscf.ru/competitions/', '2026-09-15'),
(1, 'Конкурс отдельных научных групп', 4000000, 7000000, 'https://rscf.ru/competitions/', '2026-10-15')
ON CONFLICT DO NOTHING;

-- ФСИ (fund_id = 2)
INSERT INTO contests (fund_id, title, min_funding, max_funding, application_link, deadline) VALUES
(2, 'Развитие-ИИ (очередь 3)', 1000000, 30000000, 'https://fasie.ru/development/ai/', '2026-07-20'),
(2, 'Коммерциализация-Станкостроение', 1000000, 300000000, 'https://fasie.ru/development/commercialization/', '2026-06-29')
ON CONFLICT DO NOTHING;

-- Минобрнауки РФ (fund_id = 3)
INSERT INTO contests (fund_id, title, min_funding, max_funding, application_link, deadline) VALUES
(3, 'Научные исследования совместно с организациями стран БРИКС', 1000000, 10000000, 'https://minobrnauki.gov.ru/', '2026-06-19'),
(3, 'Флагманские проекты совместно с организациями БРИКС', 1000000, 10000000, 'https://minobrnauki.gov.ru/', '2026-06-19')
ON CONFLICT DO NOTHING;

-- Фонд Потанина (fund_id = 4)
INSERT INTO contests (fund_id, title, min_funding, max_funding, application_link, deadline) VALUES
(4, 'Профессиональное развитие (Институциональный опыт)', 100000, 1000000, 'https://potaninfund.ru/competitions/professional-development/', '2026-12-31'),
(4, 'Профессиональное развитие (Индивидуальная траектория)', 50000, 300000, 'https://potaninfund.ru/competitions/professional-development/', '2026-12-31')
ON CONFLICT DO NOTHING;

-- РФРИТ (fund_id = 5)
INSERT INTO contests (fund_id, title, min_funding, max_funding, application_link, deadline) VALUES
(5, 'Гранты на внедрение российских ИТ-решений', 100000000, 2000000000, 'https://rfrit.ru/measures/it-solutions/', '2026-12-31')
ON CONFLICT DO NOTHING;