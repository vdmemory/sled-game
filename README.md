# Sled Game — стартовый проект для Roblox

> Документация: [docs/](docs/README.md) — геймдизайн, архитектура, журнал изменений.


Бесконечный спуск на санках по процедурной трассе: уворачиваешься от камней и ёлок,
прыгаешь с трамплинов, крутишь флипы ради буста, получаешь монеты и качаешь санки.
Мультиплеер — все едут по одной трассе одновременно, рекорды в лидерборде.

## Что уже есть

| Система | Файл |
|---|---|
| Все настройки (уклон, скорость, цены, ID геймпасса) | `src/shared/Config.luau` |
| Бесконечная трасса, препятствия, трамплины, лобби | `src/server/TrackGenerator.luau` |
| Сохранение прогресса (DataStore) | `src/server/DataService.luau` |
| Заезды, монеты, апгрейды, антиспам, лидерборд | `src/server/Main.server.luau` |
| Управление санками и флипы (ПК, геймпад, мобильные) | `src/client/SledController.client.luau` |
| Интерфейс | `src/client/HUD.client.luau` |

**Управление:** A/D или стрелки — руль, пробел в воздухе — флип (держать). На телефоне — стик и кнопка «Флип».

---

## Настройка (один раз)

### 1. Инструменты
1. Установи **Roblox Studio** (create.roblox.com) и войди в аккаунт.
2. Установи **VS Code** + расширение **Luau Language Server** (JohnnyMorganz) — автодополнение Roblox API.
3. Установи **Rokit** (менеджер инструментов): github.com/rojo-rbx/rokit — инструкция в README.
4. В папке проекта:
   ```bash
   rokit install        # поставит Rojo из rokit.toml
   rojo --version
   ```
   Можно обновить версию Rojo в `rokit.toml` до последней с github.com/rojo-rbx/rojo/releases.
5. Плагин Rojo для Studio: `rojo plugin install` (или из Creator Store).

### 2. Подключение к Studio
1. Studio → New → **Baseplate**. Сам Baseplate можно удалить — он далеко внизу и не мешает.
2. Сразу **File → Publish to Roblox** (без публикации не работает DataStore).
3. **Home → Game Settings → Security → Enable Studio Access to API Services** — включить.
4. В терминале: `rojo serve`
5. В Studio: вкладка **Plugins → Rojo → Connect**. Код синхронизируется при каждом сохранении в VS Code.
6. Если `FallenPartsDestroyHeight` не применился — выдели **Workspace** и поставь вручную **-50000**
   (трасса уходит вниз, без этого санки исчезнут на ~2.5 км).

### 3. Тест
- **Play (F5)** — одиночный тест.
- **Test → Clients and Servers → 2–3 игрока** — проверить мультиплеер.
- Ошибки смотри в **View → Output**.

### Без Rojo (быстро попробовать)
Создай вручную и вставь код:
- `ReplicatedStorage` → Folder `Shared` → ModuleScript `Config`
- `ServerScriptService` → Folder `Server` → Script `Main`, ModuleScript `TrackGenerator`, ModuleScript `DataService`
- `StarterPlayer/StarterPlayerScripts` → Folder `Client` → LocalScript `SledController`, LocalScript `HUD`

---

## Автодеплой без Studio (CI/CD)

Схема: `git push` → GitHub Actions → `rojo build` → Open Cloud API → игра обновлена.
Весь мир игры (трасса, лобби, UI) создаётся кодом, поэтому .rbxl полностью собирается из репозитория.

**Важно:** каждый деплой заменяет плейс целиком. Всё, что сделано руками в Studio
и не лежит в репозитории, будет перезаписано. Модели и карты храни в репо
(`.rbxm`-файлы в `src/` или ссылки на ассеты из Creator Store).

### Один раз
1. **Создай 2 опыта** в Creator Hub (или в Studio): `Sled Game` (production) и `Sled Game [TEST]` (staging).
   Этот шаг единственный, где может понадобиться Studio: API обновляет только уже существующие плейсы.
