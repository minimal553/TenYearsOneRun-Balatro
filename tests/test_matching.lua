local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
assert(type(R.match_calendar)=='function','pure Lua natal/luck matching must exist')
local raw={chart={'乙酉','戊子','辛巳','壬辰'},calendar={gender=0},decades={
 {index=1,gan_zhi='己丑',start_date='2010-06-18T02:37:00+08:00',end_date='2020-06-18T02:37:00+08:00'},
 {index=2,gan_zhi='庚寅',start_date='2020-06-18T02:37:00+08:00',end_date='2030-06-18T02:37:00+08:00'},
 {index=3,gan_zhi='辛卯',start_date='2030-06-18T02:37:00+08:00',end_date='2040-06-18T02:37:00+08:00'}}}
local p,err=R.match_calendar(raw);assert(p,err)
assert(p.natal_tier==1 and p.score==85,'exact natal threshold')
assert(p.route.key=='liansheng'and p.route.planet_key=='c_saturn','native route matches Python')
local expected={3,3,7,1,2};for i,n in ipairs(expected)do assert(p.weights[i]==n,'relationship weights')end
assert(p.decades[1].luck_tier==3 and p.decades[2].luck_tier==1 and p.decades[3].luck_tier==1,'three decade tiers')
assert(math.abs(p.decades[1].affinity+0.5375)<1e-9,'first luck score')
assert(p.decades[2].grid.target_multiplier==0.72 and p.decades[2].grid.rarity==3,'target and gift matched')
assert(raw.natal_tier==nil and raw.decades[1].luck_tier==nil,'source is not mutated')
assert(R.validate_profile(p),'matched profile passes production validation')
assert(not R.match_calendar({chart={'甲丑','甲子','甲子','甲子'},decades={}}),'invalid chart rejected')
assert(not R.match_calendar({chart={'甲子','甲子','甲子','甲子'},decades={{gan_zhi='bad'}}}),'invalid decade rejected')
print('PASS native Lua matching parity and validation assertions')
