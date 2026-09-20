local R={version='nine-grid-0.2',tier_names={'上','中','下'},rarity_names={'普通','罕见','稀有'}}
local rarities={{3,3,2},{3,2,1},{2,1,1}}
local factors={{72,90,108},{80,100,120},{88,110,132}}
local planets={c_mercury=true,c_jupiter=true,c_saturn=true,c_venus=true,c_pluto=true}
local function integer(v,min,max)return type(v)=='number' and v==math.floor(v) and v>=min and v<=max end
local function short(s,max)return type(s)=='string' and #s>0 and #s<=(max or 100)end
function R.copy(t)
 if type(t)~='table'then return t end
 local out={};for k,v in pairs(t)do out[k]=R.copy(v)end;return out
end
function R.grid(natal,luck)
 assert(integer(natal,1,3)and integer(luck,1,3),'Invalid game tier')
 local rarity=rarities[natal][luck]
 return{target_multiplier=factors[natal][luck]/100,rarity=rarity,planet_count=rarity-1}
end
function R.demo_profile()
 return{schema_version=1,rules_version=R.version,mode='demo',export_id='builtin-demo-0.2',chart={'乙酉','戊子','辛巳','壬辰'},natal_tier=1,
 route={key='liansheng',name='连生',hand_type='Straight',planet_key='c_saturn'},selected_decade=1,
 decades={{index=1,gan_zhi='示例顺境',start_date='2026-01-01',end_date='2036-01-01',luck_tier=1}}}
