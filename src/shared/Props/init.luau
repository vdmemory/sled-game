-- Модели для трассы и лобби в стилизованном low-poly духе: препятствия и декор всех миров.
-- Всё собирается из примитивов Roblox (без загрузки ассетов), поэтому работает с автодеплоем.
-- Фасад: модули категорий (папка Props/) дописывают функции в общую таблицу Props — снаружи API
-- прежний (Props.part, Props.deco, Props.car, Props.obstacle, …).
--   Base — part/deco, цвета, pick, надписи, колёса; Vehicles — транспорт и трафик;
--   Obstacles — препятствия и Props.obstacle; Decor — деревья, постройки, горы, трамплин;
--   Worlds — модели миров 4–7; LobbyDecor — костёр, флагшток, гирлянда.

local Props = require(script.Base).Props
require(script.Vehicles)
require(script.Obstacles)
require(script.Decor)
require(script.Worlds)
require(script.LobbyDecor)

return Props
