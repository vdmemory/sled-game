# Sled Game — правила работы в репозитории

Roblox-игра «на санях» (по мотивам мобильной Sled Surfers). Всё делается кодом: Luau в `src/` →
Rojo → GitHub Actions → Open Cloud. Push в `main` = деплой на staging, тег `v*` = production.
Язык общения, кода-комментариев и документации — русский.

## Команда агентов — кого звать

Запрос владельца сначала разбирается на части, каждая часть уходит профильному агенту
(`.claude/agents/`). Если запрос целиком про одну область — один агент. Если про несколько —
несколько параллельно, затем `code-reviewer`, затем `qa-tester`.

| Про что запрос | Агент | Его файлы |
| --- | --- | --- |
| Трассы, треки, участки, повороты, обрывы, дороги/трафик, миры как ландшафт, препятствия, расстановка бонусов на трассе, лобби как место | `track-architect` | `server/Track.luau`, `server/Props.luau`, `Config` (раздел ТРАССА, THEMES) |
| Правила игры, прогрессия, экономика, цены, апгрейды и тиры, бонусы и их шансы, задания, подарки, сундуки, монетизация, баланс, «как должно работать» | `game-designer` | `Config.luau` (баланс), `server/Rewards.luau`, `server/DataService.luau`, `server/Main.server.luau` (правила), `docs/GAME_DESIGN.md` |
| Внешний вид: 3D-модели (сани, ракеты, рогатка, пропсы), UI/UX (окна, HUD, кнопки, иконки), эффекты, свет, пейзаж, анимации, звук | `art-director` | `shared/SledModels.luau`, `shared/UIKit.luau`, `client/HUD`, `client/LobbyMenus`, `client/Effects`, `client/Reveal`, `client/Sounds`, `assets/ui` |
| Проверить, протестировать, пройти трассу, найти баги, оценить сложность/скорость/плотность препятствий, «почему не работает», FPS на телефоне | `qa-tester` | играет на staging через компьютер владельца; `docs/TESTING.md` |
| Код-ревью, архитектура, структура модулей, деплой, CI, DataStore/ремоуты/безопасность, производительность, «сделай правильно» | `code-reviewer` | всё `src/`, `scripts/`, `default.project.json`, `docs/ARCHITECTURE.md` |

Примеры разбора:
- «Добавь мир с водопадами» → `track-architect` (участки, пропсы) + `art-director` (вид, свет) →
  `game-designer` (куда в прогрессию, награды) → `code-reviewer` → `qa-tester`.
- «Слишком сложно на 8 уровне» → `qa-tester` (замерить) → `game-designer` (решение) →
  `track-architect` (правка генерации).
- «Кнопка вылезает за рамки» → `art-director`.
- «Сделай новое средство передвижения» → `game-designer` (место в экономике) + `art-director`
  (модель, обвес по тирам) → `qa-tester`.
- «Хочу такую же игру на воде» → `docs/PLAYBOOK.md`, затем агенты по разделам плейбука.

Агенты не спорят с решениями владельца из `docs/GAME_DESIGN.md` → «Решения владельца»; если
решение надо изменить — спрашивают.

## Обязательные правила

- **Документация с каждым изменением:** `docs/CHANGELOG.md` всегда; `docs/GAME_DESIGN.md` при
  смене правил/механик; `docs/ARCHITECTURE.md` при смене устройства (модули, ремоуты, данные);
  `docs/PLAYBOOK.md` если меняется то, что нужно знать при создании похожей игры.
- **Все числа — в `src/shared/Config.luau`**, не в коде модулей. Новый параметр баланса сразу
  добавляется в `Config.TUNABLES` (панель владельца «Настройка»).
- **Синтаксис перед пушем:** `luau-compile --null <файл>` (или `luau-analyze`) для каждого
  изменённого `.luau`.
- **После пуша дождаться деплоя** (`gh run list`, ~2 мин) и проверить в игре, если изменение
  видно глазами. Старые серверы живут ~30–45 с после деплоя.
- **`.github/workflows` не трогать** из сессии (нет scope `workflow`) — правки только через веб
  GitHub руками владельца. Загрузка ассетов делается внутри `scripts/publish.sh`.
- **Секреты:** `ROBLOX_API_KEY` никогда не читать, не печатать, не просить прислать. Владелец сам
  кладёт ключи в GitHub Secrets.
- **Владелец решает:** покупки за Robux, возрастная верификация, трата игровых монет на тестовом
  аккаунте — только с явного согласия. Управление компьютером — только после его разрешения,
  после работы освобождать контроль и блокировку.
- **Владелец в игре:** `player.UserId == game.CreatorId` — панель DEV, `DevAction`, «ТЕСТ МИРА».

## Карта проекта

| Папка | В игре | Что там |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (баланс, TUNABLES), `UIKit` (стиль UI, иконки), `SledModels` (сани, ракеты, рогатка, обвес тиров), `UIDecals` (генерируется) |
| `src/server` | `ServerScriptService.Server` | `Main.server` (игроки, заезды, ремоуты, DevAction), `Track` (генерация трассы, лобби), `Props` (модели ландшафта/препятствий), `DataService` (DataStore), `Rewards` (задания, подарки, сундук), `Tuning` (настройки на лету), `UIImages.server` (декали → картинки) |
| `src/client` | `StarterPlayerScripts.Client` | `SledController` (физика и ввод), `HUD`, `LobbyMenus`, `DevPanel` (владелец), `Effects`, `Sounds`, `Traffic`, `Reveal`, `ConfigSync` |
| `assets/ui` | Decal-ы в Roblox | 50 иконок Fluent Emoji 3D (MIT), `decals.json` |
| `scripts` | CI | `publish.sh` (сборка, загрузка иконок, публикация), `upload_ui_assets.py` |
| `docs` | — | `GAME_DESIGN`, `ARCHITECTURE`, `PLAYBOOK` (как сделать похожую игру), `TEAM` (роли агентов), `TESTING`, `CHANGELOG` |

Подробности: `docs/ARCHITECTURE.md`. Как собрать такую же игру на воде или суше: `docs/PLAYBOOK.md`.
