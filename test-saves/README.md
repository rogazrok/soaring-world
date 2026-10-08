# Optional Blue USA / Yellow USA test saves

These are standard 32,768-byte international English Generation I battery
saves targeting the ordinary USA Pokémon Blue and Pokémon Yellow releases.
They are test fixtures created for this mod, not recordings of full playthroughs.
No ROM or cartridge image is included. These games are Game Boy titles.

## Import

1. Enable Soaring World Red 1.0.1 in gen1recomp 0.3.63 or newer.
2. Select Blue or Yellow and import your own matching game data.
3. Import the matching `.sav` into a new test slot and choose CONTINUE.
4. If the engine shows its normal added-mod LOAD REPORT, press A to continue.
   Lance then approaches in Pallet Town. Advance the dialogue with A.

Do not overwrite your main slot. The files are not loaded automatically.

## Starting state

- Trainer SWRTEST, ID 42420; Pallet Town, Champion flag, eight badges,
  one native Hall of Fame entry, 50,000 money and room in the Bag.
- Dragon Call has not been received. Hidden Areas and Mew are unused.
- Six healthy Pokémon, levels 60–62, with supplies and all five HMs.
- Blue: Charizard, Blastoise, Venusaur, Raichu, Snorlax, Pidgeot.
- Yellow: Pikachu, Blastoise, Venusaur, Charizard, Snorlax, Pidgeot.
- Pidgeot knows Fly, Blastoise knows Surf; Fly towns are visited.
- Story flags outside the test prerequisites do not represent a full completed
  playthrough. Use these files for mod testing, not as a canonical completion save.

## Validation limits

Both files passed native export, import, CONTINUE and the Lance reward scene
in isolated Windows gen1recomp 0.3.63. Main data, both PC banks and all twelve
box checksums were independently verified (15 checksums per file).
Both used the matching actual imported game data. Yellow's follower appears
after import. Loading these files in an original-game emulator and through the
phone import interface remains manual.
