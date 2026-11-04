# Еженедельный цикл (автоматический)

Каждый понедельник игра сама собирает цифры, а команда агентов их разбирает и предлагает план
на неделю. Владелец получает сводку и решает. Ничего не деплоится без его «да».

## Расписание (время Киев)
| Когда | Что | Кто |
| --- | --- | --- |
| Пн 07:17 | GitHub Actions `weekly-metrics`: `scripts/fetch_metrics.py` забирает метрики за 8 дней из Open Cloud Analytics Query API → `analytics/metrics.csv`; `scripts/metrics_report.py` → `analytics/REPORT.md`; коммит в `main` | бот |
| Пн 09:00 | Запланированная задача Claude «Недельный обзор игры»: свежая сессия клонирует репозиторий и выполняет шаги ниже | главный + агенты |
| Пн, когда удобно | Владелец читает сводку, отвечает «делаем 1 и 3» | владелец |

## Шаги задачи «Недельный обзор»
1. `gh repo clone vdmemory/sled-game`, прочитать `CLAUDE.md`, `docs/WEEKLY.md`, `analytics/REPORT.md`,
   `analytics/events.csv`, `docs/BUSINESS.md` §6 (гипотезы), `docs/IDEAS.md`, последние записи
   `docs/CHANGELOG.md`.
2. Если `REPORT.md` старше 3 дней или пустой — запустить `python3 scripts/metrics_report.py`; если
   метрик всё равно нет, в сводке так и сказать (workflow не настроен / нет трафика / API не дал
   доступ) и попросить владельца прислать скриншоты Analytics.
3. **`producer`**: прочитать отчёт, сравнить с целями и с прошлой неделей, найти узкое место
   воронки, проверить открытые гипотезы в `BUSINESS.md` §6 (сбылись/нет), предложить 3 ставки на
   неделю с ожидаемым эффектом. Обновить `BUSINESS.md` (журнал гипотез, раздел 7).
4. **`idea-scout`**: обзор `IDEAS.md` (что устарело, что подтверждают цифры), 15-минутный поиск
   новостей (DevForum Announcements, Release Notes, обновления топ-игр жанра) → 2–3 новые идеи с
   оценкой в `IDEAS.md`.
5. **`qa-tester`** (без управления компьютером — только статика): `luau-analyze` по `src/`,
   последний `gh run` зелёный, метрики стабильности из отчёта (крэши, FPS), открытые баги из
   прошлых отчётов. Если что-то красное — в сводку первым пунктом.
6. **`code-reviewer`**: техдолг недели — 1–2 пункта из `IDEAS.md`/ENGINEERING, которые дешевле
   всего закрыть сейчас.
7. Главный собирает **сводку владельцу** (≤ 20 строк): цифры недели (DAU, D1, сессия, R$, дельты),
   узкое место, 3 ставки продюсера, 2–3 идеи, красные флаги QA, вопросы владельцу. Отправить
   как сообщение сессии; закоммитить правки `BUSINESS.md`/`IDEAS.md` в `main` с сообщением
   «weekly: обзор <дата>». Строку «review» добавить в `analytics/events.csv`.
8. Код игры в этой задаче **не менять** и не деплоить. Реализация — после ответа владельца, в
   обычной сессии, через агентов.

## Что нужно один раз от владельца
- Ключ API с правом **universe-analytics → universe.analytics:read** на production-опыт →
  GitHub → Settings → Environments → production → secret `ROBLOX_ANALYTICS_KEY` (можно добавить
  право к существующему ключу и положить его же под этим именем). Ключ в чат не присылать.
- Создать `.github/workflows/weekly-metrics.yml` через веб GitHub из
  `scripts/weekly-metrics.yml.example` (у сессий Claude нет права на workflows). Проверить
  вручную: Actions → weekly-metrics → Run workflow.
- Analytics Query API в бете: если вернёт 403, доступа у аккаунта пока нет — тогда владелец
  раз в неделю присылает скриншоты Analytics, главный заносит их в CSV руками.

## Источники
- Open Cloud Analytics Query API: метрики и измерения —
  https://create.roblox.com/docs/cloud/guides/analytics/metrics ; эндпоинт
  `POST https://apis.roblox.com/analytics-query-api/v1/universes/{universeId}/metrics`, ключ
  `universe-analytics:read`, лимит 30 запросов/мин (DevForum, июль 2026:
  https://devforum.roblox.com/t/open-cloud-analytics-query-api-is-live-beta-%E2%80%94-tested-documented-with-a-client/4753664).
