-- Approved Soaring palette B. The former experimental alternatives are retired.
local M={order={'B'}}
local target={
  {{.82,.88,1},{.39,.48,.91},{.22,.29,.66},{.08,.16,.32}},
  {{.70,.91,.50},{.34,.68,.16},{.14,.39,.10},{.06,.20,.08}},
  {{.83,.97,.71},{.50,.80,.27},{.25,.56,.15},{.12,.31,.12}},
  {{.88,.96,.78},{.63,.81,.41},{.37,.58,.25},{.18,.32,.15}},
  {{.97,.96,.82},{.83,.82,.64},{.60,.58,.40},{.31,.30,.22}},
  {{.87,.81,.61},{.70,.59,.35},{.48,.38,.24},{.23,.23,.16}},
  {{.82,.88,1},{.39,.48,.91},{.22,.29,.66},{.08,.16,.32}},
}
function M.apply(w,id)
  assert(id==nil or id=='B','Only approved Soaring palette B is available')
  if not w.originalSoaringRamps then
    w.originalSoaringRamps={}
    for i,row in ipairs(w.art.ramps) do
      w.originalSoaringRamps[i]={}
      for j,rgb in ipairs(row) do w.originalSoaringRamps[i][j]={rgb[1],rgb[2],rgb[3]} end
    end
  end
  local ramps={}
  for i,row in ipairs(w.originalSoaringRamps) do
    ramps[i]={}
    for j,rgb in ipairs(row) do
      local color=target[i] and target[i][j]
      ramps[i][j]=color and {color[1],color[2],color[3]} or {rgb[1],rgb[2],rgb[3]}
    end
  end
  w.art.ramps=ramps;w.soaringPalette='B'
end
return M
