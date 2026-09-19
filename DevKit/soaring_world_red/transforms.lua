-- The mod ships no Red art. This sanctioned recipe copies the player's own
-- imported OVERWORLD atlas into this mod's derived cache, so Assets.resolve
-- supplies the local derived image to the Soaring renderer at runtime.
-- No image bytes are present in the repository or distribution.
return function(ctx)
  local atlas = "tilesets/overworld.png"
  if ctx.exists(atlas) then
    ctx.writeImage(ctx.readImage(atlas), atlas)
  end
end
