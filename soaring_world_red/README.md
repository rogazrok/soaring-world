# Soaring World Red — 0.3.3

`START → SOAR WORLD` opens the current data-driven stylized experiment. It is a
separate miniature world, made from `world/kanto_height.png`,
`world/kanto_terrain.png`, `world/kanto_objects.lua`, and `world/config.lua`.
Press `R` while flying to reload those files. See `STYLIZED-WORLD-GUIDE.md` in
the tools package for editing instructions. This mode is limited to the Pallet
→ Route 1 → Viridian proof slice and does not change a save or run overworld
logic.

`START → SOAR TEST` below is the preserved earlier original-map elevation
experiment. It remains useful as a connection-data reference, but is no longer
the visual direction of SOAR WORLD.

Ступенчатый рельеф для Pallet Town → Route 1 → Viridian City. Работает на gen1recomp API 2, проверен на 0.2.52, только Pokémon Red.

Папку soaring_world_red поместите в mods отдельной тестовой игры. В менеджере включите Soaring World Red - Experimental для Red и перезапустите игру. Вход: START → SOAR WORLD. Стрелки/WASD — движение; Z/X — высота; Escape/Tab — возврат в исходную обычную игру. Экспериментальные моды могут быть выключены по умолчанию.

Высоты находятся в heightmaps/*.heightmap. Их можно редактировать отдельным Heightmap Editor из пакета инструментов или как текст. После сохранения выйдите из сцены и войдите снова. Оригинальные Pokémon map data не меняются. Нет heightmap — карта плоская. Некорректный файл даёт предупреждение в журнал и плоскую карту.

SOAR_HEIGHTMAP 1 — версия формата; map — ID карты; cell 32 — размер клетки; size — ширина и высота сетки. Далее числовые строки с уровнями -1..3. Ступень = 16 мировых пикселей. Подробное руководство содержится в HEIGHTMAP-GUIDE.md пакета инструментов.

Фиксированная 2.5D-проекция, верхние поверхности из настоящих тайлов, боковые стенки. Полёт не вызывает NPC, encounters или warp-скрипты. Без посадки, HM Fly, visited tracking и 3D-моделей зданий. Совместимость с другими overhaul-модами не проверялась. В пакет не входят ROM, атласы и исходные игровые карты. Независим от Dramatic Shape / Flying Overhaul.
