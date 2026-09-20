-- Fixed challenges share the real cycle/reward path without calendar matching.
local count=0
local function ok(v,m)count=count+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local loader=loadfile(TEST_ROOT..'/presets.lua')
ok(type(loader)=='function','nine-grid preset factory must exist')
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local M=assert(loadfile(TEST_ROOT..'/chart_patterns.lua'))()
local C=assert(loadfile(TEST_ROOT..'/cycles.lua'))()({},R,M)
M.classify=function()error('presets must not classify invented pillars')end
R.match_calendar=function()error('presets must not match a calendar')end
local P=loader()(R,M,C)
eq(#P.catalog,9,'nine preset entries')
local ids={}
local function area(limit)return{cards={},config={card_limit=limit}}end
function save_run()end
SMODS={add_card=function(a)
 local card={ability={},config={center={key=a.key}}};a.area.cards[#a.area.cards+1]=card;return card
end}
for natal=1,3 do for luck=1,3 do
 local rank=(natal-1)*3+luck;local entry=P.catalog[rank]
 eq(entry.rank,rank,'catalog is ordered natal-major');eq(entry.natal_tier,natal,'catalog natal');eq(entry.luck_tier,luck,'catalog luck')
 ok(not ids[entry.id],'preset ids are unique');ids[entry.id]=true
 local p=assert(P.make(rank));ok(R.validate_profile(p),'profile passes existing validation')
 eq(p.mode,'preset','explicit source mode');eq(p.preset_id,entry.id,'stable catalog identity')
 eq(p.natal_tier,natal,'selected natal');eq(p.pattern.key,'changgui','same honest starter')
 eq(p.pattern.combo,nil,'no invented composite');eq(p.route.planet_key,'c_pluto','same recommended planet')
 eq(p.route.hand_type,'High Card','same recommended hand');eq(p.selected_decade,1,'starts at first phase')
 eq(p.birth,nil,'no invented birth');eq(p.birth_date,nil,'no invented birth date');eq(#p.decades,8,'eight fixed phases')
 for _,pillar in ipairs(p.chart)do ok(not pillar:match('^......$'),'display tokens cannot look like two-character pillars')end
 for i,d in ipairs(p.decades)do
  eq(d.index,i,'ordered phases');eq(d.luck_tier,luck,'luck stays fixed for eight phases')
  ok(not d.start_date:match('%d%d%d%d%-%d%d%-%d%d'),'no invented start date')
  ok(not d.end_date:match('%d%d%d%d%-%d%d%-%d%d'),'no invented end date')
 end
 local run=C.prepare_run(p)
 eq(run.mode,'preset','snapshot preserves source');eq(run.preset_id,entry.id,'snapshot preserves selection')
 eq(run.natal_key,'j_tyg_mp_changgui','actual registered starter center')
 eq(run.pattern.combo,nil,'snapshot has no composite')
 G={GAME={tyg_cycle=run,round_resets={ante=1}},STATE=1,STATES={BLIND_SELECT=1,SHOP=2,SELECTING_HAND=3},
  SETTINGS={},CONTROLLER={locks={}},play={cards={}},jokers=area(5),consumeables=area(20)}
 for ante=1,10 do
  G.GAME.round_resets.ante=ante;C.update()
  local phase=C.phase(run,ante);local expected=C.grid(natal,luck)
  eq(phase.rank,rank,'rank stays fixed including endless');eq(phase.target_multiplier,1+(rank-1)/8,'correct target')
  eq(phase.reward_name,expected.reward_name,'same cycle reward name');eq(phase.reward_text,expected.reward_text,'same cycle reward text')
  eq(G.consumeables.cards[ante].config.center.key,'c_tyg_fortune_'..rank,'real fortune key each ante')
 end
 eq(#G.jokers.cards,1,'one starter only');eq(G.jokers.cards[1].config.center.key,'j_tyg_mp_changgui','spawned regular starter')
 eq(G.jokers.cards[1].ability.tyg_combo,nil,'spawned starter has no composite')
 local saved=R.copy(run);G.GAME.tyg_cycle=saved;C.update()
 eq(#G.jokers.cards,1,'resume does not duplicate starter');eq(#G.consumeables.cards,10,'resume does not duplicate ticket')
 eq(saved.mode,'preset','saved mode retained');eq(saved.preset_id,entry.id,'saved selection retained')
 p.decades[1].luck_tier=99;p.pattern.key='changed';p.route.planet_key='changed'
 local fresh=P.make(rank)
 eq(fresh.decades[1].luck_tier,luck,'factory deep copies phases');eq(fresh.pattern.key,'changgui','factory deep copies pattern')
 eq(fresh.route.planet_key,'c_pluto','factory deep copies route');eq(run.decades[1].luck_tier,luck,'run independent of profile')
end end
for _,bad in ipairs({0,10,1.5,'1',false})do ok(not P.make(bad),'invalid preset rank rejected')end
ok(not P.make(nil),'missing rank rejected')
local before=P.make(1);P.catalog[1].natal_tier=3;P.catalog[1].id='tampered'
eq(P.make(1).natal_tier,before.natal_tier,'catalog display mutation cannot alter challenge')
eq(P.make(1).preset_id,before.preset_id,'catalog display mutation cannot alter stable id')
local legacy=C.prepare_run(R.demo_profile());legacy.mode=nil;legacy.preset_id=nil
G.GAME.tyg_cycle=legacy;G.GAME.round_resets.ante=1;G.consumeables=area(20);G.jokers=area(5)
C.update();eq(legacy.mode,nil,'legacy save not reinterpreted');eq(legacy.preset_id,nil,'legacy save not relabeled')
eq(legacy.natal_key,'j_tyg_shishang','legacy starter unchanged')
print('PASS '..count..' fixed preset/catalog/snapshot/start assertions')
