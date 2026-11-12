-- Все настройки игры в одном месте. Меняй числа здесь — код трогать не нужно.
-- Баланс подобран симуляцией: уровень 1 без апгрейдов ≈ 35–40%, с ~6–8 покупками каждого ≈ финиш.
-- Экономика апгрейдов (#31): модель scratchpad econ_sim.py + phys.py, таблица в docs/GAME_DESIGN.md → «Экономика».

local Config = {}

------------------------------------------------------------------ МИР
Config.LOBBY_POS = Vector3.new(-2000, 3000, 400) -- лобби (в стороне от трасс игроков: за мостиком видна своя «витринная» трасса)
Config.SEASON_DECOR = 1 -- сезонный декор лобби (эпик E11): 0 — нет, 1 — Новый год (ёлка, подарки); сменить и задеплоить
Config.LOBBY_ZONE_POLL = 0.25 -- как часто клиент проверяет зоны станций лобби (портал «Миры», лавка «Сани», #69), с
Config.TRACKS_ORIGIN = Vector3.new(0, 3000, 0) -- старт трассы игрока в слоте 0
-- расстояние между трассами разных игроков (по X); трассы петляют (#73: было 1000 — полосы трасс с
-- долиной ±605 studs пересекались даже без сноса). Нужно ≥ 2·(наибольший снос + TRACK_FOOTPRINT):
-- 2·(SPIRAL_DRIFT_LIMIT 400 + 640) = 2080, с запасом
Config.SLOT_SPACING = 2400

------------------------------------------------------------------ ТРАССА (склон-чаша)
Config.TRACK_WIDTH = 80 -- ширина ходовой части (дно чаши): полосы препятствий, монеты, безопасная линия
Config.LANES = 6 -- полосы для препятствий; в ряду всегда свободно минимум 2
-- Поперечный профиль «чаша» (#74, эталон — видео мобильного оригинала, docs/ART_REFERENCES.md):
-- за ходовой частью на снежных кусках (старт, пологий, крутой, приземление, волны, лестница, кикер,
-- разгон к островкам) — два ездовых пояса того же снега (по ним заезжаешь и скатываешься обратно,
-- WALL_PULL), дальше ровная полка с декором и невидимый барьер-страховка. Видимых стенок нет.
-- Жёлоб поворотов/виража/ледяного тоннеля: тот же первый пояс (изо льда — стык без ступеньки), за
-- ним высокие ледяные борта 48°/74°. Геометрия Track/Sections; размеры здесь.
Config.BOWL = {
	BANK1_W = 30, -- первый пояс: ширина по склону, studs
	BANK1_ANGLE = 14, -- и угол, градусы (пологий — сани долго едут по нему и мягко возвращаются)
	BANK2_W = 30, -- второй пояс: ширина по склону
	BANK2_ANGLE = 30, -- и угол (крутой — заехал, потерял скорость, скатился)
	BARRIER_H = 40, -- невидимый барьер за вторым поясом: высота, studs
	FUNNEL_LEN = 70, -- разгон к островкам (isleIn): воронка невидимых стенок с края чаши к краю дна за столько studs
}
Config.BUILD_AHEAD = 650 -- строим трассу на столько studs вперёд от игрока
Config.KEEP_BEHIND = 150 -- и держим столько позади

-- СОХРАНЕНИЯ (DataService; не баланс — не в TUNABLES)
Config.DATA_AUTOSAVE = 120 -- секунд между автосейвами
Config.INVOKE_TIMEOUT = 12 -- сек: клиент ждёт ответа RemoteFunction (UI.invoke), потом «сервер не отвечает» (#19)
Config.DATA_LOCK_WAIT = 30 -- сколько ждать, пока другой сервер снимет блокировку сейва
Config.DATA_LOCK_STALE = 2 * Config.DATA_AUTOSAVE + 30 -- блокировка старше этого (сервер упал) — забираем сразу

-- Невидимые борта по краю дна — только там, где за дном трассы нет (озеро, островки #40, мост и
-- воронка развилки #42, воронка разгона к островкам): CanCollide, прозрачный, CanQuery=false (луч
-- санок вниз его не видит), наклон наружу — санки скатываются обратно, а не прилипают. На снежных
-- кусках чаши (#74) бортов у дна нет — границей служат пояса склона и барьер за ними (Config.BOWL);
-- в жёлобе поворота стенками служат сами ледяные пояса (74°) и общий Barrier.
Config.WALL_HEIGHT = 12 -- высота борта, studs
Config.WALL_TILT = 15 -- наклон наружу, градусы
Config.WALL_OFFSET = 1.5 -- насколько борт стоит дальше края дна, studs

-- Страховка «мягкий возврат» (server/Runs + client/SledController): сани, провалившиеся ниже дна
-- текущего куска на RESCUE_DEPTH, ушедшие вбок дальше края чаши на RESCUE_SIDE (Track.rideSpan:
-- дно + пояса склона) или дольше RESCUE_OUT_TIME находящиеся за краем чаши (полка за барьером),
-- возвращаются на дно куска (RESCUE_INSET от края, RESCUE_LIFT над снегом) с RESCUE_SPEED_KEEP
-- скорости. Не больше RESCUE_MAX раз за заезд; дальше, и над пропастью островков, — конец заезда
-- «fell» (ниже дна на FELL_DEPTH или вбок дальше 2 ширин трассы).
Config.RESCUE_DEPTH = 12
Config.RESCUE_SIDE = 30
Config.RESCUE_OUT_TIME = 1.5
Config.RESCUE_INSET = 8
Config.RESCUE_LIFT = 2
Config.RESCUE_SPEED_KEEP = 0.7
Config.RESCUE_MAX = 3
Config.FELL_DEPTH = 60
-- Персонаж не сидит в санках заезда (пропал, пересоздан, соскочил) дольше этого — заезд окончен
-- («left»), санки убираются, персонаж пересоздаётся в лобби
Config.RUN_UNSEATED_MAX = 2
-- Сел в санки у рогатки и не стреляет столько секунд (#20) — заезд отменяется («idle»): трасса, слот и
-- санки освобождаются, игрок в лобби с сообщением. 0 — без таймаута.
Config.IDLE_LAUNCH_TIMEOUT = 60

-- Лобби: витринная трасса своего мира строится у каждого игрока локально (client/LobbyScene)
Config.LOBBY_PREVIEW_SEGMENTS = 4 -- сколько первых кусков трассы показывать за мостиком (декорация)
Config.LOBBY_CAM_PITCH = -12 -- град.: наклон камеры спавна (client/LobbyScene): мостик и маяк старта над головой игрока и под плашками UI (макет scripts/ui_layout_preview.py)
Config.LOBBY_CAM_ZOOM = 16 -- studs: зум камеры спавна (Roblox по умолчанию 12.5): аватар меньше закрывает путь к старту
Config.LOBBY_LOOK_TWEEN = 1 -- сек: плавная смена освещения лобби при смене мира

-- ГРАФИКА (client/PostFX; пресеты миров — shared/WorldLook). Множители поверх пресетов.
Config.GRAPHICS = {
	BLOOM = 1, -- × интенсивности Bloom всех миров (0 — выкл)
	DOF = 1, -- × силы размытия дали в заезде (0 — выкл)
	SATURATION = 1, -- × насыщенности ColorCorrection
	SUNRAYS = 1, -- × силы солнечных лучей
	CONTRAST_MIN = 0.12, -- контраст кадра не ниже (читаемость препятствий)
	RUN_TWEEN = 1.5, -- сек: переход света при старте/конце заезда
	VIGNETTE_MAX = 0.45, -- непрозрачность виньетки скорости на краях (0 — выкл)
	VIGNETTE_FROM = 80, -- скорость, с которой виньетка появляется
	VIGNETTE_FULL = 170, -- скорость полной виньетки
	FPS_LOW = 40, -- авто-качество: FPS ниже — «Низкое» (два окна по 3 с подряд)
}

-- Повороты: ледяной жёлоб, который петляет (как в трейлере оригинала)
Config.CURVE_CHANCE = 0.3 -- шанс поворота вместо прямого участка
Config.CURVE_ANGLE = { 30, 55 } -- градусов на один поворот
Config.CURVE_STEP = 5 -- градусов на один кусок поворота
Config.CURVE_PIECE = 14 -- длина куска поворота (studs)
Config.CURVE_PITCH = { 8, 11 } -- уклон в поворотах (до 11°: ступенька на краю дна на стыках пола ≤ 0.2, #40)
Config.MAX_HEADING = 50 -- трасса не уходит дальше ±этого от общего направления
Config.MAX_DRIFT = 140 -- и не уплывает вбок дальше этого (studs): мягкий предел, проверяется в обычном повороте
-- Жёсткий предел сноса (#73; геометрия слотов, не баланс — не в TUNABLES). Снос копился на прямых
-- кусках под курсом (островки, лестницы, волны, обрыв + приземление, озеро) между случайными
-- поворотами — до 2218 studs при шаге слотов 1000. Теперь перед каждым куском (и перед длинным
-- участком — на всю его длину) профиль прогнозирует снос x − sin(курс)·путь; если прогноз дальше
-- DRIFT_LIMIT — сначала поворот-доводка к курсу asin(x / max(путь, STEER_RETURN)) (к оси).
Config.DRIFT_LIMIT = 230 -- studs: прогноз сноса центра трассы не дальше этого (факт чуть больше; вираж — SPIRAL_DRIFT_LIMIT)
Config.STEER_AHEAD = 300 -- studs: на сколько вперёд прогнозировать снос перед обычным куском
Config.STEER_RETURN = 900 -- studs: доводка выводит трассу к оси за столько пути (меньше — резче змейка)
-- Вираж-спираль S-образный (за ним трасса уходит туда, откуда шла, ~+240 studs): ему — свой предел
-- (прогон дуги и возврата курса в худшем случае, Profile.spiralFits); с DRIFT_LIMIT виражей почти нет
Config.SPIRAL_DRIFT_LIMIT = 400
-- Полоса трассы с оформлением (#73): дальше всего — дно долины (край чаши ≈ 95 + полка + VALLEY_WIDTH
-- ≈ 635 studs от оси в каждую сторону, стенд с мешами). Соседние полосы не пересекаются, пока
-- |снос| + TRACK_FOOTPRINT ≤ SLOT_SPACING / 2 (проверка — стенд scripts/stand/track_levels.luau).
Config.TRACK_FOOTPRINT = 640

-- Время в воздухе
Config.AIR_COINS_PER_SEC = 12
Config.AIR_MIN_TIME = 0.6

-- Длина уровня по горизонтали (studs). Владелец 2026-11-12: «трассы мира II слишком длинные» — было
-- 1200 + (уровень − 1) × 450 без предела (ур. 35 — 16 500, ур. 45 — 21 000, дольше лимита заезда 240 с).
-- Стало: от номера уровня ВНУТРИ мира (1…LEVELS_PER_WORLD) + небольшая надбавка за мир, с потолком;
-- сложность дальше растёт скоростью, плотностью препятствий и особыми участками, а не длиной.
Config.LEVEL_LEN_BASE = 1200 -- 1-й уровень мира
Config.LEVEL_LEN_STEP = 500 -- + за каждый следующий уровень внутри мира
Config.LEVEL_LEN_WORLD = 150 -- + за каждый следующий мир
Config.LEVEL_LEN_MAX = 5000 -- потолок
function Config.levelLength(level: number): number
	local per = Config.LEVELS_PER_WORLD or 5
	local inWorld = (level - 1) % per
	local world = (level - 1) // per
	return math.min(Config.LEVEL_LEN_MAX, Config.LEVEL_LEN_BASE + inWorld * Config.LEVEL_LEN_STEP + world * Config.LEVEL_LEN_WORLD)
end

-- Продольный рельеф «волны» (#75, эталон — видео мобильного оригинала, docs/GAME_DESIGN.md → «Рельеф»):
-- спуск (разгон) → подъём → гребень с лёгким отрывом → длинный пологий выкат → спуск… Генератор держит
-- доли пути RELIEF_SHARE (по горизонтали; повороты, дороги, старт и озеро не в счёте): берёт тот вид
-- куска, доля которого отстаёт сильнее: спуск/выкат/подъём — между собой (доли нормируются на их сумму), особые
-- (обрывы с трамплином, лестницы, островки, виражи) — от всего рельефа: пока их доля меньше цели, обрыв с
-- трамплином может встать вместо спуска (KICKER_CHANCE); приземления считаются спусками.
Config.RELIEF_SHARE = { descent = 0.30, runout = 0.45, climb = 0.15, special = 0.10 }
Config.RELIEF_CLIMB_STEP = 0.01 -- + доля подъёмов за каждый уровень внутри мира (за счёт выката)
Config.RELIEF_CLIMB_MAX = 0.20
-- Доли рельефа уровня: подъёмов больше к концу мира, выкат — остаток
function Config.reliefShare(level: number): { descent: number, runout: number, climb: number, special: number }
	local s = Config.RELIEF_SHARE
	local inWorld = (level - 1) % math.max(1, Config.LEVELS_PER_WORLD or 5)
	local climb = math.min(Config.RELIEF_CLIMB_MAX, s.climb + Config.RELIEF_CLIMB_STEP * inWorld)
	return { descent = s.descent, climb = climb, special = s.special, runout = math.max(0, 1 - s.descent - climb - s.special) }
end
Config.KICKER_CHANCE = 0.04 -- обрыв с трамплином вместо спуска (пока доля особых отстаёт); было 0.12 — чаще гребни
Config.KICKER_DROP = 22 -- высота обрыва
Config.GENTLE_ANGLE = { 3, 5 } -- выкат: уклон (тут трение побеждает гравитацию — скорость падает)
Config.RUNOUT_LEN = { 150, 260 } -- выкат: длина (studs)
Config.RUNOUT_REPEAT_LAG = 0.15 -- доля выкатов отстаёт от цели больше чем на столько — второй выкат подряд (длинный, как в видео)
Config.STEEP_ANGLE = { 12, 16 } -- спуск: уклон
Config.DESCENT_LEN = { 100, 300 } -- спуск: длина; перед подъёмом удлиняется до верхней границы, если энергии мало
Config.CLIMB_DESCENT_ANGLE = 20 -- спуск-разгон перед подъёмом может быть круче STEEP_ANGLE — до этого угла (как приземление 18°)
Config.CLIMB_ANGLE = { 3, 6 } -- подъём: уклон вверх (в профиле — отрицательный)
Config.CLIMB_LEN = { 60, 120 } -- подъём: длина
-- Подъём всегда сразу за спуском и преодолим с запасом: оценка скорости² эталонных саней мира
-- (RELIEF_REF_UPGRADE — уровень апгрейдов «рогатка/сани» по мирам; мир 1 — без апгрейдов, владелец) по
-- физике SledController без ракеты и ускорителей; в спуск перед подъёмом сани входят не медленнее
-- CLIMB_REF_SPEED; на гребне должно остаться ≥ CLIMB_MIN_SPEED — иначе спуск длиннее, потом круче (до
-- CLIMB_DESCENT_ANGLE), подъём короче, потом положе, а если и так не выходит — подъёма нет (только спуск).
-- Сани без апгрейдов (трение 10 при g 60) берут лишь короткий пологий подъём после длинного крутого разгона:
-- 300 studs × 20° → 74 studs/с → 60–80 studs × 3–4°. Проверка — scripts/relief_check.py.
Config.RELIEF_REF_UPGRADE = { 0, 6, 10, 14, 17, 20, 22 }
Config.CLIMB_REF_SPEED = 40 -- studs/с (≈ 44 км/ч)
Config.CLIMB_MIN_SPEED = 30 -- studs/с на гребне (выше SLOW_BRAKE_SPEED: добавочное торможение на малой скорости в оценку не входит)
-- Гребень: в конце подъёма плита-трамплин заподлицо со снегом (Name = "Ramp", без потери скорости):
-- подброс CREST_LIFT × скорость — на 95+ studs/с отрыв ≥ 0.6 с = «Полёт +N» (AIR_MIN_TIME), на малой
-- скорости сани только «вздрагивают» (луч 4 studs не теряет снег). Монеты — 3 на гребне.
Config.CREST_LIFT = 0.45
Config.CREST_PAD = 8 -- длина плиты (studs)
Config.FINAL_RUNOUT = 300 -- последний выкат перед озером (пологий GENTLE_ANGLE[1]): остановка за 3–5 с, не «ползание»

-- Препятствия, ускорители, монеты
Config.OBSTACLE_ROWS = 2 -- рядов препятствий на прямой участок
-- Плотность реже (владелец 2026-11-12): ряд вообще занят с шансом OBSTACLE_ROW_CHANCE; потолок занятых
-- полос в ряду растёт на 1 каждые OBSTACLE_GROW_LEVELS уровней (было 3) и каждые OBSTACLE_GROW_SEGS
-- кусков внутри уровня (было 16), всё равно ≤ 3 и в ряду свободно ≥ 2 полос (shared/SafeLine)
Config.OBSTACLE_ROW_CHANCE = 0.65
Config.OBSTACLE_GROW_LEVELS = 5
Config.OBSTACLE_GROW_SEGS = 24
Config.SAFE_START = 220 -- первые N studs после старта без препятствий
Config.BOOST_CHANCE = 0.1 -- ускоритель в ряду (≈ 1 на 3 сегмента)
Config.FORCED_KICKERS = { 0.3 } -- обязательные обрывы на этих долях уровня (#75: было { 0.35, 0.7 } — реже, вместо них гребни; 0.3 — до островков ISLE_AT)
Config.COIN_LINE_CHANCE = 0.5
-- Безопасная линия (#29, shared/SafeLine): в каждом ряду одна полоса гарантированно свободна, и между
-- соседними рядами она смещается только настолько, насколько успевает игрок на maxSpeed уровня
Config.SAFE_LINE_REACTION = 0.3 -- реакция игрока, с
Config.SAFE_LINE_MARGIN = 1.2 -- запас ×: время манёвра берётся с запасом (габарит препятствия, неточность)
Config.SAFE_LINE_MAX_SHIFT = 2 -- больше этого полос между рядами линия не смещается
-- Класс препятствия читается по виду и виды вводятся по уровням мира (#30, Props.obstacle). У каждого
-- вида поле from — с какого уровня мира он встречается (1–3); на 1-м уровне мира — лёгкие + 1 тяжёлый вид.
-- До OBSTACLE_COMBO_FROM в одном ряду препятствия одного класса (только лёгкие или только тяжёлые).
-- Со 2-го круга миров («Снежный лес II» …) открыто всё — виды игрок уже знает.
Config.OBSTACLE_COMBO_FROM = 3
Config.SNOWMAN_OBSTACLE_SCALE = 0.5 -- снеговик-препятствие (лёгкое): 15.8 → 7.9 studs, ниже тяжёлых
-- Маркер тяжёлого: красно-белый пояс-бордюр по контуру основания (SEGMENTS кусков чередуются)
Config.OBSTACLE_MARK = {
	SEGMENTS = 8,
	HEIGHT = 0.6, -- studs над дном
	WIDTH = 0.6, -- толщина бордюра
	PAD = 1.2, -- × габарита коллизии (контур чуть шире препятствия)
	MAX = 15, -- studs: не шире полосы (TRACK_WIDTH / LANES ≈ 13.3) с небольшим заходом
	MIN = 2, -- studs: полуось не меньше (тонкие — трость, столб — тоже получают заметный пояс)
}
-- Читаемость на светлом дне и в дымке (#36). Под каждым препятствием — тёмное пятно-тень: 1 плоский
-- Part-эллипс (SpecialMesh), без коллизий и CastShadow; тяжёлое — темнее (плотнее), лёгкое — мягче.
Config.OBSTACLE_SHADOW = {
	COLOR = Color3.fromRGB(20, 28, 52), -- тёмно-синий: контрастен голубому и розовому дну
	LIGHT = 0.6, -- прозрачность под лёгким
	HEAVY = 0.3, -- прозрачность под тяжёлым
	PAD = 1.35, -- × габарита коллизии
	MIN = 2.2, -- полуось, studs
	MAX = 16, -- диаметр, studs (≈ полоса + заход)
}
-- Препятствие должно читаться за OBSTACLE_READ_TIME до него на OBSTACLE_READ_SPEED (потолок саней 200 ×
-- (1 + бонус 27 %) ≈ 254 studs/с, ракета на земле ≈ 217): 2 с × 254 ≈ 510 studs < BUILD_AHEAD 650.
-- Сам манёвр (SAFE_LINE_REACTION + MARGIN · смена 2 полос) на 254 studs/с занимает ≈ 0.74 с ≈ 190 studs.
-- В заезде (client/PostFX): дымка не плотнее FOG_RUN (Density/Haze), резкость DOF — не ближе этой дистанции.
Config.OBSTACLE_READ_TIME = 2
Config.OBSTACLE_READ_SPEED = 254
Config.FOG_RUN = {
	DENSITY_MAX = 0.3, -- пещеры 0.40 и вулкан 0.38 в заезде → 0.30 (лобби — пресет мира)
	HAZE_MAX = 1.4, -- пещеры 1.7, вулкан 1.9 → 1.4
}
function Config.obstacleReadDistance(): number
	return Config.OBSTACLE_READ_TIME * Config.OBSTACLE_READ_SPEED
end

-- Дороги поперёк трассы с движущимися машинами (как в оригинале)
Config.ROAD_AT = { 0.12, 0.42, 0.72 } -- доли уровня, где могут быть дороги
-- Трафик реже (владелец 2026-11-12): дорог — +1 каждые ROAD_EVERY_LEVELS уровней (было 2), машин на
-- полосу — от 1, +1 каждые CARS_EVERY_LEVELS (было 2 + каждые 3, до 4), не больше CARS_MAX
Config.ROAD_EVERY_LEVELS = 3
Config.CARS_EVERY_LEVELS = 5
Config.CARS_MAX = 3
function Config.roadCount(level: number): number
	return math.min(#Config.ROAD_AT, 1 + (level - 1) // math.max(1, Config.ROAD_EVERY_LEVELS))
end
function Config.carsPerLane(level: number): number
	return math.min(Config.CARS_MAX, 1 + (level - 1) // math.max(1, Config.CARS_EVERY_LEVELS))
end
Config.ROAD_LOOP = 360 -- длина «кольца» полосы (studs): машина уезжает за край и возвращается
Config.CAR_SPEED = { 38, 55 } -- studs/с
Config.TRAIN_SPEED = 80
Config.TRAIN_LOOP = 1400
Config.GONDOLA_CHANCE = 0.6 -- канатка над приземлением после обрыва
Config.SMASH_COINS = 5 -- за разбитое препятствие (ракетой или на ускорителе)
-- Ящик TNT (#66): взрыв от любого удара — не авария (client/Sled/Contacts.explode)
Config.TNT_COINS = 8 -- монет за взрыв (вместо SMASH_COINS)
Config.TNT_SLOW = 0.7 -- скорость после взрыва (щит гасит потерю); потерю уменьшает устойчивость «Саней» (#60)
-- Потери скорости без аварии (client/Sled/Contacts; все уменьшает устойчивость «Саней», Config.keepSpeed):
Config.SMASH_SLOW = 0.92 -- скорость × это, когда разбил лёгкое препятствие (ракетой / после ускорителя)
Config.SHIELD_HIT_SLOW = 0.75 -- скорость × это, когда щит принял удар
Config.TNT_POP = 38 -- подброс вверх, studs/с
Config.TNT_SHAKE = 1.2 -- сила тряски камеры, studs
Config.TNT_SHAKE_TIME = 0.45 -- длительность тряски, с
-- Краш (#57): тряска камеры и «слоу-мо» 0.5 с (обесцвечивание + размытие, client/Sled/Contacts)
Config.CRASH_SHAKE = 1.8
Config.CRASH_SHAKE_TIME = 0.5
Config.CRASH_SLOWMO = 0.5
Config.CRASH_BLUR = 10
Config.AIR_COUNTER_MIN = 0.4 -- счётчик полёта «✈ 1.2 с» в HUD — с этой длительности (#57)
Config.CONFETTI_COUNT = 40 -- конфетти «НОВЫЙ РЕКОРД!» (#57)
Config.FINISH_GLIDE_MAX = 8 -- сек: после финиша катимся по ледяному озеру до остановки
Config.COINS_PER_LINE = 5

-- Гладкость трассы (#40): ходовая часть без ступенек и изломов (docs/GAME_DESIGN.md → «Гладкость»).
-- Стык кусков с разным уклоном получает переходные куски («скругление»): излом на стыке ≤ SMOOTH_KINK.
-- Пол поворота дробится на CURVE_SUBSTEPS кусков (поворот дна на CURVE_STEP / n за стык): ступенька
-- на краю дна x·sin(шаг)·tg(уклон) ≤ 0.2 stud. Остаточные ступеньки (борта жёлоба) сани проходят
-- «подсадкой» (SledController): ступенька до STEP_UP_MAX впереди — сани поднимаются без удара.
Config.SMOOTH_KINK = 1.5 -- градусов: больше — между кусками вставляются переходные (#75: было 2 — перегибы дугой)
Config.FILLET_LEN = 5 -- studs: длина одного переходного куска (#75: было 4; гребень −5°→13° = 12 кусков ≈ 60 studs дуги)
Config.CURVE_SUBSTEPS = 8 -- кусков пола на один кусок поворота
Config.STEP_UP_MAX = 1.2 -- studs: ступенька впереди не выше этого — подсадка без потери скорости
Config.STEP_PROBE = 3.2 -- studs: где впереди центра саней ищем ступеньку (+ путь за кадр)

-- Островки над пропастью (#40, shared/Islands): трамплин-ускоритель с края → цепочка 3–6 островков
-- → приземление на склон. Ускоритель задаёт скорость вылета в окне [isleSpeed, × ISLE_SPEED_SPREAD]:
-- зазоры и длины островков посчитаны баллистикой так, что при нижней скорости долетаешь с запасом
-- ISLE_LAND_MARGIN, а при верхней (и с ракетой весь полёт) не перелетаешь островок.
Config.ISLE_FROM_LEVEL = 2 -- первый уровень с островками (1-й — обучение)
Config.ISLE_AT = 0.52 -- обязательная цепочка на этой доле уровня (с ISLE_FROM_LEVEL)
Config.ISLE_CHANCE_BASE = 0.03 -- шанс доп. цепочки вместо обычного куска на ISLE_FROM_LEVEL…
Config.ISLE_CHANCE_STEP = 0.004 -- …растёт за уровень…
Config.ISLE_CHANCE_MAX = 0.07 -- …до этого
Config.ISLE_MIN_SPACING = 400 -- studs между цепочками
Config.ISLE_COUNT = { 3, 6 } -- островков в цепочке: от / до (растёт с уровнем, см. isleCount)
Config.ISLE_SPEED = { 80, 120 } -- скорость вылета с ускорителя: на ISLE_FROM_LEVEL / потолок
Config.ISLE_SPEED_STEP = 2.5 -- + studs/с за уровень
Config.ISLE_SPEED_SPREAD = 1.2 -- окно ускорителя: [v, v · это]
Config.ISLE_LIFT = 0.45 -- подброс ускорителя (доля скорости по нормали, как RAMP_LIFT)
Config.ISLE_RAMP = { 14, 4.5 } -- длина / высота трамплина-ускорителя, studs
Config.ISLE_PITCH = { 2, 5 } -- уклон островка, градусы
Config.ISLE_LEN = { 60, 95 } -- длина островка (если баллистика не требует длиннее), studs
Config.ISLE_RIM = { 10, 20 } -- островок шире коридора (борта ±W/2) на столько с каждой стороны
Config.ISLE_DROP = { -3, 12 } -- следующий островок ниже на столько (минус — выше), studs
Config.ISLE_FINAL_DROP = { 8, 16 } -- склон приземления после цепочки ниже последнего островка
Config.ISLE_GAP_MIN = 18 -- самый узкий зазор, studs
Config.ISLE_GAP_FILL = 0.6 -- зазор не меньше этой доли дальности при нижней скорости
Config.ISLE_LAND_MARGIN = 14 -- при нижней скорости садимся не ближе этого к краю, studs
Config.ISLE_END_MARGIN = 6 -- при верхней скорости + ракета садимся не дальше начала трамплина − это
Config.ISLE_SLACK = 0.97 -- нижняя скорость в расчёте × это (гашение буста на кадре трамплина)
Config.ISLE_IN = { 4, 70 } -- кусок-разгон перед первым прыжком: уклон, длина
Config.ISLE_BONUS_CHANCE = 0.5 -- бонус (щит/x2/канистра/магнит) на островке
Config.ISLE_COINS = 7 -- монет дугой над пропастью
function Config.isleChance(level: number): number
	if level < Config.ISLE_FROM_LEVEL then
		return 0
	end
	return math.min(Config.ISLE_CHANCE_MAX, Config.ISLE_CHANCE_BASE + Config.ISLE_CHANCE_STEP * (level - Config.ISLE_FROM_LEVEL))
end
-- Островков в цепочке: 3 на первых уровнях, +1 каждые 4 уровня до 6; разброс −1
function Config.isleCount(level: number): (number, number)
	local hi = math.clamp(Config.ISLE_COUNT[1] + (level - Config.ISLE_FROM_LEVEL) // 4, Config.ISLE_COUNT[1], Config.ISLE_COUNT[2])
	return math.max(Config.ISLE_COUNT[1], hi - 1), hi
end
function Config.isleSpeed(level: number): (number, number)
	local v = math.min(Config.ISLE_SPEED[2], Config.ISLE_SPEED[1] + Config.ISLE_SPEED_STEP * math.max(0, level - Config.ISLE_FROM_LEVEL))
	return v, v * Config.ISLE_SPEED_SPREAD
end

-- Развилка у островков (#42, Track/Fork): с FORK_FROM_LEVEL часть цепочек островков получает
-- ледяной мост сбоку (сторона FORK_SIDE: −1 — слева). Разгон перед прыжком шире (FORK_IN_LEN), на
-- FORK_SPLIT_AT его делит разделитель: по центру — ускоритель и островки (монет × FORK_RISK_COINS,
-- FORK_RISK_GEMS гемов), сбоку — мост (без монет и препятствий, с бортами и ускорителями). Обе ветки
-- сходятся на склоне приземления (длиннее — FORK_LAND_LEN, воронка FORK_MERGE_LEN).
Config.FORK_FROM_LEVEL = 6 -- с этого уровня (мир 2)
Config.FORK_CHANCE_BASE = 0.5 -- доля цепочек островков с развилкой на FORK_FROM_LEVEL…
Config.FORK_CHANCE_STEP = 0.01 -- …+ за уровень…
Config.FORK_CHANCE_MAX = 0.7 -- …до этого
Config.FORK_INTRO = 1 -- 1 — первая цепочка уровня FORK_FROM_LEVEL всегда с развилкой (знакомство)
Config.FORK_SIDE = -1 -- сторона моста: −1 слева, 1 справа (вывеска подстраивается)
Config.FORK_BRIDGE_X = 65 -- центр моста от оси трассы, studs
Config.FORK_BRIDGE_W = 30 -- ширина настила (2 полосы + запас на снос руля)
Config.FORK_ISLE_RIM = 6 -- островки цепочки с мостом не шире коридора больше чем на это (зазор до моста)
Config.FORK_IN_LEN = 200 -- длина разгона перед прыжком у развилки (обычно ISLE_IN[2])
Config.FORK_SPLIT_AT = 160 -- где на разгоне начинается разделитель веток, studs от начала
Config.FORK_LAND_LEN = 130 -- склон приземления у развилки (обычно 90)
Config.FORK_MERGE_LEN = 110 -- воронка: борт моста сводится к коридору за столько studs склона
Config.FORK_PITCH = { 1, 12 } -- уклон средней части моста: от / до (иначе развилки нет)
Config.FORK_BOOST_EVERY = 110 -- ускоритель на мосту каждые столько studs (пологий мост держит скорость)
Config.FORK_RISK_COINS = 2 -- монет дугой над пропастью × это (вывеска «РИСК ×2»)
Config.FORK_RISK_GEMS = 1 -- гемов над пропастью на рисковой ветке
Config.FORK_POST_STEP = 16 -- шаг столбиков перил моста
Config.FORK_PYLON_STEP = 160 -- шаг ледяных опор под мостом
Config.FORK_SIGN_SAFE = "БЕЗОПАСНО"
Config.FORK_SIGN_RISK = "РИСК ×2"
function Config.forkChance(level: number): number
	if level < Config.FORK_FROM_LEVEL then
		return 0
	end
	return math.min(Config.FORK_CHANCE_MAX, Config.FORK_CHANCE_BASE + Config.FORK_CHANCE_STEP * (level - Config.FORK_FROM_LEVEL))
end

-- Трамплин-лестница (#43, Track/Stairs): 3–4 нарастающих трамплина по пологому склону без обрыва,
-- последний — большой (как у кикера); монеты по дугам полёта, x2 в вершине последней дуги.
-- Скорость вылета — окно [stairSpeed, × STAIR_SPREAD] (атрибуты LaunchMin/LaunchMax/Lift у Ramp, как у
-- ускорителей островков): медленного подбрасывает, быстрого придерживает — дуги монет ловятся, а
-- при верхней скорости с ракетой садимся до следующего трамплина − STAIR_END_MARGIN.
Config.STAIR_FROM_LEVEL = 4 -- первый уровень с лестницей
Config.STAIR_FROM_H = 300 -- не раньше этой дистанции от старта (studs по горизонтали)
Config.STAIR_CHANCE_BASE = 0.06 -- шанс лестницы вместо обычного куска на STAIR_FROM_LEVEL…
Config.STAIR_CHANCE_STEP = 0.002 -- …+ за уровень…
Config.STAIR_CHANCE_MAX = 0.08 -- …до этого
Config.STAIR_MIN_SPACING = 1500 -- studs между лестницами
Config.STAIR_ISLE_SPACING = 250 -- и от конца цепочки островков
Config.STAIR_FOUR_LEVEL = 10 -- с этого уровня лестница иногда из 4 трамплинов (раньше — из 3)
Config.STAIR_PITCH = 7 -- уклон склона лестницы, градусы
Config.STAIR_HEIGHT = { 2.5, 5 } -- высота первого / последнего трамплина (между — поровну), studs
Config.STAIR_RAMP_RATIO = 3.6 -- длина трамплина = высота × это (5 → 18, как у кикера)
Config.STAIR_LIFT = { 0.25, 0.45 } -- подброс первого / последнего (последний — как RAMP_LIFT)
Config.STAIR_RUNUP = 40 -- разгон до первого трамплина, studs
Config.STAIR_GAP = { 55, 70 } -- между трамплинами не меньше (если баллистика не требует больше), studs
Config.STAIR_END_MARGIN = 8 -- при верхней скорости + ракета садимся до следующего трамплина − это
Config.STAIR_SPEED = { 75, 115 } -- скорость вылета: на STAIR_FROM_LEVEL / потолок
Config.STAIR_SPEED_STEP = 2 -- + studs/с за уровень
Config.STAIR_SPREAD = 1.15 -- окно скорости: [v, v · это]
Config.STAIR_LAND_PITCH = 14 -- склон приземления после последнего трамплина
Config.STAIR_LAND_LEN = 90 -- его длина не меньше этого…
Config.STAIR_LAND_MARGIN = 25 -- …и дальности при верхней скорости + ракета + это
Config.STAIR_COINS = 5 -- монет на дуге маленького трамплина (остаются те, что ловят все траектории окна)
Config.STAIR_COINS_TOP = 9 -- на дуге последнего
Config.STAIR_COIN_STEP = 5 -- монеты на дуге не чаще, studs
Config.STAIR_COIN_PROBE = 40 -- точек выборки дуги (где монету ловят все траектории окна)
Config.STAIR_X2_HIT = 16 -- высота датчика x2 в вершине последней дуги (полоса траекторий ≤ 9 + запас)
function Config.stairChance(level: number): number
	if level < Config.STAIR_FROM_LEVEL then
		return 0
	end
	return math.min(Config.STAIR_CHANCE_MAX, Config.STAIR_CHANCE_BASE + Config.STAIR_CHANCE_STEP * (level - Config.STAIR_FROM_LEVEL))
end
function Config.stairSpeed(level: number): (number, number)
	local v = math.min(Config.STAIR_SPEED[2], Config.STAIR_SPEED[1] + Config.STAIR_SPEED_STEP * math.max(0, level - Config.STAIR_FROM_LEVEL))
	return v, v * Config.STAIR_SPREAD
end

-- Вираж-спираль (#44): длинный поворот 120–150° по широкому ледяному жёлобу с высокими бортами
-- (сечение SPIRAL_PROFILE = жёлоб + ещё пояс SPIRAL_WALL) и стрелками-шевронами по внешнему краю.
-- Начинается, когда трасса уже смотрит вбок (|курс| ≥ SPIRAL_MIN_YAW), поворачивает через ось в другую
-- сторону до SPIRAL_MAX_HEADING (назад трасса не уходит) и сразу за ним — обычный поворот обратно.
-- Пол — из CURVE_SUBSTEPS частей по SPIRAL_STEP / n: ступенька на краю дна 40·sin(0.75°)·tg(9°) ≈ 0.08.
Config.SPIRAL_FROM_LEVEL = 6 -- с мира 2
Config.SPIRAL_FROM_H = 400 -- не раньше (studs от старта)
Config.SPIRAL_CHANCE_BASE = 0.26 -- шанс вместо обычного куска (когда курс подходит)…
Config.SPIRAL_CHANCE_STEP = 0.004 -- …+ за уровень…
Config.SPIRAL_CHANCE_MAX = 0.36 -- …до этого
Config.SPIRAL_MIN_SPACING = 1800 -- studs между виражами
Config.SPIRAL_ANGLE = { 120, 150 } -- градусов на вираж (меньше, если упирается в SPIRAL_MAX_HEADING)
Config.SPIRAL_MIN_YAW = 32 -- курс перед виражом не меньше (иначе 120° не набрать)
Config.SPIRAL_MAX_HEADING = 88 -- курс в конце виража не больше (трасса не поворачивает назад)
Config.SPIRAL_STEP = 6 -- градусов на кусок CURVE_PIECE (радиус ≈ 134 studs)
Config.SPIRAL_PITCH = { 7, 9 } -- уклон виража, градусы
Config.SPIRAL_WALL = { 12, 84 } -- доп. пояс борта снаружи жёлоба: ширина, угол (борт выше на ~12 studs)
Config.SPIRAL_SIGN_EVERY = 2 -- стрелка-шеврон на внешнем краю на каждом N-м куске
function Config.spiralChance(level: number): number
	if level < Config.SPIRAL_FROM_LEVEL then
		return 0
	end
	return math.min(Config.SPIRAL_CHANCE_MAX, Config.SPIRAL_CHANCE_BASE + Config.SPIRAL_CHANCE_STEP * (level - Config.SPIRAL_FROM_LEVEL))
end

-- Ледяной тоннель с кольцами-ускорителями (#44, Track/IceTunnel): перед цепочкой островков (разгон
-- перед прыжками; ускоритель островков всё равно задаёт окно скорости вылета) — короткий ледяной жёлоб
-- под сводом, внутри ICE_TUNNEL_RINGS колец по центру (каждое = ускоритель, +BOOST_ADD), монеты между
-- ними, лампы по бортам. Препятствий нет.
Config.ICE_TUNNEL_FROM_LEVEL = 6 -- с мира 2
Config.ICE_TUNNEL_CHANCE = 0.5 -- перед цепочкой островков
Config.ICE_TUNNEL_LEN = 84 -- длина (два куска по половине: портал входа и выхода)
Config.ICE_TUNNEL_PITCH = 6 -- уклон
Config.ICE_TUNNEL_RINGS = 3 -- колец-ускорителей
Config.ICE_TUNNEL_RING_R = 5.5 -- радиус кольца (датчик — квадрат 1.6·r)
Config.ICE_TUNNEL_LAMP_STEP = 12 -- лампы по бортам через столько studs

-- Оформление обычных кусков (#40, art): цветные кромки дна, флажки-слалом по бортам, ледяные арки
Config.EDGE_STRIPES = true -- цветные полосы вдоль края дна (цвет мира)
Config.SLALOM_CHANCE = 0.45 -- флажки-слалом на бортах пологого/крутого куска
Config.ARCH_CHANCE = 0.12 -- большая арка над трассой на пологом куске («вау» в поле зрения)
-- Тоннели (#65): весь ледяной поворот под сводом (Track/Tunnel). Вид — по миру; только декор.
Config.TUNNEL_SHARE = 0.25 -- доля пути под сводом (владелец: «минимум 20%»; 0 — тоннелей нет)
Config.TUNNEL_MIN_LEN = 100 -- короче участок не берётся (studs по горизонтали)
Config.TUNNEL_MAX_LEN = 700 -- один тоннель не длиннее (длинный участок — середина)
Config.TUNNEL_RING_LEN = 16 -- кольцо свода не длиннее (прямые делятся на кольца)
Config.TUNNEL_FROM_H = 300 -- не раньше этой дистанции от старта (studs по горизонтали)
Config.TUNNEL_HEIGHT = 30 -- подъём свода над кромкой жёлоба (studs)
Config.TUNNEL_SIDE = 4 -- ноги свода — на столько studs за краем полки
Config.TUNNEL_THICK = 5 -- толщина свода из блоков (фолбэк без меша)
Config.TUNNEL_RING_BLOCKS = 12 -- блоков в кольце фолбэка
Config.TUNNEL_LIGHT_EVERY = 3 -- свет внутри: один источник на N кусков поворота
Config.TUNNEL_LIGHT_RANGE = 50
Config.TUNNEL_LIGHT_BRIGHT = 1.4
-- Гребень над долиной с островками (видео референса 613–651 м): обрыв сбоку трассы (Track/Valley)
Config.VALLEY_SHARE = 0.15 -- доля пути по гребню (0 — нет; не пересекается с тоннелями)
Config.VALLEY_FROM_H = 200 -- не раньше (studs от старта)
Config.VALLEY_MIN_LEN = 100 -- короче участок не берётся
Config.VALLEY_MAX_LEN = 600 -- один участок не длиннее
Config.VALLEY_DEPTH = 70 -- глубина обрыва от кромки до дна долины (studs)
Config.VALLEY_SHOULDER = 12 -- полка между кромкой трассы и обрывом
Config.VALLEY_WIDTH = 520 -- ширина дна долины
Config.VALLEY_ISLES = 1.2 -- островков на 100 studs участка (с каждой стороны)
-- Обвязка трассы (#70): заборчик и подвесной мост
Config.FENCE_EVERY = 4 -- заборчик вдоль снежной прямой — каждый N-й кусок с каждой стороны (0 — только у обрыва)
Config.FENCE_STEP = 6 -- шаг столбиков, studs
Config.BRIDGE_GAP_X = 0 -- декоративный мост сбоку над пропастью ВЫКЛЮЧЕН (владелец 2026-11-12: висел у трамплина без смысла); настоящий мост — развилка #42
Config.BRIDGE_DROP = 6 -- мост ниже края островков, studs

-- Свои меши декора (#45, shared/Meshes): 1 — меши, если шаблоны загружены; 0 — всё из Part (как до #45).
-- Слои кадра ниже ставятся только мешами (без шаблонов их нет — старый вид, инстансов не прибавляется).
-- Шансы — на сторону куска длиной 110 studs (короче — пропорционально меньше).
Config.MESH_DECOR = 1
-- Меши транспорта (сани, обвес тиров, ракеты — shared/SledModels): 1 — меши, если шаблоны загружены;
-- 0 — всё из Part. MESH_SLED_FLIP = 1 — развернуть меши на 180° (если импорт перевернул нос).
Config.MESH_SLEDS = 1
Config.MESH_SLED_FLIP = 1 -- импорт glb в Roblox зеркалит ось Z (проверено в игре 2026-11-08: ракеты задом наперёд)
-- Фары (тир «Саней» 1, #33): пятно света на снегу впереди (SpotLight) и луч (Beam), видно с камеры
Config.HEADLIGHT_RANGE = 34
Config.HEADLIGHT_BRIGHTNESS = 3
Config.HEADLIGHT_ANGLE = 70
Config.DECOR_DRIFT_CHANCE = 0.8 -- ближний план: сугробы/дюны у внешнего края бортов
Config.DECOR_MID_CHANCE = 0.55 -- средний план: скалы/утёсы в 55–95 studs от трассы
Config.DECOR_FAR_CHANCE = 0.35 -- дальний план: второй ряд гор в 240–320 studs
Config.DECOR_WOW_CHANCE = 0.18 -- «вау»: парящий островок с ёлкой / каменная арка в поле зрения
Config.DECOR_ROCKS_CHANCE = 0.55 -- скалы/кристаллы/ёлки мира на средний план (#67), на 110 studs с каждой стороны

-- Миры по уровням (по кругу)
Config.THEMES = {
	{
		name = "Снежный лес",
		floor = Color3.fromRGB(140, 195, 240),
		wall = Color3.fromRGB(95, 160, 225),
		ground = Color3.fromRGB(225, 235, 245),
	},
	{
		name = "Ледяной город",
		floor = Color3.fromRGB(120, 185, 235),
		wall = Color3.fromRGB(80, 145, 215),
		ground = Color3.fromRGB(215, 225, 238),
	},
	{
		name = "Каньон",
		floor = Color3.fromRGB(150, 200, 240),
		wall = Color3.fromRGB(110, 170, 230),
		ground = Color3.fromRGB(225, 195, 155),
	},
	{
		name = "Ледяные пещеры",
		floor = Color3.fromRGB(150, 215, 245),
		wall = Color3.fromRGB(90, 175, 235),
		ground = Color3.fromRGB(200, 230, 248),
	},
	{
		name = "Северное сияние",
		floor = Color3.fromRGB(125, 170, 225),
		wall = Color3.fromRGB(80, 120, 200),
		ground = Color3.fromRGB(205, 220, 240),
	},
	{
		name = "Снежный вулкан",
		floor = Color3.fromRGB(150, 190, 230),
		wall = Color3.fromRGB(110, 150, 210),
		ground = Color3.fromRGB(70, 66, 72),
	},
	{
		name = "Конфетная гора",
		floor = Color3.fromRGB(245, 185, 220),
		wall = Color3.fromRGB(230, 130, 195),
		ground = Color3.fromRGB(255, 232, 245),
	},
}

-- Мир = LEVELS_PER_WORLD уровней одной темы. 7 миров: лес → город → каньон → пещеры →
-- северное сияние → вулкан → конфетная гора, дальше по кругу («Снежный лес II» и т. д.)
Config.LEVELS_PER_WORLD = 5
Config.WORLD_ICONS = { "🌲", "🏙", "🌵", "🧊", "🌌", "🌋", "🍭" }
Config.WORLD_IMAGES = { "tree", "city", "cactus", "ice", "aurora", "volcano", "candy" } -- 3D-иконки (UI.icon)
Config.WORLD_COLORS = {
	Color3.fromRGB(70, 150, 220),
	Color3.fromRGB(120, 110, 220),
	Color3.fromRGB(225, 135, 60),
	Color3.fromRGB(80, 190, 230),
	Color3.fromRGB(40, 60, 130),
	Color3.fromRGB(200, 70, 50),
	Color3.fromRGB(235, 110, 190),
}
function Config.worldOf(level: number): number
	return (level - 1) // Config.LEVELS_PER_WORLD + 1
end
-- Ступень ввода препятствий (#30): номер уровня внутри мира 1…LEVELS_PER_WORLD на первом круге
-- миров; со второго круга — LEVELS_PER_WORLD (все виды и комбинации открыты)
function Config.obstacleStage(level: number): number
	local per = Config.LEVELS_PER_WORLD
	if level > per * #Config.THEMES then
		return per
	end
	return (level - 1) % per + 1
end
function Config.themeOfWorld(world: number): number
	return ((world - 1) % #Config.THEMES) + 1
end
function Config.themeOf(level: number): number
	return Config.themeOfWorld(Config.worldOf(level))
end
function Config.worldName(world: number): string
	local base = Config.THEMES[Config.themeOfWorld(world)].name
	local lap = (world - 1) // #Config.THEMES
	return if lap > 0 then base .. " " .. string.rep("I", lap + 1) else base
end

-- HUD заезда (#71, docs/GAME_DESIGN.md → «HUD заезда»; client/HUD)
-- Аватары других игроков на шкале прогресса: только те, кто едет тот же уровень (RunLevel);
-- позиция = RunDistance / LevelLength, обновление раз в HUD_AVATAR_PERIOD с.
Config.HUD_AVATAR_PERIOD = 0.5 -- сек между обновлениями аватаров на шкале
Config.HUD_AVATAR_MAX = 6 -- больше аватаров на шкале не показываем (ближайшие по номеру в списке)
Config.HUD_AVATAR_SIZE = 38 -- логических (≈ 21 px на телефоне)
-- Баннер зоны при въезде (тоннель, гребень над долиной, дорога, рельсы, островки) и мира на старте:
-- крупный текст по центру сверху ZONE_BANNER_TIME с, проявление/угасание ZONE_BANNER_FADE с.
-- Один раз на каждую зону заезда; всплывашка трюка поверх — баннер гаснет сразу.
Config.ZONE_BANNER_TIME = 2
Config.ZONE_BANNER_FADE = 0.35
Config.ZONE_BANNER_WORLD = 1 -- 1 — баннер с названием мира после выстрела рогатки, 0 — нет
Config.ZONE_BANNERS = {
	-- тоннель — по виду свода мира (Track/Tunnel LOOKS), номер темы Config.THEMES
	tunnel = { "Снежный тоннель!", "Ледяной тоннель!", "Каменный тоннель!", "Ледяная пещера!", "Тоннель сияния!", "Лавовый тоннель!", "Карамельный тоннель!" },
	valley = "Над долиной!",
	road = "Дорога!",
	rail = "Железная дорога!",
	isle = "Островки!",
}

-- Табло «Следующее обновление» в лобби (UTC)
Config.NEXT_UPDATE = os.time({ year = 2026, month = 11, day = 15, hour = 12 })

------------------------------------------------------------------ БОНУСЫ НА ТРАССЕ
-- Подбираемые бонусы (тег PowerUp, атрибут Kind): шанс появиться на прямом участке
Config.POWERUPS = {
	shield = { chance = 0.07, name = "Щит" }, -- одно столкновение без аварии
	x2 = { chance = 0.07, name = "x2 монеты", time = 10 }, -- монеты на трассе ×2 на 10 с
	fuel = { chance = 0.09, name = "Канистра" }, -- полный бак ракеты
	rings = { chance = 0.12, name = "Кольца", coins = 10 }, -- 3 золотых кольца подряд, +10 за каждое
}
Config.MAGNET_CHANCE = 0.12 -- магнит на прямом участке
Config.MAGNET_TIME = 8 -- сек
Config.MAGNET_RADIUS = 32 -- studs
Config.GEMS_ON_TRACK = { 0.3, 0.62, 0.9 } -- где лежат гемы (доли уровня)
Config.CRYSTAL_AT = 0.5 -- ледяной кристалл (разбей — монеты + гем)
Config.CRYSTAL_COINS = 60
Config.COMBO_WINDOW = 1.3 -- сек между монетами, чтобы комбо не сбросилось
function Config.comboMult(combo: number): number
	return math.min(3, 1 + combo // 5) -- каждые 5 монет подряд +1 к множителю (до x3)
end

------------------------------------------------------------------ НАГРАДЫ (удержание)
-- Монетные награды растут с уровнем, чтобы оставаться полезными
function Config.rewardCoins(base: number, level: number): number
	return math.floor(base * (1 + (level - 1) * (if Config.F then Config.F.rewardGrowth else 0.25)))
end
-- Стрик: день цикла 1..7 по длине серии, награда (монеты с бонусом цикла — до rewardCoins), цена спасения
function Config.streakDay(count: number): number
	return (math.max(count, 1) - 1) % #Config.STREAK_REWARDS + 1
end
function Config.streakReward(count: number): (number?, number?)
	local r = Config.STREAK_REWARDS[Config.streakDay(count)]
	local coins = r.coins
	if coins and count > #Config.STREAK_REWARDS then
		coins = math.floor(coins * Config.STREAK_CYCLE_MULT)
	end
	return coins, r.gems
end
function Config.streakSavePrice(count: number): number
	return Config.STREAK_SAVE_GEMS + Config.STREAK_SAVE_STEP * (Config.streakDay(count) - 1)
end
-- Задания дня. max = true — считается лучший результат одного заезда, а не сумма.
-- icon — имя 3D-иконки (UI.icon). Каждый день выбирается TASKS_PER_DAY разных заданий
-- (shared/DailyTasks: базовый набор дня + замена невыполнимых для игрока, #32).
-- Доступность (Config.taskAvailable): needWorld = N — игрок дошёл до мира N (есть пройденный мир);
-- needLevel = N — уровень ≥ N; needRare = true — есть сани редкости Gold или выше; needSpeed = true —
-- цель (км/ч) не выше потолка скорости его «Саней»; need = function(d, target) — своё условие.
Config.TASK_BUYSLED_LEVEL = 3 -- «Купи N редкостей саней» — с этого уровня (новичку монеты нужнее на апгрейды)
Config.KMH_PER_STUD = 1.1 -- км/ч на спидометре = studs/с × 1.1
Config.TASK_POOL = {
	-- заезды и дистанция
	{ id = "runs", text = "Сделай %d %s", forms = { "заезд", "заезда", "заездов" }, targets = { 5, 10 }, gems = 3, icon = "sled" },
	{ id = "distance", text = "Проедь %d м всего", targets = { 3000, 9000 }, gems = 4, icon = "mountain" },
	{ id = "distanceRun", text = "Проедь %d м за один заезд", targets = { 500, 1200 }, gems = 5, icon = "flag", max = true },
	{ id = "finish", text = "Доедь до финиша %d раз", targets = { 1, 3 }, gems = 6, icon = "flag" },
	{ id = "best", text = "Побей свой рекорд %d раз", targets = { 1, 2 }, gems = 5, icon = "trophy" },
	{ id = "farm", text = "Сделай %d %s в пройденном мире", forms = { "заезд", "заезда", "заездов" }, targets = { 2, 4 }, gems = 4, icon = "tree", needWorld = 2 },
	-- монеты и награды
	{ id = "coins", text = "Собери %d %s", forms = { "монету", "монеты", "монет" }, targets = { 300, 900 }, gems = 4, icon = "coin" },
	{ id = "coinsRun", text = "Заработай %d %s за один заезд", forms = { "монету", "монеты", "монет" }, targets = { 150, 400 }, gems = 5, icon = "moneybag", max = true },
	{ id = "combo", text = "Собери комбо x%d", targets = { 5, 15 }, gems = 5, icon = "star", max = true },
	{ id = "gems", text = "Подбери %d %s на трассе", forms = { "гем", "гема", "гемов" }, targets = { 3, 8 }, gems = 5, icon = "gem" },
	{ id = "crystal", text = "Разбей %d %s", forms = { "ледяной кристалл", "ледяных кристалла", "ледяных кристаллов" }, targets = { 1, 3 }, gems = 5, icon = "ice" },
	-- трюки и скорость
	{ id = "air", text = "Пробудь в воздухе %d с", targets = { 15, 45 }, gems = 5, icon = "parachute" },
	{ id = "airRun", text = "Пробудь в воздухе %d с за один заезд", targets = { 6, 15 }, gems = 5, icon = "parachute", max = true },
	{ id = "flips", text = "Сделай %d сальто", targets = { 3, 10 }, gems = 5, icon = "flip" },
	{ id = "speed", text = "Разгонись до %d км/ч", targets = { 100, 160 }, gems = 5, icon = "stopwatch", max = true, needSpeed = true }, -- км/ч = studs/с × 1.1; без ракеты терминал 70–113, 200 требовал Сани ≥ 34 ур.
	{ id = "smash", text = "Разбей %d %s", forms = { "препятствие", "препятствия", "препятствий" }, targets = { 5, 15 }, gems = 4, icon = "smash" },
	{ id = "boosts", text = "Проедь по %d %s", forms = { "ускорителю", "ускорителям", "ускорителям" }, targets = { 4, 12 }, gems = 4, icon = "bolt" },
	-- бонусы на трассе
	{ id = "magnet", text = "Подбери %d %s", forms = { "магнит", "магнита", "магнитов" }, targets = { 2, 5 }, gems = 4, icon = "magnet" },
	{ id = "shield", text = "Подбери %d %s", forms = { "щит", "щита", "щитов" }, targets = { 1, 3 }, gems = 5, icon = "shield" },
	{ id = "x2", text = "Подбери %d %s", forms = { "бонус x2", "бонуса x2", "бонусов x2" }, targets = { 1, 3 }, gems = 5, icon = "coin" },
	{ id = "fuel", text = "Подбери %d %s", forms = { "канистру", "канистры", "канистр" }, targets = { 1, 4 }, gems = 4, icon = "fuel" },
	{ id = "rings", text = "Пролети через %d %s", forms = { "золотое кольцо", "золотых кольца", "золотых колец" }, targets = { 3, 12 }, gems = 5, icon = "ring" },
	-- лобби
	{ id = "upgrades", text = "Улучши что-нибудь %d раз", targets = { 2, 6 }, gems = 4, icon = "rocket" },
	{ id = "gifts", text = "Забери %d %s за игру", forms = { "подарок", "подарка", "подарков" }, targets = { 2, 4 }, gems = 3, icon = "gift" },
	{ id = "chest", text = "Открой сундук в лобби", targets = { 1, 1 }, gems = 3, icon = "gift" },
	-- аккуратность и магазин
	{ id = "cleanFinish", text = "Доедь до финиша без аварии %d %s", forms = { "раз", "раза", "раз" }, targets = { 1, 3 }, gems = 7, icon = "check" },
	{ id = "cleanRun", text = "Проедь %d м за один заезд без аварии", targets = { 400, 1000 }, gems = 5, icon = "ringbuoy", max = true },
	{ id = "magnetCoins", text = "Притяни магнитом %d %s", forms = { "монету", "монеты", "монет" }, targets = { 20, 60 }, gems = 4, icon = "magnet" },
	{ id = "rareRuns", text = "Сделай %d %s на санях Gold или редче", forms = { "заезд", "заезда", "заездов" }, targets = { 3, 7 }, gems = 5, icon = "sparkles", needRare = true },
	{ id = "buySled", text = "Купи %d %s саней", forms = { "редкость", "редкости", "редкостей" }, targets = { 1, 3 }, gems = 5, icon = "saucer", need = function(d)
		return (d.Level or 1) >= Config.TASK_BUYSLED_LEVEL -- читается на лету (TUNABLES)
	end },
}
Config.TASKS_PER_DAY = 6

-- Выполнимо ли задание t с целью target для профиля d (#32). Без условий — всегда.
function Config.taskAvailable(t, d, target: number): boolean
	local level = d.Level or 1
	if t.needWorld and Config.worldOf(level) < t.needWorld then
		return false
	end
	if t.needLevel and level < t.needLevel then
		return false
	end
	if t.needRare then
		local rare = (d.SledRarity or 1) >= 2
		for key in d.OwnedSleds or {} do
			local r = tonumber(string.match(key, ":(%d+)$"))
			if r and r >= 2 then
				rare = true
				break
			end
		end
		if not rare then
			return false
		end
	end
	if t.needSpeed and target > Config.maxSpeed(d.SledLevel or 0) * Config.KMH_PER_STUD then
		return false
	end
	if t.need and not t.need(d, target) then
		return false
	end
	return true
end

-- Число + слово в нужной форме: 1 заезд, 3 заезда, 5 заездов
function Config.plural(n: number, forms: { string }): string
	local n10, n100 = n % 10, n % 100
	if n10 == 1 and n100 ~= 11 then
		return forms[1]
	elseif n10 >= 2 and n10 <= 4 and (n100 < 12 or n100 > 14) then
		return forms[2]
	end
	return forms[3]
end
function Config.taskText(t, target: number): string
	if t.forms then
		return string.format(t.text, target, Config.plural(target, t.forms))
	end
	return string.format(t.text, target)
end
Config.TASK_CHEST_COINS = 500 -- сундук за все задания (× rewardCoins) + гемы
Config.TASK_CHEST_GEMS = 15
-- Задание недели (#56, shared/WeeklyQuest + server/Rewards): одна цель на неделю ISO (UTC, тот же ключ
-- W<год>-<нед>, что у досок недели LB_W…), сброс в понедельник 00:00 UTC. Цель недели — POOL[n % #POOL + 1],
-- след недели — TRAILS[n % #TRAILS + 1] (n — номер недели от 1970); цель и след фиксируются в сейве при
-- первом входе в неделю (правка Настройки посреди недели их не двигает). stat — ключ статистики заезда
-- из Rewards.onRun (как у заданий дня). Цели — ≈ 4 сессии по 15 мин у казуала и среднего игрока
-- (scripts/sim_economy.py, docs/GAME_DESIGN.md → «Задание недели»): не зависят от уровня и миров.
-- Награда — один раз за неделю, сразу по выполнении: эксклюзивный след (навсегда) + GEMS; след уже
-- есть — вместо него OWNED_GEMS.
Config.WEEKLY_QUEST = {
	GEMS = 30,
	OWNED_GEMS = 30, -- компенсация, если след недели уже получен раньше
	STEPS = { 25, 50, 75 }, -- % этапов: тост «Задание недели: 50 %» и custom WeeklyQuestStep
	POOL = {
		{ id = "runs", stat = "runs", text = "Сделай %d %s", forms = { "заезд", "заезда", "заездов" }, target = 60, icon = "sled" },
		{ id = "distance", stat = "distance", text = "Проедь %d м", target = 100000, icon = "mountain" },
		{ id = "air", stat = "air", text = "Пробудь в воздухе %d с", target = 200, icon = "parachute" },
		{ id = "smash", stat = "smash", text = "Разбей %d %s", forms = { "препятствие", "препятствия", "препятствий" }, target = 40, icon = "smash" },
		{ id = "boosts", stat = "boosts", text = "Проедь по %d %s", forms = { "ускорителю", "ускорителям", "ускорителям" }, target = 35, icon = "bolt" },
		{ id = "rings", stat = "rings", text = "Пролети через %d %s", forms = { "золотое кольцо", "золотых кольца", "золотых колец" }, target = 30, icon = "ring" },
	},
	TRAILS = { "aurora", "comet", "frost", "ember" }, -- эксклюзивные следы (Config.TRAILS, exclusive = true)
}
-- Подарки за время в игре (минуты с захода), как сетка «Подарки» в референсе
Config.PLAYTIME_GIFTS = {
	{ min = 1, gems = 2 }, -- 1-я минута — гемы: монеты тут дали бы лишнюю покупку до 2-го заезда (#31)
	{ min = 3, coins = 60 },
	{ min = 5, coins = 80 },
	{ min = 7, gems = 3 }, -- было 8: не «съедает» ожидание большого подарка
	-- «Большой подарок» (#24): цель «досидеть до 10 минут»; раз в день (Daily.big), не фармится
	-- перезаходом. 600 монет × rewardCoins ≈ 40% следующего апгрейда на 10-й минуте (кривая #31)
	{ min = 10, coins = 600, gems = 5, big = true },
	{ min = 14, coins = 120 }, -- было 12
	{ min = 16, coins = 150, gems = 2 },
	{ min = 20, coins = 200 },
	{ min = 25, gems = 5 },
	{ min = 30, coins = 450 },
	{ min = 40, gems = 6 },
	{ min = 50, coins = 700 },
	{ min = 60, coins = 1000, gems = 10 },
}
-- Сундук в лобби раз в 4 часа
Config.CHEST_INTERVAL = 4 * 3600
Config.CHEST_COINS = 75 -- доступен сразу: 75 + 1-й заезд ≈ одна покупка, не пять (#31)
Config.CHEST_GEMS = 3
-- Стрик дней входа (#25): день = os.time() // 86400 (UTC, как у заданий). Награда за день цикла 1..7,
-- монеты × rewardCoins; дни 1–6 — 100…400 (меньше Большого подарка 600 + 5 💎), 7-й — крупный: 600 + 25 💎.
-- Неделя: 2000 монет-базы + 35 💎 — повод зайти, а не замена заездов (кривая #31 не сдвигается)
Config.STREAK_REWARDS = {
	{ coins = 100 },
	{ coins = 150, gems = 2 },
	{ coins = 200 },
	{ coins = 250, gems = 3 },
	{ coins = 300 },
	{ coins = 400, gems = 5 },
	{ coins = 600, gems = 25, big = true },
}
Config.STREAK_CYCLE_MULT = 1.25 -- монеты со 2-го цикла (дни 8+), не накапливается
Config.STREAK_SAVE_GEMS = 10 -- спасение стрика после пропуска 1 дня: цена, если серия была 1 день
Config.STREAK_SAVE_STEP = 2 -- +💎 за каждый следующий день цикла серии (6 дней → 20, 7 → 22)
Config.SESSION_GOAL_MIN = 13 -- цель полоски «сессия» в лобби (минуты с захода, #24)
Config.SESSION_CHECK_SEC = 5 -- как часто сервер проверяет «сессия ≥ 10 мин» для аналитики
Config.DEV_SESSION_SHIFT = 5 * 60 -- DEV «+5 мин сессии»

------------------------------------------------------------------ ФИЗИКА САНОК
Config.GRAVITY_ALONG = 60 -- «игровая» гравитация вдоль склона
Config.DRAG = 0.0012 -- сопротивление воздуха (× v²)
Config.STOP_SPEED = 5 -- ниже этой скорости... (было 3)
Config.STOP_TIME = 0.8 -- ...столько секунд = остановился (было 1.5 — долго «доползал»)
-- Торможение на малой скорости (владелец 2026-11-12: «очень долго останавливается»): когда сани и так
-- замедляются и скорость ниже SLOW_BRAKE_SPEED, добавочное трение до SLOW_BRAKE studs/с² (линейно к нулю
-- скорости) — сани встают за 1–2 с, а не ползут 5–10 с. На спуске (ускорение ≥ 0) и с ракетой не действует.
Config.SLOW_BRAKE_SPEED = 28
Config.SLOW_BRAKE = 14
Config.STEER_SPEED = 45 -- максимальная боковая скорость (на скорости до STEER_REF_SPEED)
Config.STEER_REF_SPEED = 100 -- выше этой скорости руль растёт пропорционально ей: время смены полосы постоянно
Config.STEER_RESPONSE = 7 -- как быстро боковая скорость догоняет руль (инерция)
-- Боковая скорость руля на текущей скорости (docs/GAME_DESIGN.md → «Скорость и руль»)
function Config.steerSpeed(speed: number): number
	return Config.STEER_SPEED * math.max(1, speed / math.max(1, Config.STEER_REF_SPEED))
end
Config.WALL_PULL = 140 -- борта жёлоба скатывают обратно к центру
Config.STEER_TILT = 18 -- наклон ватрушки в повороте (градусы)
Config.OBSTACLE_SLOWDOWN = 0.6 -- скорость × это при «Падении» (недокрученный ручной трюк); потерю уменьшает устойчивость «Саней»
Config.BOOST_ADD = 18 -- ускоритель на льду
Config.RAMP_MIN_SPEED = 30 -- на трамплине не медленнее этого (не застрянешь)
Config.RAMP_LIFT = 0.45 -- подброс с трамплина (доля скорости вверх)
Config.ROCKET_THRUST = 40
Config.FLIP_SPEED = 9 -- рад/с: скорость вращения во всех трюках (сальто, бочка, разворот)

-- Прыжок с земли (кнопка «Прыжок»): подброс вверх; высота = v² / (2·196.2) ≈ 6.4 studs при 50
-- (было 40 ≈ 4.1), полёт на ровном 2v/g ≈ 0.51 с — авто-трюк «грэб/разворот» (ярус 0.5 с).
-- «Твёрдый» верх препятствий (детали, которые видят Touched/GetPartBoundsInBox; стенд в
-- scratchpad/walls/heights_tail): бревно 2.6, барьер 3.35, конусы 4.0, бочки 4.0, гидрант 4.25,
-- поленница 4.4, мелкий валун 4.6 — перелетаются; крупный валун до 6.7 — впритык; джип 6.9,
-- остановка 7.45, фургон 7.6, автобус 8.1, грузовик 9.6, знак 10.1, снеговик 13.9 — нет.
-- Легковушки (крыша 5.4) по-прежнему не перелетаются: у них невидимая «шапка» до CAR_HITBOX_H.
Config.JUMP_ENABLED = 0 -- прыжок с земли выключен (решение владельца 2026-11-08); 1 — вернуть
Config.JUMP_SPEED = 50 -- studs/с вверх
Config.CAR_HITBOX_H = 7.5 -- верх невидимой «шапки» легковушки (такси, полиция): выше прыжка + 1 stud
Config.JUMP_COOLDOWN = 0.6 -- сек между прыжками
Config.JUMP_GROUND_DIST = 1.3 -- после прыжка «в воздухе», пока центр саней выше этого над снегом (обычно ~0.5)

------------------------------------------------------------------ ТРЮКИ (в воздухе)
-- Клиент копит завершённые трюки за один полёт и при приземлении шлёт список серверу.
-- kind: pitch (вокруг поперечной оси, dir −1 назад / +1 вперёд), roll (вокруг продольной),
-- yaw (вокруг вертикали, направление движения не меняется), grab (без вращения — наклон саней).
-- minAir — минимальное время в воздухе (с), coins — монет за один, boost — × скорость при чистом приземлении.
Config.TRICK_ORDER = { "flip", "frontflip", "roll", "spin", "grab" }
Config.TRICKS = {
	flip = { name = "Сальто", input = "держать Пробел / 🔄", coins = 15, boost = 1.12, minAir = 0, icon = "flip", kind = "pitch", dir = -1 },
	frontflip = { name = "Переднее сальто", input = "Пробел + S/↓ (руль вперёд)", coins = 20, boost = 1.15, minAir = 0, icon = "flip", kind = "pitch", dir = 1 },
	roll = { name = "Бочка", input = "Пробел + A/D (руль вбок)", coins = 20, boost = 1.12, minAir = 0, icon = "sparkles", kind = "roll" },
	spin = { name = "Разворот 360", input = "Пробел дважды в воздухе", coins = 25, boost = 1.1, minAir = 0, icon = "star", kind = "yaw" },
	grab = { name = "Грэб", input = "короткий тап Пробела (< 0.2 с)", coins = 8, boost = 1.0, minAir = 0.4, icon = "parachute", kind = "grab" },
}
Config.TRICK_COMBO_MULT = { 1, 1.5, 2 } -- множитель монет за 1 / 2 / 3+ разных трюков в одном полёте
Config.TRICK_MAX_COUNT = 5 -- больше одного трюка одного вида за полёт сервер не засчитывает
Config.TRICK_TAP_TIME = 0.2 -- сек: короче — «грэб», дольше — вращение
Config.TRICK_DOUBLE_TAP = 0.35 -- сек между нажатиями для «разворота»
Config.GRAB_TIME = 0.5 -- сек: сколько длится наклон саней в грэбе
function Config.trickComboMult(distinct: number): number
	local m = Config.TRICK_COMBO_MULT
	return m[math.clamp(distinct, 1, #m)]
end
-- Авто-трюки (#39, как в Sled Surfers): в полёте трюк запускается сам. Клиент, как только сани
-- поднялись выше AC_AIR_HEIGHT над снегом (значит, полёт видит и сервер), предсказывает время
-- полёта по вертикальной скорости и высоте над трассой (луч вниз под санями и на AUTO_TRICK_LOOKAHEAD
-- с вперёд) и берёт последний ярус AUTO_TRICK_PLANS, чей air ≤ предсказанного: options[1] — по
-- умолчанию, с вероятностью AUTO_TRICK_RANDOM — случайный другой вариант. Скорость вращения
-- авто-трюка каждый кадр подбирается так, чтобы оборот закончился за AUTO_TRICK_MARGIN до касания
-- (в пределах AUTO_TRICK_MIN_SPEED…MAX_SPEED); не успел — трюк молча не засчитывается, «Падения» нет.
-- Нажатие Пробела/🔄 во время авто-трюка добавляет в комбо ещё один, ещё не сделанный трюк.
Config.AUTO_TRICKS = 1 -- 1 — авто-трюки включены, 0 — только ручные (как до #39)
Config.AUTO_TRICK_PLANS = {
	{ air = 0.5, options = { { "grab" }, { "spin" } } }, -- короткий полёт: грэб / разворот
	{ air = 0.9, options = { { "flip" }, { "frontflip" }, { "roll" } } }, -- сальто
	{ air = 1.5, options = { { "flip", "grab" }, { "roll", "grab" }, { "frontflip", "spin" } } },
	{ air = 2.2, options = { { "flip", "roll", "grab" }, { "frontflip", "spin", "grab" }, { "roll", "flip", "grab" } } },
}
Config.AUTO_TRICK_RANDOM = 0.3 -- доля полётов, где вместо варианта по умолчанию — случайный другой
Config.AUTO_TRICK_MARGIN = 0.12 -- с: оборот заканчивается не позже чем за столько до касания
Config.AUTO_TRICK_MIN_SPEED = 6 -- рад/с: медленнее не крутим (длинный полёт — плавный трюк)
Config.AUTO_TRICK_MAX_SPEED = 22 -- рад/с: быстрее не докручиваем (оборот за 0.29 с)
Config.AUTO_TRICK_SAFE_AIR = 0.7 -- оборотов в плане ≤ maxRotations(предсказанный полёт × это): запас к серверному полёту
Config.AUTO_TRICK_RAY = 120 -- studs: луч вниз для высоты над трассой
Config.AUTO_TRICK_LOOKAHEAD = 0.4 -- с: где по горизонтали мерить второй луч (наклон трассы впереди)
Config.AUTO_TRICK_UNKNOWN_AIR = 0.6 -- с: оценка остатка полёта, если луч не нашёл снег (обрыв глубже луча)

-- Сколько полных оборотов физически влезает в полёт (для серверной проверки)
function Config.maxRotations(airTime: number): number
	return 1 + math.floor(math.max(0, airTime) * Config.FLIP_SPEED / (2 * math.pi))
end

------------------------------------------------------------------ АПГРЕЙДЫ
-- 4 апгрейда как в оригинале. Ракета качается за гемы, остальные — за монеты.
-- Каждые TIER_SIZE уровней — новый «тир»: меняется вид рогатки/санок, а переход на него стоит гемы.
-- step — уровней за одну покупку: у ракеты (#47) = TIER_SIZE, без промежуточных делений — каждая
-- покупка сразу следующая ракета (уровень хранится в прежней шкале 0…30, кратно 5: тир = ур. // 5,
-- поэтому rocketFuel/tierOf/обвес саней работают без изменений).
Config.TIER_SIZE = 5
Config.UPGRADES = {
	Launch = { title = "Рогатка", icon = "🎯", color = Color3.fromRGB(225, 80, 70), BaseCost = 100, Growth = 1.01, MaxLevel = 50 },
	Sled = { title = "Сани", icon = "🛷", color = Color3.fromRGB(60, 130, 230), BaseCost = 130, Growth = 1.01, MaxLevel = 50 },
	Income = { title = "Доход", icon = "💰", color = Color3.fromRGB(235, 165, 35), BaseCost = 180, Growth = 1.02, MaxLevel = 50 },
	Rocket = { title = "Ракета", icon = "🚀", color = Color3.fromRGB(240, 115, 45), MaxLevel = 30, gems = true, step = 5 },
}
Config.UPGRADE_ORDER = { "Launch", "Sled", "Income", "Rocket" }
-- Цена следующей ракеты в гемах (#47): [1] — Петарда → Ракета, …, [6] — Гиперджет → Плазменный.
-- = сумма прежних цен 5 уровней тира (1 + ур./3): 7, 15, 23, 32, 40, 48 — всего 165, как было.
Config.ROCKET_TIER_PRICES = { 7, 15, 23, 32, 40, 48 }

-- Названия тиров (показываются при получении: «ПОЛУЧЕНА СТАЛЬНАЯ РОГАТКА!»)
-- Названия тиров: новый тир каждые TIER_SIZE уровней (рогатка/сани/доход — до 50 ур., ракета — до 30)
Config.TIERS = {
	Launch = {
		"Деревянная рогатка", "Стальная рогатка", "Мега-рогатка", "Силовая рогатка", "Золотая рогатка", "Неоновая рогатка",
		"Ледяная рогатка", "Огненная рогатка", "Техно-рогатка", "Радужная рогатка", "Галактическая рогатка",
	},
	Sled = {
		"Обычные санки", "Фары", "Спойлер", "Обтекатель", "Золотой бампер", "Неоновая подсветка",
		"Флажок", "Боковые крылья", "Хромированные выхлопы", "Сияние", "Корона чемпиона",
	},
	Income = {
		"Копилка", "Мешок монет", "Сундук", "Сейф", "Банк", "Золотой банк",
		"Монетный двор", "Сокровищница", "Алмазный сейф", "Золотая гора", "Империя монет",
	},
	Rocket = { "Петарда", "Ракета", "Турбо-ракета", "Мега-двигатель", "Бласт-двигатель", "Гиперджет", "Плазменный двигатель" },
}
-- ЗВУК (client/Sounds; docs/GAME_DESIGN.md → «Звук»). Не баланс — кроме громкостей в TUNABLES.
-- Фоновая музыка: первый загрузившийся трек — лобби, в заезде — другой загрузившийся по миру
-- (RunTheme), переход кроссфейдом. Свой трек: залить аудио и поставить его ID первым.
Config.MUSIC_IDS = { 125871106395463, 132489602913551, 140520386514181 }
Config.MUSIC_VOLUME = 0.16 -- громкость трека (≤ 0.2: музыка не спорит с эффектами)
Config.MUSIC_RUN_MULT = 0.6 -- в заезде музыка тише (ветер и скольжение важнее)
Config.MUSIC_FADE = 1.5 -- сек кроссфейда лобби ↔ заезд
Config.SOUND_SET = 1 -- 0 встроенные · 1 v1 (синтез) · 2 v2 (записи); см. shared/AudioSet
Config.SOUND = {
	-- громкость каналов SoundGroup (выключатели ⚙ «Звуки»/«Музыка» глушат каналы целиком)
	groups = { Music = 1, SFX = 0.9, UI = 0.55, Ambience = 0.8 },
	duck = 0.3, -- музыка на важных событиях (финиш, авария, награды) падает до 30 %…
	duckRelease = 2.5, -- …и за столько секунд возвращается
	jitter = 0.06, -- случайность тона повторов ±6 %
	coinWindow = 0.6, -- монеты чаще этого — серия, тон растёт по мажорной гамме
	coinStreakMax = 7, -- 8-я монета серии — на октаву выше первой, дальше не растёт
	loopFullSpeed = 140, -- скорость, на которой ветер/скольжение звучат в полную силу
	moverRadius = 140, -- 3D-моторы машин/поездов слышны в этом радиусе…
	moverMax = 3, -- …у стольких ближайших
	-- событие → { громкость, канал, копий одновременно }. Звуки атласа v2 выровнены по громкости (RMS −16 dBFS
	-- у one-shot, −22 у лупов), поэтому числа ниже — и есть микс: UI тише, удары и награды заметны,
	-- скольжение — фоном. Правятся в DEV → «Звуки» (−/+ и «Сохранить») = TUNABLES «Звук: события».
	sfx = {
		click = { 0.5, "UI", 2 }, open = { 0.5, "UI", 2 }, deny = { 0.6, "UI", 2 }, buy = { 0.7, "UI", 2 },
		claim = { 0.55, "UI", 2 }, chest = { 0.8, "UI", 1 }, ready = { 0.7, "UI", 1 }, task = { 0.7, "UI", 1 },
		reveal = { 0.8, "UI", 1 }, tierup = { 0.9, "UI", 1 },
		coin = { 0.45, "SFX", 4 }, gem = { 0.6, "SFX", 2 }, crystal = { 0.8, "SFX", 2 },
		shield = { 0.7, "SFX", 1 }, shieldhit = { 0.8, "SFX", 1 }, x2 = { 0.7, "SFX", 1 }, magnet = { 0.65, "SFX", 1 },
		fuel = { 0.7, "SFX", 1 }, ring = { 0.6, "SFX", 2 }, boost = { 0.7, "SFX", 2 }, spring = { 0.75, "SFX", 1 },
		launch = { 0.9, "SFX", 1 }, jump = { 0.6, "SFX", 2 }, land = { 0.7, "SFX", 2 }, spin = { 0.5, "SFX", 2 },
		flip = { 0.65, "SFX", 2 }, wipe = { 0.8, "SFX", 1 }, smash = { 0.8, "SFX", 3 }, crash = { 1, "SFX", 1 },
		fall = { 0.8, "SFX", 1 }, rocket_on = { 0.7, "SFX", 1 }, rocket_off = { 0.6, "SFX", 1 },
		finish = { 0.85, "SFX", 1 }, record = { 0.8, "SFX", 1 }, horn = { 0.9, "Ambience", 2 },
		-- лупы: громкость в полную силу (скорость ≥ loopFullSpeed). Скольжение тихо, фоном (жалоба владельца
		-- на v1: «шум санок сильно громкий»): снег 0.22 атласа v2 ≈ на 9 дБ тише v1 при 0.5 (≈ уровень
		-- временного 0.15 у v1), ветер 0.45 ≈ v1 при 0.25.
		wind = { 0.45, "Ambience", 1 }, snow = { 0.22, "SFX", 1 }, ice = { 0.22, "SFX", 1 }, hard = { 0.22, "SFX", 1 },
		rocket = { 0.55, "SFX", 1 }, stretch = { 0.6, "SFX", 1 }, car = { 0.6, "Ambience", 1 }, train = { 0.8, "Ambience", 1 },
	},
	-- Звук из Roblox Creator Store вместо куска атласа: событие → asset ID (аудио «by Roblox» из
	-- create.roblox.com/store/audio играет в любой игре без загрузки и лимита). Играет весь ассет целиком;
	-- пусто — атлас. Проверить — DEV → «Звуки» (источник покажет «Roblox ID»). Пример: coin = 1234567890.
	library = {} :: { [string]: number },
}

function Config.tierOf(level: number): number
	return level // Config.TIER_SIZE
end
function Config.tierName(name: string, level: number): string
	local list = Config.TIERS[name]
	return list[math.min(Config.tierOf(level) + 1, #list)]
end

-- Коэффициенты формул прокачки (настраиваются в панели разработчика)
Config.F = {
	launchBase = 48, launchStep = 6, -- сила рогатки = база + шаг × уровень
	fuelBase = 0.6, fuelStep = 0.15, -- топливо ракеты, сек (владелец 2026-11-12: «замедли ракету», было 0.3)
	frictionBase = 10, frictionDecay = 0.965, -- трение = база × спад^уровень (2026-11-12: было 9.5 — слабые сани катились слишком далеко)
	speedBase = 100, speedStep = 5, -- потолок скорости: наклон на 0-м уровне (studs/с за уровень)
	speedSoftCap = 200, -- асимптота потолка: выше него потолок не поднимется ни на каком уровне
	-- Устойчивость «Саней» (#60): потеря скорости от TNT, разбитого препятствия, щита и «Падения»
	-- меньше на stabilityStep за уровень, но не больше чем на stabilityMax (0.025 / 0.5 → потолок на 20-м
	-- уровне = тир «Золотой бампер»). Расчёт и таблица — docs/GAME_DESIGN.md → «Устойчивость».
	stabilityStep = 0.025,
	stabilityMax = 0.5,
	incomeStep = 0.15, -- множитель монет = 1 + шаг × уровень
	finishPerLevel = 100, -- бонус за финиш = это × уровень
	rewardGrowth = 0.25, -- рост монетных наград с уровнем
}
function Config.launchSpeed(level: number): number
	return Config.F.launchBase + Config.F.launchStep * level
end
function Config.rocketFuel(level: number): number
	return Config.F.fuelBase + Config.F.fuelStep * level -- секунд
end
function Config.friction(level: number): number
	return Config.F.frictionBase * Config.F.frictionDecay ^ level
end
-- Потолок скорости с убывающим ростом: стартует как base + step·level, но плавно упирается в
-- speedSoftCap (0 → 100, 10 → 139, 20 → 163, 30 → 177, 50 → 191 при 100/5/200).
-- Расчёт и таблица «уровень → скорость → время смены полосы» — docs/GAME_DESIGN.md.
function Config.maxSpeed(level: number): number
	local base, step, cap = Config.F.speedBase, Config.F.speedStep, Config.F.speedSoftCap
	local span = cap - base
	if span <= 0 or step <= 0 then
		return base -- кап ниже базы или нулевой шаг: потолок не растёт
	end
	return cap - span * math.exp(-step * level / span)
end
-- Доля потери скорости, которую гасят сани уровня level (0 … stabilityMax)
function Config.stability(level: number): number
	return math.clamp(Config.F.stabilityStep * math.max(0, level), 0, math.max(0, Config.F.stabilityMax))
end
-- Множитель скорости после удара с учётом устойчивости: потеря (1 − keep) × (1 − stability).
-- keepSpeed(0.7, 0) = 0.7; keepSpeed(0.7, 20) = 0.85 (TNT); keepSpeed(0.6, 20) = 0.8 («Падение»).
function Config.keepSpeed(keep: number, level: number): number
	return 1 - (1 - keep) * (1 - Config.stability(level))
end
function Config.incomeMult(level: number): number
	return 1 + Config.F.incomeStep * level
end

-- Цена следующего уровня: (сколько, валюта "Coins" | "Gems").
-- Монеты: BaseCost × (1 + уровень)^UPGRADE_PRICE_POW × Growth^уровень. Степенная часть дорожает
-- быстро в начале (×4, ×2.3, ×1.8 …) и полого к концу — как растёт доход за заезд; Growth — хвост.
-- Модель (#31): 1-я покупка после 1-го заезда, далее раз в 2–4 заезда, лестница 3×50 ≈ 60 ч игры.
Config.UPGRADE_PRICE_POW = 2.6 -- владелец 2026-11-12: «апгрейд дороже» (было 2; модель docs/ECONOMY_SIM.md)
function Config.upgradePrice(name: string, level: number): (number, string)
	local u = Config.UPGRADES[name]
	if u.gems then
		local list = Config.ROCKET_TIER_PRICES
		return list[math.clamp(level // Config.TIER_SIZE + 1, 1, #list)], "Gems"
	end
	if level > 0 and level % Config.TIER_SIZE == 0 then
		return 1 + level // (Config.TIER_SIZE * 2), "Gems" -- переход на новый тир
	end
	return math.floor(u.BaseCost * (1 + level) ^ Config.UPGRADE_PRICE_POW * u.Growth ^ level), "Coins"
end
-- Уровень после покупки: +1, у апгрейда со step — до следующей границы тира (ракета: 0 → 5 → … → 30)
function Config.upgradeNext(name: string, level: number): number
	local u = Config.UPGRADES[name]
	local step = u.step or 1
	return math.min((level // step + 1) * step, u.MaxLevel)
end
-- совместимость со старым кодом
function Config.upgradeCost(name: string, level: number): number
	return (Config.upgradePrice(name, level))
end

------------------------------------------------------------------ ГЕМЫ
Config.GEMS_FINISH = 3 -- за пройденный уровень
Config.GEMS_NEW_BEST = 1 -- за новый рекорд на уровне
-- Новый рекорд дистанции на уровне (#59, server/Runs endRun): монеты заезда × это — только когда рекорд
-- (% уровня, LevelBest) улучшен; не на финише (там свой бонус), не в фарме, не за повтор. 1 — выключено.
Config.NEW_BEST_COIN_MULT = 1.15
-- Рубежи дистанции (#61): арка-маркер над трассой каждые STEP м (studs пути, как «N м» в HUD) —
-- 250, 500, 750…; за каждый рубеж один раз за заезд COINS монет (каждый BIG_EVERY-й — BIG_COINS), в
-- итог идут с множителями дохода (чип «рубежи»). Засчитывает сервер по пути, прошедшему античит
-- (run.distance, server/Runs). Рубеж ближе FINISH_GAP к финишу не ставится (там своя арка). Арки —
-- декор (Track/Milestones): без коллизий и лучей, без Random — раскладка трассы не меняется.
Config.MILESTONES = {
	STEP = 250, -- м между рубежами (0 — выключено)
	COINS = 10, -- монет за рубеж
	BIG_EVERY = 4, -- каждый N-й рубеж (1000, 2000 м…) — большой
	BIG_COINS = 30, -- монет за большой рубеж
	FINISH_GAP = 60, -- м: ближе к финишу рубежа нет
	CONFETTI = 14, -- конфетти при рубеже (у рекорда — CONFETTI_COUNT)
}
Config.GEMS_FARM_FINISH = 1 -- финиш в уже пройденном мире (фарм): уровень не растёт

-- Robux-товары (Developer Products). Владелец создаёт их в Creator Dashboard
-- (Monetization → Developer Products) и вписывает сюда ID; при id = 0 кнопка покажет «скоро».
Config.PRODUCTS = {
	SkipWorld = { id = 0, price = 49 }, -- пропуск текущего мира: сразу на 1-й уровень следующего
}

-- Уровень, на котором едем при фарме мира (последний, самый длинный уровень мира)
function Config.farmLevel(world: number): number
	return world * Config.LEVELS_PER_WORLD
end

------------------------------------------------------------------ СКИНЫ ВАТРУШЕК (за монеты)
-- tube — основной цвет, rim — бортик, neon — светится

------------------------------------------------------------------ САНИ С РЕДКОСТЯМИ (как в Roblox-референсе)
-- Модель открывается с миром; у каждой 5 редкостей. Редкость покупается по порядку и даёт +% скорости.
Config.RARITIES = {
	{ name = "Обычная", bonus = 0 },
	{ name = "Gold", bonus = 2, color = Color3.fromRGB(245, 195, 60), material = Enum.Material.SmoothPlastic, shine = 0.25 },
	{ name = "Diamond", bonus = 4, color = Color3.fromRGB(160, 225, 255), material = Enum.Material.Glass, shine = 0.2 },
	{ name = "Ruby", bonus = 7, color = Color3.fromRGB(220, 40, 70), material = Enum.Material.SmoothPlastic, shine = 0.15 },
	-- Galaxy: тёмно-фиолетовый глянец, светятся только акценты (иначе неон «съедает» детали модели)
	{ name = "Galaxy", bonus = 10, color = Color3.fromRGB(95, 45, 200), material = Enum.Material.SmoothPlastic, shine = 0.2 },
}
-- Сани: модель открывается с миром; main/accent — цвета обычной редкости
Config.SLEDS = {
	{ id = "tube", name = "Ватрушка", icon = "🍩", img = "donut", world = 1, bonus = 0, prices = { 0, 300, 900, 2400, 6000 }, main = Color3.fromRGB(240, 70, 120), accent = Color3.fromRGB(255, 160, 195) },
	{ id = "saucer", name = "Ледянка", icon = "🥏", img = "saucer", world = 1, bonus = 2, prices = { 250, 700, 1800, 4500, 10000 }, main = Color3.fromRGB(60, 150, 245), accent = Color3.fromRGB(255, 220, 70) },
	{ id = "board", name = "Доска", icon = "🏂", img = "snowboard", world = 1, bonus = 3, prices = { 700, 1500, 3500, 8000, 18000 }, main = Color3.fromRGB(70, 130, 230), accent = Color3.fromRGB(255, 200, 60) },
	{ id = "toboggan", name = "Тобоган", icon = "🪵", img = "toboggan", world = 2, bonus = 5, prices = { 2500, 5500, 12000, 25000, 50000 }, main = Color3.fromRGB(196, 132, 76), accent = Color3.fromRGB(200, 50, 50) },
	{ id = "classic", name = "Деревянные санки", icon = "🛷", img = "sled", world = 2, bonus = 6, prices = { 4000, 8000, 16000, 32000, 60000 }, main = Color3.fromRGB(186, 128, 74), accent = Color3.fromRGB(190, 40, 40) },
	{ id = "kayak", name = "Снежный каяк", icon = "🛶", img = "canoe", world = 3, bonus = 8, prices = { 9000, 18000, 36000, 72000, 140000 }, main = Color3.fromRGB(250, 170, 40), accent = Color3.fromRGB(40, 60, 90) },
	{ id = "plane", name = "Сани-самолёт", icon = "✈", img = "plane", world = 3, bonus = 10, prices = { 15000, 30000, 60000, 120000, 240000 }, main = Color3.fromRGB(225, 55, 55), accent = Color3.fromRGB(245, 245, 250) },
	{ id = "bobsled", name = "Бобслей", icon = "🏎", img = "racecar", world = 4, bonus = 13, prices = { 30000, 60000, 120000, 240000, 480000 }, main = Color3.fromRGB(40, 90, 210), accent = Color3.fromRGB(240, 240, 250) },
	{ id = "snowmobile", name = "Снегоход", icon = "🛵", img = "scooter", world = 5, bonus = 17, prices = { 70000, 140000, 280000, 560000, 1100000 }, main = Color3.fromRGB(230, 200, 30), accent = Color3.fromRGB(30, 32, 40) },
}
function Config.sled(id: string?)
	for _, s in Config.SLEDS do
		if s.id == id then
			return s
		end
	end
	return Config.SLEDS[1]
end
-- Общий бонус скорости (доля): модель + редкость
function Config.sledBonus(id: string?, rarity: number?): number
	local s = Config.sled(id)
	local r = Config.RARITIES[math.clamp(rarity or 1, 1, #Config.RARITIES)]
	return (s.bonus + r.bonus) / 100
end

------------------------------------------------------------------ СЛЕДЫ (шлейф за санками, +% монет)
Config.TRAILS = {
	{ id = "white", name = "Снежный", color = Color3.fromRGB(235, 245, 255), bonus = 0, price = 0 },
	{ id = "orange", name = "Апельсин", color = Color3.fromRGB(255, 150, 50), bonus = 10, price = 600 },
	{ id = "yellow", name = "Солнце", color = Color3.fromRGB(255, 225, 60), bonus = 15, price = 1500 },
	{ id = "green", name = "Лайм", color = Color3.fromRGB(110, 230, 90), bonus = 25, price = 4000 },
	{ id = "blue", name = "Океан", color = Color3.fromRGB(70, 150, 255), bonus = 30, price = 9000 },
	{ id = "purple", name = "Аметист", color = Color3.fromRGB(170, 90, 255), bonus = 35, price = 16000 },
	{ id = "pink", name = "Фламинго", color = Color3.fromRGB(255, 110, 190), bonus = 45, price = 30000 },
	{ id = "rainbow", name = "Радуга", color = Color3.fromRGB(255, 80, 80), bonus = 60, price = 60000, rainbow = true },
	-- эксклюзивные (#56): только наградой за задание недели (WEEKLY_QUEST.TRAILS), не продаются (Shop.trailAction
	-- отказывает); color → color2 — градиент ленты. +20 % монет: между «Солнцем» (1500) и «Лаймом» (4000) —
	-- ощутимо для новичка, не обгоняет купленные старшие следы (коллекция, а не сила).
	{ id = "aurora", name = "Северное сияние", color = Color3.fromRGB(60, 230, 170), color2 = Color3.fromRGB(150, 90, 255), bonus = 20, price = 0, exclusive = true },
	{ id = "comet", name = "Комета", color = Color3.fromRGB(255, 245, 200), color2 = Color3.fromRGB(80, 150, 255), bonus = 20, price = 0, exclusive = true },
	{ id = "frost", name = "Иней", color = Color3.fromRGB(200, 245, 255), color2 = Color3.fromRGB(40, 120, 220), bonus = 20, price = 0, exclusive = true },
	{ id = "ember", name = "Уголёк", color = Color3.fromRGB(255, 210, 60), color2 = Color3.fromRGB(230, 50, 30), bonus = 20, price = 0, exclusive = true },
}
-- Превью следа в окне «Следы» (client/LobbyMenus, #7): нарисованная лента из кружков за иконкой
-- саней (объект Trail во ViewportFrame не рисуется). Только вид — не баланс, в TUNABLES не входит.
Config.TRAIL_PREVIEW = {
	SEGMENTS = 9, -- кружков в ленте (дёшево: 9 Frame, анимация только пока окно открыто)
	SPACING = 17, -- логических px между кружками по X
	SPEED = 2.6, -- рад/с: частота покачивания саней
	BOB = 16, -- логических px: размах покачивания
	LAG = 0.5, -- рад: отставание фазы на каждый следующий кружок (лента «волной»)
	TILT = 9, -- град.: наклон иконки саней на подъёме/спуске
	LINES_SPEED = 160, -- логических px/с: «ветер» (полоски скорости) справа налево
	RAINBOW_SPEED = 0.35, -- оборотов палитры радуги в секунду
}
function Config.trail(id: string?)
	for _, t in Config.TRAILS do
		if t.id == id then
			return t
		end
	end
	return Config.TRAILS[1]
end

------------------------------------------------------------------ ЭКОНОМИКА
Config.STUDS_PER_COIN = 4
Config.COIN_PICKUP_VALUE = 3
-- Монеты за трюки — в Config.TRICKS[id].coins (× Config.trickComboMult за разные трюки в полёте)
function Config.finishBonus(level: number): number
	return Config.F.finishPerLevel * level
end
Config.GAMEPASS_X2_COINS = 0 -- ID геймпасса «x2 монеты» (0 = выкл)

-- Идеальный запуск (#58, server/RunEvents Launch): натяг дошёл до зоны PERFECT_ZONE (жёлтые деления
-- шкалы) — с этого момента PERFECT_WINDOW секунд на отпускание → стартовая скорость × PERFECT_LAUNCH_MULT.
-- Окно — одно на натяг (первый вход в зону). Решает сервер: клиент сообщает начало натяга ("pull") и
-- сколько секунд прошло от входа в зону до отпускания; сервер проверяет окно, силу ≥ зоны и что от
-- начала натяга по его часам до входа в зону прошло ≥ PERFECT_MIN_PULL (с запасом PERFECT_LAG на пинг).
Config.PERFECT_ZONE = 0.9 -- доля натяга: начало зоны «ИДЕАЛЬНО» (клавиша: 0.99 с удержания из 1.1)
Config.PERFECT_WINDOW = 0.15 -- с от входа в зону до отпускания
Config.PERFECT_LAUNCH_MULT = 1.1 -- × стартовой скорости (1 — механика выключена)
Config.PERFECT_MIN_PULL = 0.2 -- с от начала натяга до входа в зону (быстрее честно не натянуть)
Config.PERFECT_LAG = 0.1 -- с: разброс пинга между «натянул» и «отпустил»

------------------------------------------------------------------ АНТИЧИТ (server/AntiCheat)
-- Санки считает клиент (network ownership), сервер проверяет правдоподобие. Предел скорости —
-- «огибающая» env: максимум скорости, который честный игрок мог набрать к этому моменту.
--   старт: max(рогатка launchSpeed(L) — до ~348 на 50 ур., потолок саней maxSpeed × (1 + бонус)
--   — до 200 × 1.27, терминал ракеты на земле √((ROCKET_THRUST + GRAVITY_ALONG·sin16°) / DRAG)
--   ≈ 217: выше него ракета на земле не разгоняет — сопротивление сильнее тяги);
--   + (тяга + гравитация) × время полёта, пока есть топливо (в воздухе сопротивления нет);
--   + BOOST_ADD за каждый засчитанный ускоритель; × буст трюков (тот же, что у клиента);
--   на земле спадает не быстрее AC_DECAY × DRAG × v² (честные сани тормозят быстрее).
-- Предел прогресса за тик = (env × AC_SPEED_MULT + AC_SPEED_ADD) × dt. Моделирование
-- (scratchpad: уровни 0/10/30/50, бонус 0/27 %, ракета, цепочки трамплинов, сальто ×2.25,
-- ускорители, канистры): честная скорость ≤ 1.93 env, отставание засчитанного пути ≤ 0.3 с
-- предела — при допуске AC_LAG_SEC = 1.5 с флагов нет.
Config.AC_SPEED_MULT = 1.25 -- запас на рывки репликации и боковой руль (до 1.1 × скорости)
Config.AC_SPEED_ADD = 30 -- studs/с: трамплин держит не меньше RAMP_MIN_SPEED = 30
Config.AC_DECAY = 0.5 -- доля сопротивления DRAG·v², на которую спадает огибающая на земле
Config.AC_LAG_SEC = 1.5 -- флаг, если реальный путь ушёл вперёд засчитанного больше, чем на столько секунд предела
-- Телепорт = заезд окончен: сдвиг по горизонтали за тик > AC_TELEPORT_STUDS + предел × dt ×
-- AC_TELEPORT_MULT. На 0 ур. за тик 0.2 с это 150 + 301·0.2·2 ≈ 270 studs, на 50 ур. ≈ 336 —
-- перенос на 500 studs ловится; честный рывок даже при 1.93 env — не больше 0.39 env за тик.
Config.AC_TELEPORT_STUDS = 150
Config.AC_TELEPORT_MULT = 2
Config.AC_DT_MAX = 3 -- сек: дольше «заморозки» позиции (лаг) не накапливаем допуск
-- Полёт по серверу: луч вниз от саней до трассы длиннее AC_AIR_HEIGHT. Центр саней на снегу
-- ~0.5 над поверхностью (на борту жёлоба 74° ≈ 1.8 по вертикали); прыжок поднимает на ~6.4
-- (JUMP_SPEED² / 2g при 50). Самый короткий честный полёт с наградой — грэб, 0.4 с: на ровном он
-- выше 2.5 studs ≈ 0.24 с (≥ 1 серверный тик 0.2 с); прыжок 0.51 с — выше порога ≈ 0.40 с (2 тика),
-- засчитанный полёт ≥ 0.2 + AC_AIR_GRACE = 0.6 ≥ 0.51 — честный прыжок с грэбом/разворотом без
-- урезания; полёт 0.6 с (AIR_MIN_TIME) — ≈ 0.51 с выше порога (≥ 2 тика).
-- Монеты за полёт = min(время клиента, полёт по серверу + AC_AIR_GRACE).
Config.AC_AIR_HEIGHT = 2.5
Config.AC_AIR_GRACE = 0.4 -- сек: взлёт/посадка ниже порога + шаг тика 0.2 с
-- Дольше этого в воздухе без земли — флаг (полёт-чит). Честный худший случай — трамплин на 50 ур.:
-- вверх 0.45·348 ≈ 157 studs/с, обрыв 22 + склон 16° уходит вниз → ≈ 2.8 с.
Config.AC_MAX_AIR = 6
-- Бонус/препятствие засчитываем, если оно ближе AC_NEAR_RADIUS + скорость × AC_NEAR_LAG:
-- серверная позиция саней отстаёт от клиентской на пинг (на 350 studs/с за 0.2 с это 70 studs).
Config.AC_NEAR_RADIUS = 30
Config.AC_NEAR_LAG = 0.3
Config.AC_FLAG_LIMIT = 6 -- столько мягких нарушений за заезд = заезд не засчитан
Config.AC_FLAG_COOLDOWN = 2 -- сек: одно и то же нарушение по позиции считаем не чаще

------------------------------------------------------------------ ЛИДЕРБОРД НЕДЕЛИ (#26, server/Weekly)
-- Неделя ISO по UTC (shared/Week), сброс в понедельник 00:00 UTC. Доски (OrderedDataStore, ключ
-- u_<UserId>): лучшая дистанция за заезд в мире N — LB_W<год>-<нед>_<N>; чистые финиши недели —
-- LB_W<год>-<нед>_clean. Топ-3 прошлой недели — титул на неделю (WeeklyWinners_v1).
-- Бюджет запросов — docs/ARCHITECTURE.md → «Лидерборд недели».
Config.WEEKLY = {
	REFRESH = 60, -- с: опрос досок и обновление табло
	WRITE_EVERY = 30, -- с: запись игрока в доски не чаще (лимит ключа — 1 запись / 6 с)
	FLUSH_TICK = 5, -- с: проверка очереди записей
	PAGE = 100, -- записей с доски за один запрос (место игрока — в первой сотне)
	SHOW = 10, -- строк на табло
	MAX_FLAGS = 2, -- заезд с ≥ стольких флагов античита в доску не идёт (≥ AC_FLAG_LIMIT — уже «cheat»)
	MAX_AVG_SPEED = 400, -- studs/с: путь ≤ время с выстрела × это (страховка поверх AntiCheat)
	BUDGET_RESERVE = 2, -- запросов в бюджете DataStore оставляем остальным системам
	WINNERS_DELAY = 180, -- с после сброса: ждём последние записи прошлой недели, потом считаем топ-3
	PAGE_SEC = 8, -- с: смена страницы табло (неделя мира → чистые финиши → всё время)
	-- по месту в прошлой неделе (лучшее из досок, где игрок играл); kind — цвет плашки UI.KIND
	TITLES = {
		{ id = "gold", name = "Чемпион недели", icon = "👑", kind = "yellow" },
		{ id = "silver", name = "Серебро недели", icon = "🥈", kind = "grey" },
		{ id = "bronze", name = "Бронза недели", icon = "🥉", kind = "orange" },
	},
}

-- Пьедестал топ-3 недели в лобби (#48): Lobby.PLAN.top3 — место, server/Podium — аватары.
-- Обновляется вместе с табло (WEEKLY.REFRESH); аватар пересоздаётся только при смене игрока на месте.
Config.PODIUM = {
	BOARD = "clean", -- доска из WeeklyBoard: «чистые финиши недели» — одна на всех миров
	MAX_DIST = 160, -- studs: дальше таблички и «?» не рисуются
	CACHE = 6, -- аватаров в кэше сервера (топ-3 + недавно выбывшие — если вернутся, не грузим заново)
	WAVE_EVERY = 6, -- с: 2-е и 3-е место по очереди машут рукой
	-- бесплатные анимации Roblox (эмоции стандартного Animate): 1-е — «ура», 2–3 — стойка и взмах
	ANIM = {
		R15 = { win = 507770677, idle = 507766388, wave = 507770239 },
		R6 = { win = 129423030, idle = 180435571, wave = 128777973 },
	},
}

------------------------------------------------------------------ НАСТРОЙКА В ИГРЕ
-- Параметры, которые владелец меняет в панели разработчика (вкладка «Настройка»).
-- Изменения хранятся в DataStore и применяются на всех серверах без перевыпуска игры.
-- { путь в Config, подпись, группа, мин, макс, шаг }
-- Обучение первых заездов (#27, client/Tutorial): одна подсказка за раз, исчезает по действию.
-- Порядок = номер бита в сейве (DataService.Tutorial) — НЕ переставлять, только дописывать в конец.
-- where: "lobby" | "run"; pc/touch — текст для клавиатуры и для телефона (≤ 6 слов).
-- Сворачивание панели апгрейдов в лобби (client/HUD, #11): время выезда карточек вниз/вверх, с
Config.UPGRADES_PANEL_TWEEN = 0.3

Config.TUTORIAL = {
	MAX_RUNS = 3, -- с этого заезда подсказок нет (в заезде — с MAX_RUNS-го, в лобби — после него)
	IDLE = 5, -- с бездействия в лобби до подсказки «к саням»
	HOLD = 7, -- с: подсказка в заезде висит не дольше (потом считается показанной)
	GAP = 2.5, -- с: пауза между подсказками
	STEER_AHEAD = 40, -- studs до первого ряда препятствий (SAFE_START): показать «руль»
	PULSE = 2.2, -- с: период подсветки карточки апгрейда
	STEPS = {
		{ id = "play", where = "lobby", icon = "sled", pc = "Иди к саням или жми ▼", touch = "Иди к саням или жми ▼" },
		{ id = "launch", where = "run", icon = "bullseye", pc = "Зажми мышь, тяни, отпусти!", touch = "Тяни вниз и отпусти!" },
		{ id = "steer", where = "run", icon = "sled", pc = "A / D — объезжай камни!", touch = "Веди пальцем — объезжай!" },
		{ id = "jump", where = "run", icon = "bolt", pc = "Ctrl — прыжок!", touch = "Жми ⤴ — прыжок!" },
		{ id = "flip", where = "run", icon = "flip", pc = "Трюки сами! Жми Пробел — ещё один", touch = "Трюки сами! Жми 🔄 — ещё один" },
		{ id = "rocket", where = "run", icon = "fire", pc = "Shift — ракета ломает ящики!", touch = "Жми 🔥 — ракета ломает ящики!" },
		{ id = "upgrade", where = "lobby", icon = "star", pc = "Улучши — полетишь дальше!", touch = "Улучши — полетишь дальше!" },
		{ id = "again", where = "lobby", icon = "flag", pc = "Поехали ещё! Жми ▼", touch = "Поехали ещё! Жми ▼" },
	},
}

------------------------------------------------------------------ ПРИЗРАК РЕКОРДА (#62)
-- Клиент пишет траекторию заезда (client/Ghost, сжатие shared/GhostCodec), сервер хранит лучший
-- заезд уровня в DataStore Ghost_v1 (server/Ghosts) и проверяет запись перед сохранением.
-- «Лучший» = финиш быстрее прошлого финиша, иначе — дальше прошлой дистанции.
Config.GHOST_SAMPLE_DT = 0.15 -- сек между сэмплами записи (в записи хранится свой dt)
Config.GHOST_POS_Q = 0.1 -- studs: шаг квантования позиции
Config.GHOST_MAX_SAMPLES = 1700 -- ≈ 255 с при 0.15 (заезд обрывается сервером на 240 с)
Config.GHOST_MAX_CHARS = 24000 -- потолок строки записи (честная — ≤ ~12 символов на сэмпл)
Config.GHOST_MIN_DIST = 60 -- studs: короче — призрак не сохраняем (вылет со старта)
Config.GHOST_UPLOAD_WINDOW = 30 -- сек после конца заезда сервер ждёт запись от клиента
Config.GHOST_FETCH_COOLDOWN = 1 -- сек: запрос призрака не чаще (кэш в памяти сервера — без DataStore)
-- Проверка записи на сервере (дёшево, один проход): длительность ≈ времени заезда по серверу,
-- путь вдоль трассы не назад, точки рядом с трассой, скорость правдоподобная, итог ≈ дистанции
Config.GHOST_TIME_TOL = 2.5 -- сек + 10 % времени заезда
Config.GHOST_DIST_TOL = 80 -- studs + 8 % дистанции: итог записи против засчитанного пути
Config.GHOST_BACK_SLACK = 25 -- studs: насколько путь может «откатиться» назад (кувырок, возврат)
Config.GHOST_MAX_SPEED = 1000 -- studs/с между сэмплами (честный максимум ≈ 1.93 огибающей, ≤ ~700)
Config.GHOST_MAX_SIDE = 200 -- studs вбок от оси куска (конец «улетел» — 2 ширины трассы = 160)
Config.GHOST_MAX_ABOVE = 300 -- studs над дном куска (полёты с трамплинов и островков)
Config.GHOST_BAD_MAX = 6 -- нарушений на запись (возвраты на трассу, рывки) — больше: отказ
-- Вид (клиент; TUNABLES «Призрак»)
Config.GHOST_TRANSPARENCY = 0.6 -- прозрачность саней-призрака
Config.GHOST_TAG_DIST = 220 -- studs: дальше этого подпись «Твой рекорд» не видна
Config.GHOST_HUD_EVERY = 0.2 -- сек между обновлениями «+12 м к рекорду»

Config.TUNABLES = {
	{ "SLOW_BRAKE", "Торможение на малой скорости (studs/с²)", "Прокачка", 0, 40, 1 },
	{ "SLOW_BRAKE_SPEED", "Торможение: ниже этой скорости", "Прокачка", 0, 80, 1 },
	{ "STOP_TIME", "Остановка: секунд на малой скорости", "Прокачка", 0.2, 3, 0.1 },
	{ "LEVEL_LEN_STEP", "Длина: + за уровень внутри мира (studs; новый заезд)", "Трасса", 0, 1500, 50 },
	{ "LEVEL_LEN_WORLD", "Длина: + за мир (studs)", "Трасса", 0, 1000, 25 },
	{ "LEVEL_LEN_MAX", "Длина: потолок (studs)", "Трасса", 1500, 20000, 250 },
	{ "F.launchBase", "Рогатка: сила на 0 ур.", "Прокачка", 10, 200, 1 },
	{ "F.launchStep", "Рогатка: + силы за уровень", "Прокачка", 1, 20, 0.5 },
	{ "UPGRADES.Launch.BaseCost", "Рогатка: цена 1-го ур.", "Прокачка", 5, 1000, 5 },
	{ "UPGRADES.Launch.Growth", "Рогатка: рост цены ×", "Прокачка", 1.01, 1.5, 0.01 },
	{ "F.speedBase", "Сани: потолок скорости на 0 ур.", "Прокачка", 50, 300, 5 },
	{ "F.speedStep", "Сани: + потолка за уровень (на 0 ур.)", "Прокачка", 0, 20, 0.5 },
	{ "F.speedSoftCap", "Сани: асимптота потолка", "Прокачка", 100, 400, 5 },
	{ "F.frictionBase", "Сани: трение на 0 ур.", "Прокачка", 1, 30, 0.5 },
	{ "F.frictionDecay", "Сани: спад трения за ур.", "Прокачка", 0.8, 1, 0.005 },
	{ "F.stabilityStep", "Сани: устойчивость за ур. (доля потери)", "Прокачка", 0, 0.1, 0.005 },
	{ "F.stabilityMax", "Сани: устойчивость, потолок", "Прокачка", 0, 0.9, 0.05 },
	{ "UPGRADES.Sled.BaseCost", "Сани: цена 1-го ур.", "Прокачка", 5, 1000, 5 },
	{ "UPGRADES.Sled.Growth", "Сани: рост цены ×", "Прокачка", 1.01, 1.5, 0.01 },
	{ "F.incomeStep", "Доход: + множителя за ур.", "Прокачка", 0.01, 1, 0.01 },
	{ "UPGRADES.Income.BaseCost", "Доход: цена 1-го ур.", "Прокачка", 5, 2000, 5 },
	{ "UPGRADES.Income.Growth", "Доход: рост цены ×", "Прокачка", 1.01, 1.5, 0.01 },
	{ "UPGRADE_PRICE_POW", "Апгрейды: степень цены (1+ур)^x", "Прокачка", 0, 4, 0.1 },
	{ "F.fuelBase", "Ракета: топливо на 0 ур., с", "Прокачка", 0.1, 5, 0.1 },
	{ "F.fuelStep", "Ракета: + топлива за ур., с (ракета = 5 ур.)", "Прокачка", 0.05, 2, 0.05 },
	{ "ROCKET_TIER_PRICES.1", "Ракета 2 (Ракета): цена 💎", "Прокачка", 1, 200, 1 },
	{ "ROCKET_TIER_PRICES.2", "Ракета 3 (Турбо): цена 💎", "Прокачка", 1, 200, 1 },
	{ "ROCKET_TIER_PRICES.3", "Ракета 4 (Мега): цена 💎", "Прокачка", 1, 200, 1 },
	{ "ROCKET_TIER_PRICES.4", "Ракета 5 (Бласт): цена 💎", "Прокачка", 1, 300, 1 },
	{ "ROCKET_TIER_PRICES.5", "Ракета 6 (Гиперджет): цена 💎", "Прокачка", 1, 300, 1 },
	{ "ROCKET_TIER_PRICES.6", "Ракета 7 (Плазменный): цена 💎", "Прокачка", 1, 300, 1 },
	{ "ROCKET_THRUST", "Ракета: тяга", "Прокачка", 5, 150, 1 },

	{ "STUDS_PER_COIN", "Studs за 1 монету дистанции", "Экономика", 1, 20, 1 },
	{ "COIN_PICKUP_VALUE", "Монета на трассе = N", "Экономика", 1, 50, 1 },
	{ "F.finishPerLevel", "Финиш: монет × уровень", "Экономика", 0, 1000, 10 },
	{ "F.rewardGrowth", "Рост наград с уровнем", "Экономика", 0, 2, 0.05 },
	{ "GEMS_FINISH", "Гемов за финиш", "Экономика", 0, 50, 1 },
	{ "GEMS_NEW_BEST", "Гемов за рекорд", "Экономика", 0, 20, 1 },
	{ "NEW_BEST_COIN_MULT", "Рекорд: × монет заезда", "Экономика", 1, 2, 0.01 },
	{ "MILESTONES.STEP", "Рубежи: шаг, м (0 — выкл)", "Экономика", 0, 2000, 50 },
	{ "MILESTONES.COINS", "Рубежи: монет за рубеж", "Экономика", 0, 200, 1 },
	{ "MILESTONES.BIG_EVERY", "Рубежи: каждый N-й — большой", "Экономика", 0, 20, 1 },
	{ "MILESTONES.BIG_COINS", "Рубежи: монет за большой", "Экономика", 0, 500, 5 },
	{ "MILESTONES.FINISH_GAP", "Рубежи: не ближе к финишу, м", "Экономика", 0, 300, 10 },
	{ "GEMS_FARM_FINISH", "Гемов за финиш (фарм)", "Экономика", 0, 20, 1 },
	{ "CRYSTAL_COINS", "Кристалл: монет", "Экономика", 0, 500, 5 },
	{ "SMASH_COINS", "Разбил препятствие: монет", "Экономика", 0, 100, 1 },
	{ "TNT_COINS", "TNT: монет за взрыв", "Бонусы", 0, 50, 1 },
	{ "TNT_SLOW", "TNT: скорость после взрыва (доля)", "Бонусы", 0.3, 1, 0.05 },
	{ "SMASH_SLOW", "Разбил препятствие: скорость ×", "Бонусы", 0.5, 1, 0.01 },
	{ "SHIELD_HIT_SLOW", "Щит принял удар: скорость ×", "Бонусы", 0.3, 1, 0.05 },
	{ "TNT_POP", "TNT: подброс вверх", "Бонусы", 0, 80, 2 },
	{ "TRICKS.flip.coins", "Сальто: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.frontflip.coins", "Переднее сальто: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.roll.coins", "Бочка: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.spin.coins", "Разворот 360: монет", "Экономика", 0, 200, 1 },
	{ "TRICKS.grab.coins", "Грэб: монет", "Экономика", 0, 100, 1 },
	{ "TRICK_COMBO_MULT.2", "Комбо трюков: × за 2-й", "Экономика", 1, 5, 0.1 },
	{ "TRICK_COMBO_MULT.3", "Комбо трюков: × за 3-й", "Экономика", 1, 10, 0.1 },
	{ "AIR_COINS_PER_SEC", "Полёт: монет в секунду", "Экономика", 0, 100, 1 },
	{ "PERFECT_ZONE", "Идеальный запуск: зона от доли натяга", "Прокачка", 0.5, 1, 0.01 },
	{ "PERFECT_WINDOW", "Идеальный запуск: окно, с", "Прокачка", 0.05, 1, 0.01 },
	{ "PERFECT_LAUNCH_MULT", "Идеальный запуск: × скорости старта", "Прокачка", 1, 1.5, 0.01 },
	{ "PERFECT_MIN_PULL", "Идеальный запуск: мин. натяг до зоны, с", "Античит", 0, 1, 0.05 },
	{ "PERFECT_LAG", "Идеальный запуск: запас на пинг, с", "Античит", 0, 0.5, 0.05 },

	{ "MAGNET_CHANCE", "Магнит: шанс на кусок", "Бонусы", 0, 1, 0.01 },
	{ "MAGNET_TIME", "Магнит: длительность, с", "Бонусы", 1, 30, 1 },
	{ "MAGNET_RADIUS", "Магнит: радиус", "Бонусы", 5, 100, 1 },
	{ "BOOST_CHANCE", "Ускоритель: шанс в ряду", "Бонусы", 0, 1, 0.01 },
	{ "BOOST_ADD", "Ускоритель: + скорости", "Бонусы", 0, 80, 1 },
	{ "POWERUPS.shield.chance", "Щит: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.x2.chance", "x2 монеты: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.x2.time", "x2 монеты: длительность, с", "Бонусы", 1, 60, 1 },
	{ "POWERUPS.fuel.chance", "Канистра: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.rings.chance", "Кольца: шанс", "Бонусы", 0, 1, 0.01 },
	{ "POWERUPS.rings.coins", "Кольца: монет за кольцо", "Бонусы", 0, 200, 1 },

	{ "TASKS_PER_DAY", "Заданий в день", "Награды", 1, 12, 1 },
	{ "TASK_BUYSLED_LEVEL", "Задание «купи редкость»: с уровня", "Награды", 1, 50, 1 },
	{ "TASK_CHEST_COINS", "Сундук заданий: монет", "Награды", 0, 10000, 50 },
	{ "TASK_CHEST_GEMS", "Сундук заданий: гемов", "Награды", 0, 200, 1 },
	{ "WEEKLY_QUEST.GEMS", "Задание недели: гемов", "Награды", 0, 500, 1 },
	{ "WEEKLY_QUEST.OWNED_GEMS", "Задание недели: гемов вместо следа (уже есть)", "Награды", 0, 500, 1 },
	{ "WEEKLY_QUEST.POOL.1.target", "Задание недели: заездов", "Награды", 1, 1000, 1 },
	{ "WEEKLY_QUEST.POOL.2.target", "Задание недели: метров", "Награды", 1000, 1000000, 1000 },
	{ "WEEKLY_QUEST.POOL.3.target", "Задание недели: секунд в воздухе", "Награды", 10, 3000, 5 },
	{ "WEEKLY_QUEST.POOL.4.target", "Задание недели: препятствий", "Награды", 1, 1000, 1 },
	{ "WEEKLY_QUEST.POOL.5.target", "Задание недели: ускорителей", "Награды", 1, 1000, 1 },
	{ "WEEKLY_QUEST.POOL.6.target", "Задание недели: колец", "Награды", 1, 1000, 1 },
	{ "CHEST_COINS", "Сундук в лобби: монет", "Награды", 0, 10000, 25 },
	{ "CHEST_GEMS", "Сундук в лобби: гемов", "Награды", 0, 100, 1 },
	{ "PLAYTIME_GIFTS.5.min", "Большой подарок: минута", "Награды", 1, 60, 1 },
	{ "PLAYTIME_GIFTS.5.coins", "Большой подарок: монет", "Награды", 0, 10000, 50 },
	{ "PLAYTIME_GIFTS.5.gems", "Большой подарок: гемов", "Награды", 0, 100, 1 },
	{ "SESSION_GOAL_MIN", "Цель сессии, мин", "Награды", 1, 60, 1 },
	{ "STREAK_REWARDS.1.coins", "Стрик: день 1, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.2.coins", "Стрик: день 2, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.3.coins", "Стрик: день 3, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.4.coins", "Стрик: день 4, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.5.coins", "Стрик: день 5, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.6.coins", "Стрик: день 6, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.7.coins", "Стрик: день 7, монет", "Награды", 0, 10000, 25 },
	{ "STREAK_REWARDS.7.gems", "Стрик: день 7, гемов", "Награды", 0, 200, 1 },
	{ "STREAK_CYCLE_MULT", "Стрик: множитель монет со 2-й недели", "Награды", 1, 3, 0.05 },
	{ "STREAK_SAVE_GEMS", "Спасение стрика: гемов (день 1)", "Награды", 0, 200, 1 },
	{ "STREAK_SAVE_STEP", "Спасение стрика: +гемов за день", "Награды", 0, 50, 1 },

	{ "TUTORIAL.IDLE", "Обучение: бездействие до подсказки, с", "Обучение", 1, 30, 1 },
	{ "TUTORIAL.HOLD", "Обучение: подсказка висит, с", "Обучение", 2, 20, 0.5 },
	{ "TUTORIAL.GAP", "Обучение: пауза между подсказками, с", "Обучение", 0, 10, 0.5 },
	{ "HUD_AVATAR_PERIOD", "HUD: аватары на шкале — период, с", "Интерфейс", 0.2, 3, 0.1 },
	{ "HUD_AVATAR_MAX", "HUD: аватаров на шкале не больше", "Интерфейс", 0, 12, 1 },
	{ "ZONE_BANNER_TIME", "HUD: баннер зоны — показ, с", "Интерфейс", 0.5, 5, 0.1 },
	{ "ZONE_BANNER_WORLD", "HUD: баннер мира после выстрела (0/1)", "Интерфейс", 0, 1, 1 },

	{ "OBSTACLE_ROWS", "Рядов препятствий на кусок", "Трасса", 0, 6, 1 },
	{ "OBSTACLE_ROW_CHANCE", "Препятствия: шанс, что ряд занят", "Трасса", 0, 1, 0.05 },
	{ "OBSTACLE_GROW_LEVELS", "Препятствия: +1 полоса каждые N уровней", "Трасса", 1, 20, 1 },
	{ "CARS_MAX", "Трафик: макс. машин на полосу", "Трасса", 1, 6, 1 },
	{ "CARS_EVERY_LEVELS", "Трафик: +1 машина каждые N уровней", "Трасса", 1, 20, 1 },
	{ "ROAD_EVERY_LEVELS", "Трафик: +1 дорога каждые N уровней", "Трасса", 1, 20, 1 },
	{ "IDLE_LAUNCH_TIMEOUT", "Без выстрела у рогатки → в лобби, с (0 — нет)", "Трасса", 0, 600, 10 },
	{ "SAFE_START", "Без препятствий первые, studs", "Трасса", 0, 1000, 10 },
	{ "COIN_LINE_CHANCE", "Шанс линии монет", "Трасса", 0, 1, 0.05 },
	{ "SAFE_LINE_REACTION", "Безопасная линия: реакция, с", "Трасса", 0, 1, 0.05 },
	{ "SAFE_LINE_MARGIN", "Безопасная линия: запас времени ×", "Трасса", 1, 3, 0.05 },
	{ "SAFE_LINE_MAX_SHIFT", "Безопасная линия: макс. сдвиг, полос", "Трасса", 0, 4, 1 },
	{ "OBSTACLE_COMBO_FROM", "Препятствия: лёгкое+тяжёлое в ряду с уровня мира", "Трасса", 1, 6, 1 },
	{ "SNOWMAN_OBSTACLE_SCALE", "Снеговик-препятствие: масштаб", "Трасса", 0.3, 1, 0.05 },
	{ "OBSTACLE_MARK.SEGMENTS", "Маркер тяжёлого: кусков пояса (0 — выкл)", "Трасса", 0, 16, 2 },
	{ "OBSTACLE_MARK.HEIGHT", "Маркер тяжёлого: высота, studs", "Трасса", 0.1, 2, 0.05 },
	{ "OBSTACLE_SHADOW.LIGHT", "Пятно-тень лёгкого: прозрачность", "Трасса", 0, 1, 0.05 },
	{ "OBSTACLE_SHADOW.HEAVY", "Пятно-тень тяжёлого: прозрачность", "Трасса", 0, 1, 0.05 },
	{ "OBSTACLE_SHADOW.PAD", "Пятно-тень: × габарита", "Трасса", 0.5, 3, 0.05 },
	{ "OBSTACLE_READ_TIME", "Читаемость препятствия: за сколько с", "Графика", 0.5, 4, 0.1 },
	{ "FOG_RUN.DENSITY_MAX", "Дымка в заезде: Density не выше", "Графика", 0, 1, 0.01 },
	{ "FOG_RUN.HAZE_MAX", "Дымка в заезде: Haze не выше", "Графика", 0, 3, 0.05 },
	{ "CURVE_CHANCE", "Шанс поворота", "Трасса", 0, 1, 0.05 },
	{ "KICKER_CHANCE", "Шанс обрыва с трамплином", "Трасса", 0, 1, 0.01 },
	{ "GRAVITY_ALONG", "Гравитация вдоль склона", "Трасса", 10, 200, 1 },
	{ "STEER_SPEED", "Руль: боковая скорость", "Трасса", 10, 120, 1 },
	{ "STEER_REF_SPEED", "Руль: растёт со скорости выше", "Трасса", 30, 400, 5 },
	{ "STEER_RESPONSE", "Руль: отзывчивость", "Трасса", 2, 20, 0.5 },
	{ "OBSTACLE_SLOWDOWN", "«Падение» (трюк): скорость ×", "Трасса", 0, 1, 0.05 },
	{ "JUMP_ENABLED", "Прыжок с земли (0 — выкл)", "Трасса", 0, 1, 1 },
	{ "JUMP_SPEED", "Прыжок: скорость вверх", "Трасса", 10, 80, 1 },
	{ "JUMP_COOLDOWN", "Прыжок: пауза, с", "Трасса", 0, 3, 0.1 },
	{ "FLIP_SPEED", "Трюки: скорость вращения, рад/с", "Трасса", 3, 20, 0.5 },
	{ "TRICKS.flip.boost", "Сальто: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.frontflip.boost", "Переднее сальто: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.roll.boost", "Бочка: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.spin.boost", "Разворот: буст ×", "Трасса", 1, 1.5, 0.01 },
	{ "TRICKS.grab.minAir", "Грэб: мин. время в воздухе, с", "Трасса", 0, 2, 0.1 },
	{ "AUTO_TRICKS", "Авто-трюки: 1 вкл / 0 выкл", "Трасса", 0, 1, 1 },
	{ "AUTO_TRICK_PLANS.1.air", "Авто-трюк: грэб/разворот от полёта, с", "Трасса", 0.2, 3, 0.05 },
	{ "AUTO_TRICK_PLANS.2.air", "Авто-трюк: сальто от полёта, с", "Трасса", 0.3, 4, 0.05 },
	{ "AUTO_TRICK_PLANS.3.air", "Авто-трюк: комбо из 2 от полёта, с", "Трасса", 0.5, 5, 0.05 },
	{ "AUTO_TRICK_PLANS.4.air", "Авто-трюк: комбо из 3 от полёта, с", "Трасса", 0.8, 6, 0.05 },
	{ "AUTO_TRICK_RANDOM", "Авто-трюк: доля случайного варианта", "Трасса", 0, 1, 0.05 },
	{ "AUTO_TRICK_MARGIN", "Авто-трюк: запас до касания, с", "Трасса", 0, 0.5, 0.01 },
	{ "AUTO_TRICK_MIN_SPEED", "Авто-трюк: мин. вращение, рад/с", "Трасса", 2, 20, 0.5 },
	{ "AUTO_TRICK_MAX_SPEED", "Авто-трюк: макс. вращение, рад/с", "Трасса", 6, 40, 0.5 },
	{ "AUTO_TRICK_SAFE_AIR", "Авто-трюк: доля полёта для лимита оборотов", "Античит", 0.3, 1, 0.05 },
	{ "BOWL.BANK1_W", "Чаша: 1-й пояс, ширина", "Трасса", 10, 60, 1 },
	{ "BOWL.BANK1_ANGLE", "Чаша: 1-й пояс, угол °", "Трасса", 5, 30, 1 },
	{ "BOWL.BANK2_W", "Чаша: 2-й пояс, ширина", "Трасса", 10, 60, 1 },
	{ "BOWL.BANK2_ANGLE", "Чаша: 2-й пояс, угол °", "Трасса", 15, 60, 1 },
	{ "BOWL.BARRIER_H", "Чаша: барьер за поясами, высота", "Трасса", 10, 80, 5 },
	{ "BOWL.FUNNEL_LEN", "Чаша: воронка перед островками, studs", "Трасса", 20, 200, 10 },
	{ "WALL_HEIGHT", "Невидимый борт: высота", "Трасса", 0, 40, 1 },
	{ "WALL_TILT", "Невидимый борт: наклон наружу, °", "Трасса", 0, 45, 1 },
	{ "WALL_OFFSET", "Невидимый борт: отступ от края дна", "Трасса", 0, 20, 0.5 },
	{ "CAR_HITBOX_H", "Легковушка: верх «шапки» (не перепрыгнуть)", "Трасса", 5, 15, 0.5 },
	{ "RESCUE_DEPTH", "Возврат: ниже дна на, studs", "Трасса", 4, 50, 1 },
	{ "RESCUE_SIDE", "Возврат: вбок дальше края дна на", "Трасса", 10, 80, 1 },
	{ "RESCUE_OUT_TIME", "Возврат: снаружи борта дольше, с", "Трасса", 0.5, 10, 0.5 },
	{ "RESCUE_SPEED_KEEP", "Возврат: скорость ×", "Трасса", 0.1, 1, 0.05 },
	{ "RESCUE_MAX", "Возврат: раз за заезд", "Трасса", 0, 10, 1 },
	{ "FELL_DEPTH", "Конец «улетел»: ниже дна на", "Трасса", 20, 200, 5 },
	{ "LOBBY_PREVIEW_SEGMENTS", "Лобби: кусков витринной трассы", "Трасса", 1, 10, 1 },
	{ "SMOOTH_KINK", "Гладкость: макс. излом на стыке, °", "Трасса", 0.5, 20, 0.5 },
	{ "STEP_UP_MAX", "Гладкость: подсадка на ступеньку, studs", "Трасса", 0, 4, 0.1 },
	{ "SLALOM_CHANCE", "Оформление: флажки-слалом", "Трасса", 0, 1, 0.05 },
	{ "ARCH_CHANCE", "Оформление: арка над трассой", "Трасса", 0, 1, 0.01 },
	{ "TUNNEL_SHARE", "Тоннель: доля пути под сводом (0 — нет; новый заезд)", "Трасса", 0, 0.6, 0.05 },
	{ "TUNNEL_MAX_LEN", "Тоннель: макс. длина одного (studs)", "Трасса", 150, 2000, 50 },
	{ "VALLEY_SHARE", "Долина: доля пути по гребню (0 — нет; новый заезд)", "Трасса", 0, 0.5, 0.05 },
	{ "VALLEY_DEPTH", "Долина: глубина обрыва", "Трасса", 20, 200, 5 },
	{ "VALLEY_ISLES", "Долина: островков на 100 studs", "Трасса", 0, 5, 0.1 },
	{ "FENCE_EVERY", "Заборчик: каждый N-й кусок (0 — только у обрыва)", "Трасса", 0, 10, 1 },
	{ "BRIDGE_GAP_X", "Мост над пропастью: смещение вбок (0 — нет)", "Трасса", 0, 120, 2 },
	{ "TUNNEL_FROM_H", "Тоннель: не раньше (studs от старта)", "Трасса", 0, 2000, 50 },
	{ "TUNNEL_HEIGHT", "Тоннель: высота свода над кромкой", "Трасса", 10, 60, 1 },
	{ "TUNNEL_LIGHT_EVERY", "Тоннель: свет на N кусков", "Графика", 1, 10, 1 },
	{ "TUNNEL_LIGHT_BRIGHT", "Тоннель: яркость света", "Графика", 0, 5, 0.1 },
	{ "MESH_DECOR", "Меши декора: 1 — вкл, 0 — Part", "Графика", 0, 1, 1 },
	{ "MESH_SLEDS", "Меши саней/обвеса/ракет: 1 — вкл, 0 — Part", "Графика", 0, 1, 1 },
	{ "MESH_SLED_FLIP", "Меши саней: развернуть на 180°", "Графика", 0, 1, 1 },
	{ "HEADLIGHT_RANGE", "Фары: дальность света", "Графика", 0, 80, 1 },
	{ "HEADLIGHT_BRIGHTNESS", "Фары: яркость", "Графика", 0, 10, 0.25 },
	{ "HEADLIGHT_ANGLE", "Фары: угол конуса, °", "Графика", 10, 120, 5 },
	{ "DECOR_DRIFT_CHANCE", "Декор: сугробы у бортов (меши)", "Графика", 0, 2, 0.05 },
	{ "DECOR_MID_CHANCE", "Декор: скалы среднего плана (меши)", "Графика", 0, 2, 0.05 },
	{ "DECOR_FAR_CHANCE", "Декор: дальние горы (меши)", "Графика", 0, 2, 0.05 },
	{ "DECOR_WOW_CHANCE", "Декор: «вау»-объект (меши)", "Графика", 0, 1, 0.01 },
	{ "DECOR_ROCKS_CHANCE", "Оформление: скалы и кристаллы мира (#67)", "Графика", 0, 2, 0.05 },
	{ "RELIEF_SHARE.descent", "Рельеф: доля спусков (новый заезд)", "Трасса", 0, 0.6, 0.05 },
	{ "RELIEF_SHARE.climb", "Рельеф: доля подъёмов (новый заезд)", "Трасса", 0, 0.4, 0.01 },
	{ "RELIEF_SHARE.special", "Рельеф: доля особых участков (новый заезд)", "Трасса", 0, 0.4, 0.01 },
	{ "RELIEF_CLIMB_STEP", "Рельеф: + доля подъёмов за уровень мира", "Трасса", 0, 0.05, 0.005 },
	{ "CLIMB_REF_SPEED", "Подъём: скорость входа в спуск для расчёта (studs/с)", "Трасса", 10, 120, 1 },
	{ "CLIMB_MIN_SPEED", "Подъём: запас скорости на гребне (studs/с)", "Трасса", 5, 60, 1 },
	{ "CREST_LIFT", "Гребень: подброс (× скорости)", "Трасса", 0, 1, 0.05 },
	{ "FINAL_RUNOUT", "Выкат перед озером (studs, новый заезд)", "Трасса", 0, 800, 20 },
	{ "STAIR_FROM_LEVEL", "Лестница трамплинов: с уровня", "Трасса", 1, 50, 1 },
	{ "STAIR_CHANCE_BASE", "Лестница: шанс", "Трасса", 0, 0.5, 0.005 },
	{ "STAIR_CHANCE_STEP", "Лестница: + шанс за уровень", "Трасса", 0, 0.05, 0.001 },
	{ "STAIR_CHANCE_MAX", "Лестница: макс. шанс", "Трасса", 0, 0.5, 0.005 },
	{ "STAIR_MIN_SPACING", "Лестница: не чаще, studs", "Трасса", 100, 5000, 50 },
	{ "STAIR_GAP.1", "Лестница: мин. шаг трамплинов, studs", "Трасса", 20, 200, 5 },
	{ "STAIR_SPEED.1", "Лестница: скорость вылета на 1-м уровне", "Трасса", 40, 200, 5 },
	{ "STAIR_SPEED.2", "Лестница: потолок скорости вылета", "Трасса", 40, 200, 5 },
	{ "STAIR_SPEED_STEP", "Лестница: + скорость за уровень", "Трасса", 0, 10, 0.5 },
	{ "STAIR_SPREAD", "Лестница: окно скорости ×", "Трасса", 1, 1.5, 0.01 },
	{ "STAIR_END_MARGIN", "Лестница: запас до след. трамплина", "Трасса", 0, 40, 1 },
	{ "SPIRAL_FROM_LEVEL", "Вираж-спираль: с уровня", "Трасса", 1, 50, 1 },
	{ "SPIRAL_CHANCE_BASE", "Вираж: шанс", "Трасса", 0, 1, 0.01 },
	{ "SPIRAL_CHANCE_MAX", "Вираж: макс. шанс", "Трасса", 0, 1, 0.01 },
	{ "SPIRAL_MIN_SPACING", "Вираж: не чаще, studs", "Трасса", 200, 10000, 100 },
	{ "SPIRAL_ANGLE.1", "Вираж: угол от, °", "Трасса", 60, 180, 5 },
	{ "SPIRAL_ANGLE.2", "Вираж: угол до, °", "Трасса", 60, 180, 5 },
	{ "ICE_TUNNEL_FROM_LEVEL", "Ледяной тоннель с кольцами: с уровня", "Трасса", 1, 50, 1 },
	{ "ICE_TUNNEL_CHANCE", "Ледяной тоннель: шанс перед островками", "Трасса", 0, 1, 0.05 },
	{ "ICE_TUNNEL_RINGS", "Ледяной тоннель: колец-ускорителей", "Трасса", 0, 6, 1 },
	{ "ISLE_FROM_LEVEL", "Островки: с уровня", "Острова", 1, 50, 1 },
	{ "ISLE_AT", "Островки: обязательная цепочка на доле уровня", "Острова", 0.2, 0.9, 0.01 },
	{ "ISLE_CHANCE_BASE", "Островки: шанс доп. цепочки", "Острова", 0, 0.5, 0.005 },
	{ "ISLE_CHANCE_STEP", "Островки: + шанс за уровень", "Острова", 0, 0.05, 0.001 },
	{ "ISLE_CHANCE_MAX", "Островки: макс. шанс", "Острова", 0, 0.5, 0.005 },
	{ "ISLE_COUNT.1", "Островки: в цепочке от", "Острова", 1, 10, 1 },
	{ "ISLE_COUNT.2", "Островки: в цепочке до", "Острова", 1, 10, 1 },
	{ "ISLE_SPEED.1", "Островки: скорость вылета на 1-м уровне", "Острова", 40, 250, 5 },
	{ "ISLE_SPEED.2", "Островки: потолок скорости вылета", "Острова", 40, 250, 5 },
	{ "ISLE_SPEED_STEP", "Островки: + скорость за уровень", "Острова", 0, 20, 0.5 },
	{ "ISLE_SPEED_SPREAD", "Островки: окно скорости ×", "Острова", 1, 2, 0.05 },
	{ "ISLE_LIFT", "Островки: подброс ускорителя", "Острова", 0.1, 1, 0.05 },
	{ "ISLE_LAND_MARGIN", "Островки: запас долёта, studs", "Острова", 2, 60, 1 },
	{ "ISLE_GAP_MIN", "Островки: мин. зазор, studs", "Острова", 4, 100, 1 },
	{ "ISLE_BONUS_CHANCE", "Островки: шанс бонуса", "Острова", 0, 1, 0.05 },
	{ "FORK_FROM_LEVEL", "Развилка-мост: с уровня", "Острова", 1, 50, 1 },
	{ "FORK_CHANCE_BASE", "Развилка-мост: доля цепочек", "Острова", 0, 1, 0.05 },
	{ "FORK_CHANCE_STEP", "Развилка-мост: + доля за уровень", "Острова", 0, 0.1, 0.005 },
	{ "FORK_CHANCE_MAX", "Развилка-мост: макс. доля", "Острова", 0, 1, 0.05 },
	{ "FORK_INTRO", "Развилка-мост: первая цепочка ур. «с» — всегда (0/1)", "Острова", 0, 1, 1 },
	{ "FORK_BOOST_EVERY", "Мост: ускоритель каждые, studs", "Острова", 40, 400, 10 },
	{ "FORK_RISK_COINS", "Развилка: монет над пропастью ×", "Острова", 1, 4, 1 },
	{ "FORK_RISK_GEMS", "Развилка: гемов над пропастью", "Острова", 0, 3, 1 },

	{ "AC_SPEED_MULT", "Предел скорости: × огибающей", "Античит", 1, 3, 0.05 },
	{ "AC_SPEED_ADD", "Предел скорости: + studs/с", "Античит", 0, 200, 5 },
	{ "AC_DECAY", "Спад огибающей: доля сопротивления", "Античит", 0, 1, 0.05 },
	{ "AC_LAG_SEC", "Флаг: отставание пути, с предела", "Античит", 0.5, 10, 0.1 },
	{ "AC_TELEPORT_STUDS", "Телепорт: сдвиг за тик, studs", "Античит", 50, 2000, 10 },
	{ "AC_TELEPORT_MULT", "Телепорт: × предела за тик", "Античит", 1, 10, 0.5 },
	{ "AC_DT_MAX", "Лаг: макс. пауза позиции, с", "Античит", 0.5, 10, 0.5 },
	{ "AC_AIR_HEIGHT", "Полёт: высота над трассой", "Античит", 1, 10, 0.5 },
	{ "AC_AIR_GRACE", "Полёт: запас к серверному, с", "Античит", 0, 2, 0.1 },
	{ "AC_MAX_AIR", "Полёт: флаг дольше, с", "Античит", 2, 30, 0.5 },
	{ "AC_NEAR_RADIUS", "Бонус/препятствие: радиус", "Античит", 10, 200, 5 },
	{ "AC_NEAR_LAG", "Радиус: + скорость × с", "Античит", 0, 1, 0.05 },
	{ "AC_FLAG_LIMIT", "Флагов до отмены заезда", "Античит", 1, 50, 1 },
	{ "AC_FLAG_COOLDOWN", "Флаг по позиции: не чаще, с", "Античит", 0.2, 10, 0.2 },
	{ "WEEKLY.MAX_FLAGS", "Неделя: флагов до исключения", "Лидерборд", 1, 50, 1 },
	{ "WEEKLY.MAX_AVG_SPEED", "Неделя: макс. средняя скорость", "Лидерборд", 100, 2000, 10 },
	{ "WEEKLY.WRITE_EVERY", "Неделя: запись игрока раз в, с", "Лидерборд", 10, 300, 5 },
	{ "WEEKLY.REFRESH", "Неделя: обновление табло, с", "Лидерборд", 30, 600, 10 },
	{ "WEEKLY.PAGE_SEC", "Табло: смена страницы, с", "Лидерборд", 3, 30, 1 },
	{ "GHOST_TRANSPARENCY", "Призрак: прозрачность саней", "Призрак", 0, 0.95, 0.05 },
	{ "GHOST_TAG_DIST", "Призрак: подпись видна до, studs", "Призрак", 0, 1000, 10 },
	{ "GHOST_SAMPLE_DT", "Призрак: запись раз в, с (новые записи)", "Призрак", 0.15, 0.3, 0.01 },
	{ "GHOST_MIN_DIST", "Призрак: не сохранять короче, studs", "Призрак", 0, 500, 10 },

	{ "GRAPHICS.BLOOM", "Bloom: × интенсивности", "Графика", 0, 2, 0.05 },
	{ "GRAPHICS.DOF", "Размытие дали: × силы", "Графика", 0, 3, 0.05 },
	{ "GRAPHICS.SATURATION", "Насыщенность: ×", "Графика", 0, 2, 0.05 },
	{ "GRAPHICS.SUNRAYS", "Солнечные лучи: ×", "Графика", 0, 3, 0.05 },
	{ "GRAPHICS.CONTRAST_MIN", "Контраст: не ниже", "Графика", 0, 0.5, 0.01 },
	{ "GRAPHICS.VIGNETTE_MAX", "Виньетка скорости: макс.", "Графика", 0, 0.9, 0.05 },
	{ "GRAPHICS.VIGNETTE_FROM", "Виньетка: со скорости", "Графика", 0, 300, 5 },
	{ "GRAPHICS.VIGNETTE_FULL", "Виньетка: полная на скорости", "Графика", 10, 400, 5 },
	{ "SOUND_SET", "Звук: набор (0 встроенные, 1 v1, 2 v2; перезайти)", "Звук", 0, 2, 1 },
	{ "MUSIC_VOLUME", "Музыка: громкость", "Звук", 0, 0.3, 0.01 },
	{ "SOUND.groups.SFX", "Эффекты: громкость канала", "Звук", 0, 1, 0.05 },
	{ "SOUND.groups.UI", "Интерфейс: громкость канала", "Звук", 0, 1, 0.05 },
	{ "SOUND.groups.Ambience", "Окружение (ветер, машины)", "Звук", 0, 1, 0.05 },
	{ "SOUND.duck", "Приглушение музыки на событиях", "Звук", 0, 1, 0.05 },
	-- громкость каждого звука (DEV → «Звуки» правит их же)
	{ "SOUND.sfx.click.1", "click: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.open.1", "open: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.deny.1", "deny: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.buy.1", "buy: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.claim.1", "claim: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.chest.1", "chest: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.ready.1", "ready: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.task.1", "task: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.reveal.1", "reveal: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.tierup.1", "tierup: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.coin.1", "coin: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.gem.1", "gem: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.crystal.1", "crystal: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.shield.1", "shield: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.shieldhit.1", "shieldhit: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.x2.1", "x2: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.magnet.1", "magnet: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.fuel.1", "fuel: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.ring.1", "ring: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.boost.1", "boost: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.spring.1", "spring: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.launch.1", "launch: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.jump.1", "jump: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.land.1", "land: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.spin.1", "spin: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.flip.1", "flip: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.wipe.1", "wipe: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.smash.1", "smash: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.crash.1", "crash: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.fall.1", "fall: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.rocket_on.1", "rocket_on: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.rocket_off.1", "rocket_off: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.finish.1", "finish: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.record.1", "record: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.horn.1", "horn: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.wind.1", "wind: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.snow.1", "snow: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.ice.1", "ice: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.hard.1", "hard: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.rocket.1", "rocket: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.stretch.1", "stretch: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.car.1", "car: громкость", "Звук: события", 0, 1, 0.05 },
	{ "SOUND.sfx.train.1", "train: громкость", "Звук: события", 0, 1, 0.05 },
}
Config.TUNABLE_DEFAULTS = {} :: { [string]: number }

-- Значение по пути "A.B.C" (числовой сегмент — индекс массива: "TRICK_COMBO_MULT.2")
local function pathKey(part: string): any
	return tonumber(part) or part
end
function Config.getPath(path: string): any
	local t: any = Config
	for part in string.gmatch(path, "[^%.]+") do
		if type(t) ~= "table" then
			return nil
		end
		t = t[pathKey(part)]
	end
	return t
end
function Config.setPath(path: string, value: any)
	local parts = string.split(path, ".")
	local t: any = Config
	for i = 1, #parts - 1 do
		t = t[pathKey(parts[i])]
		if type(t) ~= "table" then
			return
		end
	end
	t[pathKey(parts[#parts])] = value
end
for _, tn in Config.TUNABLES do
	Config.TUNABLE_DEFAULTS[tn[1]] = Config.getPath(tn[1])
end
-- Применить словарь изменений { путь = число } (неизвестные пути и нечисла пропускаются)
function Config.applyOverrides(overrides: { [string]: any })
	for _, tn in Config.TUNABLES do
		local path = tn[1]
		local v = overrides[path]
		if typeof(v) == "number" then
			Config.setPath(path, math.clamp(v, tn[4], tn[5]))
		else
			Config.setPath(path, Config.TUNABLE_DEFAULTS[path])
		end
	end
end

return Config