2. Запиши **Universe ID** и **Place ID** каждого: Creator Hub → опыт → меню «⋯» → Copy Universe ID / Copy Start Place ID.
3. **API-ключ**: Creator Hub → Open Cloud → API Keys → Create API Key
   - Access Permissions → **universe-places** → выбери оба опыта → операция **Write**
   - Accepted IP Addresses: `0.0.0.0/0` (у GitHub-раннеров динамические IP)
   - Задай срок действия и запомни, когда его продлевать.
4. **GitHub** → репозиторий → Settings → Environments → создай `staging` и `production`:
   - Secret `ROBLOX_API_KEY` — ключ
   - Variables `UNIVERSE_ID` и `PLACE_ID` — ID соответствующего опыта
   - Для `production` включи **Required reviewers** — ручное подтверждение перед релизом.

### Ежедневная работа
```bash
git push                          # → сборка и деплой в staging, проверяешь в тестовом опыте
git tag v0.1.0 && git push --tags # → релиз в production
```
Локально (без GitHub):
```bash
rojo build -o game.rbxl
ROBLOX_API_KEY=... UNIVERSE_ID=... PLACE_ID=... ./scripts/publish.sh game.rbxl
```

### Ограничения API
- Не обновляет плейсы с `PartOperation` (Union/Negate), `SurfaceAppearance`, `EditableImage/Mesh`, `BaseWrap`.
  Если они появятся — заменяй их на MeshPart или грузи как ассеты.
- Настройки опыта (название, иконка, цены геймпассов) API не меняет, они в Creator Hub.

---

## Если что-то не так

- **Трамплин стоит стенкой к игроку** — в `TrackGenerator.luau` в `addRamp` убери `* CFrame.Angles(0, math.pi, 0)`.
- **Слишком быстро/медленно** — `BASE_SPEED`, `ACCELERATION`, `SLOPE_DEG` в `Config.luau`.
- **Слишком сложно в начале** — увеличь `SAFE_SEGMENTS`, уменьши число препятствий в `buildSegment`.
- **Выкидывает из санок** — проверь, что в Output нет ошибок от `SledController`.

---

## Монетизация

1. Creator Hub → твой опыт → **Monetization → Passes** → создай «x2 монеты», поставь цену.
2. ID пасса впиши в `Config.GAMEPASS_X2_COINS`. Начисление x2 уже работает.
3. Кнопку покупки в UI: `MarketplaceService:PromptGamePassPurchase(player, id)`.

Дальше: VIP-санки и трейлы (геймпассы), паки монет (Developer Products + `ProcessReceipt`).
Без энергии и таймеров — это главная претензия к мобильному оригиналу.

## Публикация
1. Game Settings → Basic Info: название, описание, жанр; иконка и 3+ скриншота/видео.
2. Пройди **Experience Questionnaire** (возрастной рейтинг) — без него игра не попадёт в выдачу.
3. Permissions → Public.
4. Первый трафик: Ads Manager (спонсорство), TikTok/Shorts с геймплеем, Discord-группа.

## Роадмап после MVP
1. **Монетки на трассе** — подбираемые, рядами (сильно улучшает «ощущение»).
2. **Скины санок/персонажа** — магазин за монеты и Robux.
3. **Ребёрты** — сброс апгрейдов за постоянный множитель монет.
4. **Ежедневные задания и награда за вход.**
5. **Биомы** — лес → лёд → пещеры по мере дистанции (меняй цвета/материалы по индексу сегмента).
6. **Звук и эффекты** — снежная пыль (ParticleEmitter), свист ветра от скорости, камера с FOV по скорости.
7. **ProfileStore** вместо голого DataStore — защита от потери данных и дюпа.
8. **Античит** — проверка скорости на сервере (клиент владеет физикой санок).
