-- Reusable straight span and 90-degree elbow. Local +Y is the straight length;
-- the elbow connects local south to east and rotates with the whole prop.
-- The origin is
-- centered between the pier feet. XY use map cells, Z uses world height units.
local M={}
function M.build(face,x,y,z,d,sc,s,rotation)
  local angle=math.rad(rotation or 0);local co,si=math.cos(angle),math.sin(angle)
  local a,b,h=d.w*s,d.d*s,d.h
  local function p(dx,dy,dz)
    return {x*s+sc*(dx*co-dy*si),y*s+sc*(dx*si+dy*co),z+sc*dz}
  end
  local function panel(points,col,shade)
    local cx,cy=0,0;for _,v in ipairs(points) do cx=cx+v[1];cy=cy+v[2] end
    cx,cy=cx/#points,cy/#points
    local f=face(points,col,cy+.5*cx,cx,cy);f.shade=shade or 1
    return f
  end
  local function block(cx,cy,bottom,w,l,height,col,shade,localAngle)
    local bc,bs=math.cos(localAngle or 0),math.sin(localAngle or 0)
    local function bp(xx,yy,zz) return p(cx+xx*bc-yy*bs,cy+xx*bs+yy*bc,zz) end
    local lo={bp(-w/2,-l/2,bottom),bp(w/2,-l/2,bottom),bp(w/2,l/2,bottom),bp(-w/2,l/2,bottom)}
    local hi={bp(-w/2,-l/2,bottom+height),bp(w/2,-l/2,bottom+height),bp(w/2,l/2,bottom+height),bp(-w/2,l/2,bottom+height)}
    for i=1,4 do local j=i%4+1;panel({hi[i],hi[j],lo[j],lo[i]},col,shade or .82) end
    panel(hi,col,1);panel({lo[4],lo[3],lo[2],lo[1]},col,.68)
  end
  local thickness=1.8;local surface=h+thickness
  if d.turn==90 then
    -- Radius = half a straight span. Ports share its width and deck elevation.
    -- Centerline ports are (-R/2,+R/2) and (+R/2,-R/2).
    local radius=b/2;local cx,cy=radius/2,radius/2
    local start,finish=math.pi,math.pi*1.5;local steps=12
    local function arc(r,t,zz) return p(cx+r*math.cos(t),cy+r*math.sin(t),zz) end
    local function strip(inner,outer,zz,height,col,shade)
      for i=0,steps-1 do
        local t0=start+(finish-start)*i/steps;local t1=start+(finish-start)*(i+1)/steps
        local lo={arc(inner,t0,zz),arc(outer,t0,zz),arc(outer,t1,zz),arc(inner,t1,zz)}
        local hi={arc(inner,t0,zz+height),arc(outer,t0,zz+height),arc(outer,t1,zz+height),arc(inner,t1,zz+height)}
        panel(hi,col,1);panel({lo[4],lo[3],lo[2],lo[1]},col,.68)
        panel({hi[1],hi[4],lo[4],lo[1]},col,shade)
        panel({hi[2],lo[2],lo[3],hi[3]},col,shade)
        if i==0 then panel({hi[1],lo[1],lo[2],hi[2]},col,shade) end
        if i==steps-1 then panel({hi[4],hi[3],lo[3],lo[4]},col,shade) end
      end
    end
    strip(radius-a/2,radius+a/2,h,thickness,5,.85)
    for _,sign in ipairs({-1,1}) do
      local r=radius+sign*a*.31
      strip(r-a*.05,r+a*.05,h-2.3,2.3,6,.82)
    end
    -- Same four concrete piers, footings and caps as the straight piece.
    for _,fraction in ipairs({.22,.78}) do
      local t=start+(finish-start)*fraction;local ct,st=math.cos(t),math.sin(t)
      for _,sign in ipairs({-1,1}) do
        local r=radius+sign*a*.31;local xx,yy=cx+r*ct,cy+r*st
        block(xx,yy,0,a*.24,b*.15,1.5,6,.85,t)
        block(xx,yy,1.5,a*.16,b*.105,h-4.2,5,.77,t)
        block(xx,yy,h-3.0,a*.24,b*.15,1.1,6,.88,t)
      end
      block(cx+radius*ct,cy+radius*st,h-1.9,a*.88,b*.14,1.9,6,.90,t)
    end
    for _,sign in ipairs({-1,1}) do
      local r=radius+sign*a*.47
      strip(r-a*.0275,r+a*.0275,surface,.65,6,.87)
      for i=0,8 do
        local t=start+(finish-start)*i/8
        block(cx+r*math.cos(t),cy+r*math.sin(t),surface+.65,a*.045,b*.025,2.1,6,.86,t)
      end
      strip(r-a*.02,r+a*.02,surface+1.25,.35,5,.88)
      strip(r-a*.0225,r+a*.0225,surface+2.45,.4,5,.90)
    end
    local function marking(inner,outer,t0,t1,zz)
      panel({arc(inner,t0,zz),arc(outer,t0,zz),arc(outer,t1,zz),arc(inner,t1,zz)},4,.94)
    end
    for _,sign in ipairs({-1,1}) do
      local r=radius+sign*a*.36
      for i=0,steps-1 do
        marking(r-a*.012,r+a*.012,start+(finish-start)*i/steps,start+(finish-start)*(i+1)/steps,surface+.02)
      end
    end
    for _,f in ipairs({.1,.3,.5,.7,.9}) do
      marking(radius-a*.014,radius+a*.014,start+(finish-start)*(f-.04),start+(finish-start)*(f+.04),surface+.025)
    end
    return
  end
  -- Continuous pale pavement, thick deck fascia, two longitudinal girders.
  block(0,0,h,a,b,thickness,5,.85)
  for _,sign in ipairs({-1,1}) do block(sign*a*.31,0,h-2.3,a*.10,b,2.3,6,.82) end
  -- Two portal piers with broad feet, square concrete columns and cap beams.
  for _,yy in ipairs({-b*.29,b*.29}) do
    for _,sign in ipairs({-1,1}) do
      local xx=sign*a*.31
      block(xx,yy,0,a*.24,b*.15,1.5,6,.85)
      block(xx,yy,1.5,a*.16,b*.105,h-4.2,5,.77)
      block(xx,yy,h-3.0,a*.24,b*.15,1.1,6,.88)
    end
    block(0,yy,h-1.9,a*.88,b*.14,1.9,6,.90)
  end
  -- Low curbs and open double guardrails leave water visible below the span.
  for _,sign in ipairs({-1,1}) do
    local xx=sign*a*.47
    block(xx,0,surface,a*.055,b,.65,6,.87)
    for _,yy in ipairs({-b*.44,-b*.22,0,b*.22,b*.44}) do
      block(xx,yy,surface+.65,a*.045,b*.025,2.1,6,.86)
    end
    block(xx,0,surface+1.25,a*.04,b,.35,5,.88)
    block(xx,0,surface+2.45,a*.045,b,.4,5,.90)
  end
  -- Narrow lane borders and five center dashes. No per-quad texture resets.
  for _,xx in ipairs({-a*.36,a*.36}) do
    panel({p(xx-a*.012,-b/2,surface+.02),p(xx+a*.012,-b/2,surface+.02),p(xx+a*.012,b/2,surface+.02),p(xx-a*.012,b/2,surface+.02)},4,.94)
  end
  for _,yy in ipairs({-b*.4,-b*.2,0,b*.2,b*.4}) do
    panel({p(-a*.014,yy-b*.045,surface+.025),p(a*.014,yy-b*.045,surface+.025),p(a*.014,yy+b*.045,surface+.025),p(-a*.014,yy+b*.045,surface+.025)},4,.94)
  end
end
return M
