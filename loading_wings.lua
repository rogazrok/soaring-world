-- Compose the supplied wing poses over frame26's FIXED background/body.
-- Only changed sprite pixels in the wing region participate; never cloud pixels.
-- No source art is modified. Packed RGB keeps the small CPU compositor portable.
local M={width=256,height=144}
local function rgb(r,g,b) return r*65536+g*256+b end
local sprite={}
for _,c in ipairs({{41,42,41},{217,154,92},{241,215,160},{165,110,66},{190,64,53},{119,81,60}}) do
  sprite[rgb(c[1],c[2],c[3])]=true
end
function M.compose(pixel)
  local base,frames,mask={},{[23]={},[25]={}},{}
  local function index(x,y) return y*M.width+x+1 end
  for y=0,M.height-1 do for x=0,M.width-1 do
    local i=index(x,y);base[i]=pixel(26,x,y)
    frames[23][i]=base[i];frames[25][i]=base[i]
  end end
  for y=40,89 do for x=108,194 do
    local i=index(x,y);local c=base[i]
    local down,up=pixel(23,x,y),pixel(25,x,y)
    if (c~=down and (sprite[c] or sprite[down])) or (c~=up and (sprite[c] or sprite[up])) then
      mask[i]=true
      local background=c
      if sprite[c] then
        -- Reveal a fixed nearby frame26 background where a horizontal wing was.
        for distance=1,M.width do
          local left,right=x-distance,x+distance
          if left>=0 and not sprite[base[index(left,y)]] then background=base[index(left,y)];break end
          if right<M.width and not sprite[base[index(right,y)]] then background=base[index(right,y)];break end
        end
      end
      frames[23][i]=sprite[down] and down or background
      frames[25][i]=sprite[up] and up or background
    end
  end end
  return frames,mask,base
end
return M
