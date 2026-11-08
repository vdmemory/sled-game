# Звуки игры — источники и лицензии

| Файл | Что | Источник | Лицензия |
| --- | --- | --- | --- |
| `sfx_atlas.ogg` | все 43 звуковых эффекта и лупа одним файлом (41 с, mono 44.1 кГц, Vorbis q6, ~360 КБ) | синтезирован кодом `scripts/gen_audio.py` (numpy/scipy, без сэмплов) | собственный, CC0 |
| `atlas.json` | карта кусков: имя → начало, длина, луп, пик после кодирования, описание | генерирует `gen_audio.py` | — |
| `audio.json` | ID загруженного атласа и sha файла (`{"sfx_atlas": {"id", "sha"}}`) | пишет `scripts/upload_audio.py` при деплое | — |
| `preview.png` | сводка: волна (линия −1 dBFS) и спектрограмма каждого звука | `gen_audio.py --preview` | — |

Встроенные звуки клиента Roblox (`rbxasset://sounds/*`: `button.wav`, `electronicpingshort.wav`,
`action_jump.mp3`, `action_falling.ogg` …) — только запасной вариант, пока атлас не загружен или на
модерации (`client/Sounds` → `FALLBACK`). Музыка — `Config.MUSIC_IDS` (ID из ранней версии игры; источник
и лицензия в репозитории не записаны — играют только если Roblox разрешает их нашему месту, иначе
«музыкальная шкатулка» из встроенного звука). Своих треков пока нет.

## Как поменять звук
1. Правка в `scripts/gen_audio.py` (каждый звук — одна функция `add(имя, сигнал, описание)`).
2. `python3 scripts/gen_audio.py --preview` → атлас, `atlas.json`, `src/shared/AudioIds.luau`
   (`atlas = 0`, пока новый файл не загружен), `preview.png` — посмотреть волны/спектр.
3. Новое событие: громкость/канал/копии — `Config.SOUND.sfx`, вызов — `controller.Sfx:Fire("имя")`.
4. Пуш → `scripts/publish.sh` → `upload_audio.py` загрузит новый атлас (новый ассет: аудио в Roblox не
   обновляются) → ID в лог между `AUDIO_IDS_JSON_BEGIN/END` — закоммитить `audio.json` + `AudioIds.luau`.

## Ограничения загрузки (create.roblox.com/docs/audio/assets, /docs/cloud/guides/usage-assets)
- .ogg/.mp3/.wav/.flac, < 20 МБ, ≤ 7 мин, ≤ 48 кГц, mono/stereo; аудио проходит модерацию.
- Через Open Cloud: **10 аудио в месяц без ID-верификации, 100 — с ней**; поэтому все звуки — один файл,
  каждая правка атласа тратит одну загрузку. Генератор детерминирован (seed + bitexact Ogg): без правок
  sha не меняется и повторной загрузки нет.
- Права ключа `ROBLOX_API_KEY`: Assets API → `asset:read` + `asset:write` (те же, что у иконок и мешей).
