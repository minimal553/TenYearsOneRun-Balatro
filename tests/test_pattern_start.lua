local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local M=assert(loadfile(TEST_ROOT..'/chart_patterns.lua'))()
local C=assert(loadfile(TEST_ROOT..'/cycles.lua'))()({},R,M)
local Calendar=assert(loadfile(TEST_ROOT..'/calendar.lua'))()(assert(loadfile(TEST_ROOT..'/calendar_data.lua'))())
local match=assert(loadfile(TEST_ROOT..'/pattern_matcher.lua'))()(R,M)
local live_profile=assert(match(assert(Calendar.calculate{date='2005-04-12',time='00:30',gender=1})))
local live_run=C.prepare_run(live_profile)
for i,d in ipairs(live_profile.decades)do
 local actual=C.phase(live_run,i)
 eq(d.grid.target_multiplier,actual.target_multiplier,'profile preview grid agrees with actual gameplay')
 eq(d.grid.rank,actual.rank,'profile reward rank agrees with actual gameplay')
 eq(d.grid.fortune_key,'c_tyg_fortune_'..actual.rank,'profile references fortune, never Joker pack')
 eq(d.grid.rarity,nil,'new profile does not expose stale legacy pack rarity')
end
for _,row in ipairs(M.catalog)do
 local p=R.demo_profile();p.route={key=row.key,name=row.name,planet_key=row.planet_key}
 p.pattern={version=M.version,key=row.key,name=row.name,status='明确匹配',reasons={'test reason'},combo={key='guanyin',name='官印相生'}}
 local run=C.prepare_run(p)
 eq(run.natal_key,row.joker_key,'every valid category starts corresponding actual center')
 eq(run.version,2,'new snapshot version');eq(run.pattern.key,row.key,'pattern snapshot persists')
 eq(run.pattern.combo.key,'guanyin','one composite in snapshot')
 p.pattern.combo.key='changed';eq(run.pattern.combo.key,'guanyin','snapshot independent of profile')
end
local p=R.demo_profile();p.route.key='zhengguan';p.pattern={key='zhengguan',name='正官格',combo={key='guanyin',name='官印相生'}}
local run=C.prepare_run(p)
G={GAME={tyg_cycle=run,round_resets={ante=1}},STATE=1,STATES={BLIND_SELECT=1,SHOP=2,SELECTING_HAND=3},
 SETTINGS={},CONTROLLER={locks={}},play={cards={}},jokers={cards={},config={card_limit=5}},consumeables={cards={},config={card_limit=2}}}
SMODS={add_card=function(a)local c={ability={},config={center={key=a.key}}};a.area.cards[#a.area.cards+1]=c;return c end}
function save_run()end
C.update()
eq(#G.jokers.cards,1,'one and only one new starter')
eq(G.jokers.cards[1].ability.tyg_combo.key,'guanyin','actual spawned card receives its composite')
eq(G.jokers.cards[1].ability.tyg_pattern_key,'zhengguan','actual card stores pattern identity')
G.GAME.tyg_cycle=R.copy(run);C.update();eq(#G.jokers.cards,1,'resume keeps same starter without reclassification or duplicates')
local legacy=C.prepare_run(R.demo_profile());eq(legacy.natal_key,'j_tyg_shishang','legacy profile helper preserved')
p.pattern.key='invented';ok(not pcall(C.prepare_run,p),'unregistered pattern cannot silently produce wrong Joker')
print('PASS '..n..' pattern to starter/save assertions')
