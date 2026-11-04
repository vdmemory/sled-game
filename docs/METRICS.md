# Метрики и история

Одно место, где лежат цифры игры во времени и всё, что их объясняет. Читают `producer`,
`game-designer`, `idea-scout`; заполняет главный по данным владельца. Правило: **цифра без даты
и источника не записывается**; **каждое изменение игры — строка в журнале событий**, иначе
через месяц не понять, почему график дёрнулся.

## Где лежат данные
| Что | Где | Формат |
| --- | --- | --- |
| Снимки метрик по датам | `analytics/metrics.csv` | одна строка = один день (или неделя), колонки ниже |
| Журнал событий (релизы, реклама, ивенты, внешнее) | `analytics/events.csv` | дата, тип, описание, коммит/версия |
| Отчёт с трендами и дельтами | `python3 scripts/metrics_report.py` → `analytics/REPORT.md` | генерируется, не править руками |
| Гипотезы и их результат | `docs/BUSINESS.md` §6 | ставка → метрика → факт |
| Автосбор раз в неделю | `scripts/fetch_metrics.py` (Open Cloud Analytics Query API) из GitHub Actions `weekly-metrics` | см. `docs/WEEKLY.md` |
| Сырые данные Creator Hub | владелец присылает скриншоты/CSV из Analytics → `analytics/raw/<дата>/` | как есть |

## Колонки `metrics.csv`
`date` (YYYY-MM-DD), `period` (day/week), `visits`, `dau`, `ccu_peak`, `new_users`,
`d1`, `d7`, `d30` (доли 0–1), `session_min` (средняя сессия), `likes_pct`,
`robux_earned` (за период), `robux_creator_rewards`, `payers`, `conversion` (payers/dau),
`arpdau_usd` (= robux_earned × 0.7 × 0.0038 / dau; для Creator Rewards без 0.7),
`premium_playtime_score`, `source` (откуда цифры), `note`.
Пустая ячейка = не было данных; ноль пишется только как измеренный ноль.

## Откуда брать цифры (Creator Hub → твой опыт → Analytics)
- **Engagement:** Visits, DAU, Average Session Time, Concurrent Users.
- **Retention:** D1 / D7 / D30 по когортам (брать когорту, которой уже исполнился срок).
- **Monetization:** Robux earned (Passes, Products), Creator Rewards (Premium Playtime Score,
  Premium Visits), Paying users, ARPPU.
- **Acquisition:** источники трафика, CTR иконки (impressions → plays) в Sponsored.
- **Funnels:** онбординг (шаги ниже), **Economy:** источники/стоки монет и гемов, **Custom:**
  дистанции, финиши, сессии (события ниже).
Владелец присылает скриншоты или экспорт; главный переносит в CSV и запускает отчёт.

## События в игре (`src/server/Analytics.luau`, только на опубликованном плейсе)
| Вид | Имя | Смысл |
| --- | --- | --- |
| Onboarding funnel | 1 Joined → 2 FirstRun → 3 ThirdRun → 4 FirstUpgrade → 5 FinishedLevel → 6 World2 → 7 FirstPurchase | где отваливаются новички; шаг пишется один раз на игрока (`Stats.Onboard`) |
| Economy Source | Coins/Gems: `Run`/`Finish` (Gameplay), `Task`/`TaskChest`/`Gift`/`LobbyChest` (Reward) | откуда приходят валюты; поля: World, Level |
| Economy Sink | Coins/Gems: `Upgrade:<имя>`, `Sled:<id:редкость>`, `Trail:<id>` (Shop) | куда уходят; поле 3 — категория |
| Custom (значение) | `RunDistance`, `RunPercent`, `SessionMinutes`, `RobuxPurchase` | средние/суммы по дням |
| Custom (счётчик) | `RunFinished`, `RunCrashed`, `RunStopped` | исходы заездов → доля финишей |
Счётчики на игроке в сейве: `Stats = { Runs, Finishes, Onboard, Purchases, Playtime }`.

## Как читать (правила продюсера)
- Сравнивай с той же когортой и тем же днём недели; выходные ≠ будни.
- Изменение < 10% при DAU < 500 — шум. Решение принимается по тренду 7–14 дней, не по дню.
- Любой скачок ищи в `events.csv` (релиз, реклама, фича Discovery, праздник, падение Roblox).
- Retention важнее дохода, пока DAU < 1000; доля финишей по мирам показывает, где сложность
  ломает игроков; Economy Sink без Source рядом — игрок копит и не тратит (нечего купить).
- Онбординг: падение > 30% между соседними шагами — задача недели.

## История (кратко; детали в CSV и CHANGELOG)
| Дата | Что | Эффект |
| --- | --- | --- |
| 2026-10 | MVP, staging/production-пайплайн, миры 1–3 | — |
| 2026-11-01…04 | 7 миров, 9 саней, бонусы, 25 заданий, тиры с визуалом, панель DEV, настройка на лету, UI с 3D-иконками | игра не опубликована публично, трафика нет |
| 2026-11-05 | аналитика событий в игре (этот документ), команда агентов, плейбук | ждём первых данных после публикации |