end
function R.validate_profile(p)
 if type(p)~='table' or p.schema_version~=1 or p.rules_version~=R.version then return nil,'配置版本不支持，请重新导出' end
 if p.export_id~=nil and not short(p.export_id,100)then return nil,'配置标识无效'end
 if type(p.chart)~='table'or #p.chart~=4 or not integer(p.natal_tier,1,3)then return nil,'八字或本命档无效'end
 for _,s in ipairs(p.chart)do if not short(s,18)then return nil,'四柱内容无效'end end
 if type(p.route)~='table'or not short(p.route.name,40)or not planets[p.route.planet_key]then return nil,'推荐牌型无效'end
 if type(p.decades)~='table'or #p.decades<1 or #p.decades>12 then return nil,'大运表无效'end
 for i,d in ipairs(p.decades)do
  if type(d)~='table'or d.index~=i or not integer(d.luck_tier,1,3)or not short(d.gan_zhi,30)
    or not short(d.start_date,40)or not short(d.end_date,40)then return nil,'大运条目无效'end
 end
 if not integer(p.selected_decade,1,#p.decades)then return nil,'选择的大运不存在'end
 return R.copy(p)
end
function R.prepare_run(p,selection)
 local index=integer(selection,1,#p.decades)and selection or p.selected_decade
 local d=p.decades[index];local grid=R.grid(p.natal_tier,d.luck_tier)
 return{rules_version=R.version,chart=table.concat(p.chart,' '),demo=p.mode=='demo',
  natal_tier=p.natal_tier,luck_tier=d.luck_tier,decade=index,gan_zhi=d.gan_zhi,start_date=d.start_date,end_date=d.end_date,
  route=R.copy(p.route),target_multiplier=grid.target_multiplier,rarity=grid.rarity,
  gift_state='unclaimed',planets_pending=grid.planet_count,gift_keys=nil,last_error=nil}
end
function R.filter_pool(pool,centers,tier)
 local out,seen={},{}
 local aliases={Common=1,Uncommon=2,Rare=3,Legendary=4}
 for _,key in ipairs(pool or {})do
  local c=centers[key]
  if c and c.set=='Joker'and(aliases[c.rarity]or c.rarity)==tier and not c.hidden and not seen[key]then
   seen[key]=true;out[#out+1]=key
  end
 end
 return out
end
function R.pick_unique(pool,count,choose_index)
 local remaining=R.copy(pool);local out={}
 for i=1,math.min(count,#remaining)do
  local idx=choose_index(#remaining,i)
  assert(integer(idx,1,#remaining),'Invalid random index')
  out[#out+1]=table.remove(remaining,idx)
 end
 return out
end
-- The exact integer game-grading model used by the v0.2 Python prototype.
local stems={'甲','乙','丙','丁','戊','己','庚','辛','壬','癸'}
local branches={'子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'}
local elements={'木','火','土','金','水'}
local stem_index,branch_index={},{}
for i,k in ipairs(stems)do stem_index[k]=i-1 end
for i,k in ipairs(branches)do branch_index[k]=i-1 end
local branch_elements={4,2,0,0,2,1,1,2,3,3,2,4}
local targets={{40,15,25,10,10},{25,40,10,10,15},{25,15,40,15,5},{25,10,20,35,10},{25,25,10,10,30}}
local preferences={{1,0,1,-1,-1},{1,1,-1,-1,0},{0,-1,1,1,-1},{1,-1,0,1,-1},{0,1,-1,-1,1}}
local routes={
 {key='jushi',name='聚势',hand_type='Pair',planet_key='c_mercury'},
 {key='huchi',name='护持',hand_type='Flush',planet_key='c_jupiter'},
 {key='liansheng',name='连生',hand_type='Straight',planet_key='c_saturn'},
 {key='xucai',name='蓄财',hand_type='Three of a Kind',planet_key='c_venus'},
 {key='zhiheng',name='制衡',hand_type='High Card',planet_key='c_pluto'}}
local function parts(pillar)
 -- Every valid Gan/Zhi character in this fixed alphabet has three UTF-8 bytes.
 if type(pillar)~='string'or #pillar~=6 then return nil end
 local s,b=stem_index[pillar:sub(1,3)],branch_index[pillar:sub(4,6)]
 if s==nil or b==nil or s%2~=b%2 then return nil end
 return math.floor(s/2),branch_elements[b+1]
end
local function relation(day,element)return({1,3,4,5,2})[(element-day)%5+1]end
function R.match_calendar(raw)
 if type(raw)~='table'or type(raw.chart)~='table'or #raw.chart~=4 or type(raw.decades)~='table'or #raw.decades<1 or #raw.decades>12 then return nil,'排盘数据不完整'end
 local day=parts(raw.chart[3]);if day==nil then return nil,'日柱无效'end
 local weights={0,0,0,0,0}
 local branch_weights={2,6,2,2}
 for i,pillar in ipairs(raw.chart)do
  local g,z=parts(pillar);if g==nil then return nil,'四柱干支无效'end
  local gr,zr=relation(day,g),relation(day,z)
  weights[gr]=weights[gr]+1;weights[zr]=weights[zr]+branch_weights[i]
 end
 local best,f32=1,-math.huge
 for i,t in ipairs(targets)do
  local score=3200;for j=1,5 do score=score-math.abs(100*weights[j]-16*t[j])end
  if score>f32 then best=i;f32=score end
 end
 local p=R.copy(raw)
 p.schema_version=1;p.rules_version=R.version;p.mode='ingame';p.selected_decade=1
 p.natal_tier=f32>=2720 and 1 or(f32>=2080 and 2 or 3)
 p.day_element=elements[day+1];p.weights=weights;p.score=f32/32;p.route=R.copy(routes[best])
 local affinity={}
 for i=1,5 do affinity[i]=math.max(-400,math.min(400,200*preferences[best][i]+4*targets[best][i]-25*weights[i]))end
 for _,d in ipairs(p.decades)do
  if type(d)~='table'then return nil,'大运数据无效'end
  local g,z=parts(d.gan_zhi);if g==nil then return nil,'大运干支无效'end
  local numerator=affinity[relation(day,g)]+2*affinity[relation(day,z)]
  d.luck_tier=numerator>=400 and 1 or(numerator<=-400 and 3 or 2)
  d.affinity=numerator/1200;d.grid=R.grid(p.natal_tier,d.luck_tier)
 end
 return R.validate_profile(p)
end
return R
