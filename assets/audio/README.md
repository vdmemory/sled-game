# Звуки игры — источники и лицензии

| Файл | Что | Источник | Лицензия |
| --- | --- | --- | --- |
| `sfx_atlas_v2.ogg` | все 43 эффекта и лупа одним файлом (81 с, mono 44.1 кГц, Vorbis q6, ~810 КБ) | собирает `scripts/gen_audio.py` из записей `sources/` + немного синтеза | см. ниже (CC0 + CC BY 4.0) |
| `atlas.json` | карта кусков: имя → начало, длина, луп, источник, пик и RMS после кодирования, описание | генерирует `gen_audio.py` | — |
| `audio.json` | ID загруженных атласов и sha файла (`sfx_atlas` — v1, синтез, ID 85020498524123; `sfx_atlas_v2`) | пишет `scripts/upload_audio.py` при деплое | — |
| `preview.png` | сводка: волна (линия −1 dBFS) и спектрограмма каждого звука | `gen_audio.py --preview` | — |
| `sources/` | исходные записи (только те, что идут в атлас, 66 файлов, 1.8 МБ) | см. таблицу | см. таблицу |

## Исходные записи (`sources/`)

| Папка | Что | Автор, откуда | Лицензия |
| --- | --- | --- | --- |
| `kenney/` | удары (дерево, доска, металл, стекло, мягкий удар, «панч»), шаги по снегу; монеты в ладони, скрипы, щелчок металла | Kenney («Impact Sounds», «RPG Audio»), kenney.nl; копии: github.com/Boyquotes/kenney-impact-sounds-for-godot, github.com/ismetcabbar9-oss/kenney-audio-assets | **CC0 1.0** |
| `oculus/` | снег (шаги/бег/приземление), бетон, UI-набор Casual, «бель-три», уведомление, стингеры (Level Up / Victory: маримба, оркестр), монета, стекло, магия, пауэр-апы, бульканье, вуши, «бойнг», волочение доски, мотор машины, проезд электрички (отрезок 9–18 с) | **Oculus Audio Pack 1** © 2015 Oculus VR, LLC; github.com/facebookincubator/Meta-open-sound (`corpora/oculus-audio-pack`) | **CC BY 4.0** — нужна строка в титрах (ниже) |
| `freesound/` | ветер: «Wind on bushes with muffled gust of wind…», отрезок 1:48–2:04 | **felix.blume**, freesound.org/s/711106 (через github.com/funcoder/omarchy-ambient, CREDITS.md) | **CC0 1.0** |

**Строка в титрах (обязательна для CC BY 4.0)** — в описание игры / окно «Об игре»:
> Sound effects: Oculus Audio Pack 1 © 2015 Oculus VR, LLC (CC BY 4.0, creativecommons.org/licenses/by/4.0), modified; Kenney (CC0); felix.blume / Freesound (CC0).

Изменения (для CC BY — указать, что изменено): обрезка, фильтры, смена скорости, микширование, грануляция
(лупы снега/льда/асфальта/скрипа собраны из сотен коротких кусочков записей), нормализация, моно 44.1 кГц.

Синтез (numpy/scipy, свой, CC0) остался: `reveal` (райзер нового тира), свист в `fall`, `rocket_on`/`rocket_off`,
`horn`, низ/треск лупа `rocket` и тонкий слой «звона» поверх записей `coin`, `gem`, `ring`, `buy`.

## Что смотрели и почему так
- **Roblox Creator Store (аудио «by Roblox»)** — лучший вариант по лимиту (играют в любой игре по ID, без
  загрузки), но из сессии агента Roblox-домены закрыты (create.roblox.com, apis.roblox.com toolbox,
  economy) — проверить ID нельзя, а непроверенный ID = тишина. Поэтому: `Config.SOUND.library` — событие →
  ID; владелец находит звук в Creator Store (Studio → Toolbox → Audio, фильтр создателя Roblox), вписывает
  ID и слушает в DEV → «Звуки» (источник «Roblox ID»). Загрузка аудио не тратится.
- **CC0/CC BY записи, доступные через GitHub** — Kenney (CC0), Oculus Audio Pack (CC BY 4.0, через Meta
  Open Sound), Freesound CC0 (через omarchy-ambient). OpenGameArt, Freesound, Sonniss напрямую из сессии
  недоступны. Отклонены: `Lucassnam/skiing-sound` (записи из YouTube/Pixabay — лицензия не CC0).

## Встроенные звуки клиента
`rbxasset://sounds/*` (`button.wav`, `electronicpingshort.wav`, `action_jump.mp3` …) — только запасной
вариант, пока атлас не загружен или на модерации (`client/Sounds` → `FALLBACK`). Музыка — `Config.MUSIC_IDS`
(ID из ранней версии игры; источник и лицензия в репозитории не записаны — играют, только если Roblox
разрешает их нашему месту, иначе тихая «музыкальная шкатулка»).

## Как поменять звук
1. Правка в `scripts/gen_audio.py` (каждый звук — `add(имя, сигнал, описание, источник)`; записи — `o()`/`k()`/`rec()`).
2. `python3 scripts/gen_audio.py --preview` → атлас, `atlas.json`, `src/shared/AudioIds.luau`
   (`atlas = 0`, пока новый файл не загружен), `preview.png`.
3. Новое событие: громкость/канал/копии — `Config.SOUND.sfx` (+ строка TUNABLES «Звук: события»), вызов —
   `controller.Sfx:Fire("имя")`, в DEV → «Звуки» — в `SOUND_GROUPS`.
4. Пуш → `scripts/publish.sh` → `upload_audio.py` загрузит новый атлас (новый ассет: аудио в Roblox не
   обновляются) → ID в лог между `AUDIO_IDS_JSON_BEGIN/END` — закоммитить `audio.json` + `AudioIds.luau`.
   **Каждая пересборка с другим sha = одна загрузка из лимита** — сначала слушать локально.

## Ограничения загрузки (create.roblox.com/docs/audio/assets, /docs/cloud/guides/usage-assets)
- .ogg/.mp3/.wav/.flac, < 20 МБ, ≤ 7 мин, ≤ 48 кГц, mono/stereo; аудио проходит модерацию.
- Через Open Cloud: **10 аудио в месяц без ID-верификации, 100 — с ней**; поэтому все звуки — один файл.
  Генератор детерминирован (seed + bitexact Ogg): без правок sha не меняется и повторной загрузки нет.
  Ноябрь 2026: использовано 1 (v1) + 1 при деплое v2.
- Права ключа `ROBLOX_API_KEY`: Assets API → `asset:read` + `asset:write` (те же, что у иконок и мешей).
