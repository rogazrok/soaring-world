# Soaring World

**Version 1.0.0 · Pokémon Red · gen1recomp**

Explore Kanto from Dragonite's back. Fly over familiar towns, discover places
that cannot be reached by road, and return to the ground whenever you find a
landing spot.

## Features

- A 3D view of Kanto with two flight cameras: CHASE and HIGH SOAR.
- Dragonite arrival, takeoff and landing animations, with Surf music in flight.
- Landing in towns you have already visited.
- Five repeatable Hidden Areas with their own encounters and item rewards.
- Discovery progress and per-visit rewards that persist through saving and loading.
- A panoramic horizon, moving clouds, animated water and atmosphere effects.
- Day and night lighting that follows the game's current time of day.

## Installation

1. Close the game and back up your save before updating an existing installation.
2. Extract the runtime ZIP into the game's `mods` directory. The resulting layout
   should be `mods/soaring_world_red/manifest.json`.
3. When updating, replace the previous `soaring_world_red` folder completely.
4. Start Pokémon Red in gen1recomp and enable the mod in the game's mod settings.

On Windows, the usual mod directory is
`%APPDATA%/pokemon-love2d/mods`. On other platforms, use the mod directory provided
by your game installation.

The runtime ZIP is everything needed to play. The DevKit is an optional download
for people who want to edit the world. Neither download includes the game engine
or Pokémon Red game data.

## Getting the Dragon Call

After you become Champion, return to Pallet Town. Lance will meet you and give
you the **DRAGON CALL**. Use it from the Bag while outdoors to summon Dragonite
and enter Soaring.

An existing save with the Champion victory flag can trigger this meeting; you
do not need to defeat the League again solely to unlock it. Leave room in your
Bag for the item.

## Flight controls

Controls use your normal in-game button bindings, including touch controls.

| Button | Action |
| --- | --- |
| Up / Down | Fly forward / backward |
| Left / Right | Turn |
| A / B | Ascend / descend |
| A at an `A: LAND` prompt | Open the landing confirmation |
| A / B in a confirmation | Confirm / go back |
| Select | Switch between CHASE and HIGH SOAR |
| Start | Open the Soaring Map |
| B or Start on the map | Return to flight |

Opening the map pauses your flight. If a landing
prompt appears, confirm the destination before descending into it.

## Exploring hidden places

Unknown Hidden Areas initially display `???`. Land successfully to discover
their names. Their encounters and rewards vary by area and visit. When you are
finished exploring, use the Dragon Call to return to the sky.

Town landings are available after you have visited those towns in the normal
game. Some secrets have additional discovery requirements; keep exploring.

## Compatibility and troubleshooting

This mod is for **Pokémon Red**, not Blue, Yellow or other generations. Its
manifest accepts gen1recomp versions from 0.2.52 up to, but not including, 0.4.0.
The final gameplay regression suite was run on 0.3.57, with manual play checks
reported on PC and phone.

Vanilla Fly remains available. Modern Field Moves was also included in the
regression checks. Other mods that replace the overworld, map data or rendering
may need separate compatibility testing.

If you see an error, make sure there is only one installed copy of the mod and
that the previous folder was fully replaced. When reporting a problem, include
your game version, platform, other enabled mods and the steps that caused it.
Attach a screenshot of the error if possible.

## Version history

For earlier milestones and the changes included in this release, see
[Version history](VERSION_HISTORY.md).

See [LICENSE](LICENSE) for licensing information.
