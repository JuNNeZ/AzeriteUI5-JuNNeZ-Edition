-- Real shared placement: preserve the measured dip at every supported scale,
-- orientation and nudge, without reading any secret health/resource values.
-- lua Tools/Harness/aligned_endcap_harness.lua <addon root>
local ns = {}
local root = arg[1] or "."
assert(loadfile(root.."/Core/ThemeEngine.lua"))("AzeriteUI5_JuNNeZ_Edition",ns)
local checks = 0
local function check(v,label) checks=checks+1;assert(v,label) end
local back = { GetWidth=function() return 716 end, GetHeight=function() return 188 end }
local art = {}
function art:ClearAllPoints() self.points={} end
function art:SetSize(w,h) self.width,self.height=w,h end
function art:SetPoint(...) self.points={...} end
function art:SetTexCoord(...) self.coords={...} end
local pivots={{750/1024,187/256},{758.5/1024,181/256},{869/1024,188/256},
 {760.5/1024,187/256},{767.5/1024,181/256},{879.5/1024,188/256},
 {753.5/1024,187/256},{761/1024,181/256},{872.5/1024,188/256},
 {757.5/1024,187/256},{757.5/1024,190/256},{876/1024,185/256}}
for _,pivot in ipairs(pivots) do
 for _,flip in ipairs({false,true}) do
  for _,scale in ipairs({.5,1,1.3,1.5,2}) do
   for _,offset in ipairs({{0,0},{5,-3},{-60,60}}) do
    local dx,dy=unpack(offset)
    check(ns.ThemeEngine:PlaceAlignedHealthEndcap(art,back,pivot,flip,scale/1.3,dx,dy),"valid placement")
    local x=flip and 1-pivot[1] or pivot[1]
    local actualX=art.points[4]+x*art.width
    local actualY=-art.points[5]+pivot[2]*art.height
    check(math.abs(actualX-(716*x+(flip and -dx or dx)))<1e-8,"dip X fixed under scale, outward nudge mirrors")
    check(math.abs(actualY-(188*pivot[2]-dy))<1e-8,"dip Y fixed under scale and nudge")
    check(art.points[2]==back and art.coords[1]==(flip and 1 or 0),"same backdrop and mirror")
   end
  end
 end
end
check(not ns.ThemeEngine:PlaceAlignedHealthEndcap(nil,back,pivots[1],false,1,0,0),"missing art ignored")
check(not ns.ThemeEngine:PlaceAlignedHealthEndcap(art,nil,pivots[1],false,1,0,0),"missing backdrop ignored")
check(not ns.ThemeEngine:PlaceAlignedHealthEndcap(art,back,nil,false,1,0,0),"unknown casing ignored")
print("Aligned endcap placement: "..checks.." checks passed (offline only)")
