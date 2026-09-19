# Soaring World Red — 0.5.1

`START → SOAR WORLD` opens the current data-driven stylized experiment. It is a
separate miniature world, made from `world/kanto_height.png`,
`world/kanto_terrain.png`, `world/kanto_objects.lua`, and `world/config.lua`.
Press `R` while flying to reload those files. See `STYLIZED-WORLD-GUIDE.md` in
the tools package for editing instructions. This mode is limited to the Pallet
→ Route 1 → Viridian proof slice and does not change a save or run overworld
logic.

The world scene uses 2× internal supersampling (320×288) with one smooth
reduction to gen1recomp's 160×144 playfield. Material-specific distance LOD
removes fine forest and mountain motifs before they shimmer. For weak mobile
hardware, set `render_scale=1` and `texture_scale=1` in `world/art.lua`.
Gameplay uses a perspective chase camera behind the flying placeholder. Press
`C` or Select to cycle `CHASE`, `HIGH_SOAR`, and the inspection-only
`DEBUG_TOP`; Start exits. Flight heading, camera position and camera rotation
are smoothed independently. A small pixel-art sky/horizon/sea continuation
fills the area beyond the vertical slice.

Flight controls are heading-relative: left/right turn the craft and camera,
up/down fly forward/reverse, and A/B climb/descend. Reverse speed defaults to
65% of forward speed. `flight_turn_speed` and `flight_reverse_scale` can be
tuned in `world/config.lua`; older user configs receive safe defaults.

The earlier original-map elevation experiment is retained internally as a
connection-data reference, but it is no longer shown in the normal Start menu.

Ступенчатый рельеф для Pallet Town → Route 1 → Viridian City. Работает на gen1recomp API 2, проверен на 0.2.52, только Pokémon Red.

Папку soaring_world_red поместите в mods отдельной тестовой игры. В менеджере включите Soaring World Red - Experimental для Red и перезапустите игру. Вход: START → SOAR WORLD. Стрелки/WASD — движение; Z/X — высота; Escape/Tab — возврат в исходную обычную игру. Экспериментальные моды могут быть выключены по умолчанию.

Высоты находятся в heightmaps/*.heightmap. Их можно редактировать отдельным Heightmap Editor из пакета инструментов или как текст. После сохранения выйдите из сцены и войдите снова. Оригинальные Pokémon map data не меняются. Нет heightmap — карта плоская. Некорректный файл даёт предупреждение в журнал и плоскую карту.

SOAR_HEIGHTMAP 1 — версия формата; map — ID карты; cell 32 — размер клетки; size — ширина и высота сетки. Далее числовые строки с уровнями -1..3. Ступень = 16 мировых пикселей. Подробное руководство содержится в HEIGHTMAP-GUIDE.md пакета инструментов.

Фиксированная 2.5D-проекция, верхние поверхности из настоящих тайлов, боковые стенки. Полёт не вызывает NPC, encounters или warp-скрипты. Без посадки, HM Fly, visited tracking и 3D-моделей зданий. Совместимость с другими overhaul-модами не проверялась. В пакет не входят ROM, атласы и исходные игровые карты. Независим от Dramatic Shape / Flying Overhaul.
