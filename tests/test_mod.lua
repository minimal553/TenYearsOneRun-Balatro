-- Pure rules and native-callback contract checks, not an in-game UI test.
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function eq(a,b,msg)check(a==b,(msg or '')..': '..tostring(a)..' ~= '..tostring(b))end
local rules_loader=loadfile(TEST_ROOT..'/rules.lua')
check(type(rules_loader)=='function','nine-grid rules module must exist')
local R=rules_loader()
local expected={{0.72,0.90,1.08},{0.80,1.00,1.20},{0.88,1.10,1.32}}
local rarity={{3,3,2},{3,2,1},{2,1,1}}
for a=1,3 do for b=1,3 do
 local p=R.grid(a,b)
 check(math.abs(p.target_multiplier-expected[a][b])<1e-9,'grid target')
 eq(p.rarity,rarity[a][b],'strict grid rarity');eq(p.planet_count,p.rarity-1,'planet queue count')
end end
check(not pcall(R.grid,0,1),'invalid tier rejected')
local sample=R.demo_profile()
local p,err=R.validate_profile(sample);check(p~=nil,err)
local run=R.prepare_run(p,1)
eq(run.gift_state,'unclaimed','gift initially unclaimed')
eq(run.planets_pending,R.grid(run.natal_tier,run.luck_tier).planet_count,'saved queued planets')
sample.decades[1].luck_tier=2
check(run.luck_tier~=sample.decades[1].luck_tier,'run snapshots source values')
sample=R.demo_profile();sample.decades[1].luck_tier=9
check(not R.validate_profile(sample),'bad imported tier rejected')
sample=R.demo_profile();sample.schema_version=99
check(not R.validate_profile(sample),'bad schema rejected')
sample=R.demo_profile();sample.route.planet_key='c_soul'
check(not R.validate_profile(sample),'arbitrary reward key rejected')
sample=R.demo_profile();sample.decades[1].grid={target_multiplier=0.00001,rarity=4}
local safe=R.prepare_run(assert(R.validate_profile(sample)),1)
eq(safe.target_multiplier,0.72,'do not trust arbitrary imported multiplier')
eq(safe.rarity,3,'do not trust arbitrary imported rarity')
local centers={c={key='c',set='Joker',rarity=1},a={key='a',set='Joker',rarity=3},b={key='b',set='Joker',rarity=3},d={key='d',set='Joker',rarity='Rare'},h={key='h',set='Joker',rarity=3,hidden=true}}
local pool=R.filter_pool({'UNAVAILABLE','c','a','b','a','d','h','missing'},centers,3)
eq(#pool,3,'filter rejects wrong rarity, duplicates and hidden')
local chosen=R.pick_unique(pool,3,function(size)return 1 end)
eq(#chosen,3,'3 distinct candidates');check(chosen[1]~=chosen[2] and chosen[1]~=chosen[3],'no duplicate')
eq(#R.filter_pool({'c'},centers,3),0,'vanilla common fallback cannot leak into rare pack')
eq(#R.pick_unique({'a'},3,function()return 1 end),1,'short pool remains same rarity')

local registry={}
local events={}
local adds,opened,returned_to_deck=0,0,0
G={GAME={},SETTINGS={paused=false},UIT={R=1,C=2,T=3,O=4},P_CENTERS=centers,FUNCS={},STATES={SHOP=1,BLIND_SELECT=2,PLAY_TAROT=3,SELECTING_HAND=4,SMODS_BOOSTER_OPENED=5},
 STATE=2,STAGES={RUN=2},STAGE=2,C={MULT={},MONEY={},BLUE={},GREEN={},RED={},WHITE={},BLACK={},UI={TEXT_LIGHT={}}},
 jokers={cards={},config={card_limit=5}},consumeables={cards={},config={card_limit=2}},
 play={T={x=0,y=0,w=1,h=1}},hand={},CARD_W=1,CARD_H=1,P_CARDS={empty={}},
 CONTROLLER={locks={},interrupt={}},E_MANAGER={add_event=function(self,e)events[#events+1]=e end}}
G.FUNCS.draw_from_hand_to_deck=function()returned_to_deck=returned_to_deck+1;return 'native' end
SMODS={current_mod={path=TEST_ROOT..'/',config={}}}
local inputs={}
local instance={effect={config={}}}
function create_text_input(args)inputs[args.id]=args;return{input=args}end
function create_option_cycle(args)return args end
function create_UIBox_generic_options(args)return args end
function UIBox_button(args)return args end
function DynaText(args)return args end
G.FUNCS.overlay_menu=function(args)G.OVERLAY_MENU={definition=args.definition}end
G.FUNCS.exit_overlay_menu=function()G.OVERLAY_MENU=nil;G.SETTINGS.paused=false end
G.FUNCS.start_run=function(e,args)
 eq(args.deck_choice.name,'b_tyg_mingju','birthday confirmed for own deck')
 registry.b_tyg_mingju.apply(registry.b_tyg_mingju,instance)
end
function SMODS.load_file(name)return loadfile(TEST_ROOT..'/'..name)end
function SMODS.Consumable(v)registry['c_tyg_'..v.key]=v end
function SMODS.Back(v)registry['b_tyg_'..v.key]=v end
function SMODS.Joker(v)registry['j_tyg_'..v.key]=v end
function SMODS.ConsumableType(v)end
function SMODS.Atlas(v)end
SMODS.Booster=setmetatable({update_pack=function()end,create_UIBox=function()return{}end},{__call=function(self,v)registry['p_tyg_'..v.key]=v end})
function SMODS.add_card(args)adds=adds+1;local c={config={center={key=args.key,set=args.set}}};args.area.cards[#args.area.cards+1]=c;return c end
function SMODS.save_mod_config()end
function sendInfoMessage()end
function sendWarnMessage()end
function Event(e)return e end
function pseudoseed(s)return s end
function pseudorandom_element(p,s)return p[1]end
function get_current_pool(set,rarity_arg)
 eq(set,'Joker','eligible native joker pool')
 eq(rarity_arg,'Rare','native rarity must be named string, not numeric3')
 return {'c','a','b','d','UNAVAILABLE'}
end
local saves={}
function save_run()
 -- Match the native guard: an opened booster cannot be saved as a stable run.
 if G.STATE==G.STATES.SMODS_BOOSTER_OPENED then return end
 saves[#saves+1]={state=G.STATE,run=R.copy(G.GAME.tyg_run)}
end
Game={update=function(self,dt)end}
function Card(x,y,w,h,front,center,args)
 return {config={center=center},ability={set='Booster',extra=3,choose=1},cost=4,start_materialize=function()end,remove=function()end}
end
local expected_idle=G.STATES.BLIND_SELECT
G.FUNCS.use_card=function(e)
 opened=opened+1;eq(G.STATE,expected_idle,'open after native restoration')
 local saved=saves[#saves]
 check(saved and saved.run and saved.run.gift_state=='pending','recoverable pending must be saved before opening')
 eq(#saved.run.gift_keys,3,'frozen candidates must be in saved snapshot')
 eq(#G.consumeables.cards,1,'ticket remains recoverable at save point')
 G.GAME.PACK_INTERRUPT=G.STATE;G.STATE=G.STATES.SMODS_BOOSTER_OPENED;SMODS.OPENED_BOOSTER=e.config.ref_table
end
assert(loadfile(TEST_ROOT..'/main.lua'))()
-- Steamodded injects registered centres before a new run can start.
for key,center in pairs(registry)do center.key=key;G.P_CENTERS[key]=center end
local back=assert(registry.b_tyg_mingju,'new independent back registered')
eq(back.atlas,'deck','new back must reference our own artwork')
eq(back.pos.y,0,'custom back atlas origin')
local ticket=assert(registry.c_tyg_gift,'gift ticket registered')
for _,key in ipairs({'common','uncommon','rare'})do
 check(registry['p_tyg_gift_'..key]~=nil,'rarity booster exists')
 eq(registry['p_tyg_gift_'..key].pos.y,0,'legacy booster uses our new atlas origin')
end
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
check(not G.GAME.tyg_run,'wizard must not apply deck before confirmation')
check(SMODS.current_mod.tyg_presets,'main exposes preset factory')
G.FUNCS.tyg_choose_birth()
inputs.tyg_birth_date.ref_table.date='20051223'
inputs.tyg_birth_time.ref_table.time='730'
G.FUNCS.tyg_birth_gender({to_key=2})
G.FUNCS.tyg_birth_match()
check(SMODS.current_mod.tyg_birth.current_profile(),'real Lua calendar matches from native input')
G.FUNCS.tyg_birth_start()
eq(instance.effect.config.ante_scaling,1,'new multiplier owned by cycle hook, no double scaling')
eq(G.GAME.win_ante,8,'eight actual decades')
eq(#instance.effect.config.consumables,0,'new runs never spawn legacy Emperor-looking coupon')
eq(G.GAME.tyg_cycle.natal_key,'j_tyg_mp_shishen','actual birthday selects monthly 食神 pattern, not old nearest5')
check(not G.GAME.tyg_run,'new run does not activate legacy gift lifecycle')
G.GAME.tyg_cycle=nil
G.GAME.tyg_run=R.prepare_run(R.demo_profile(),1)
local this_run=G.GAME.tyg_run
local token={config={center={key='c_tyg_gift'}},ability={set='Tarot'},area=G.consumeables,
 remove_from_deck=function()end,start_dissolve=function(self)self.removed=true end}
function G.consumeables:remove_card(c) for i=#self.cards,1,-1 do if self.cards[i]==c then table.remove(self.cards,i)end end end
G.consumeables.cards={token}
check(ticket.can_use(ticket,token),'usable at blind selection with slot')
G.STATE=G.STATES.SELECTING_HAND
check(ticket.can_use(ticket,token),'opening gift stays usable after entering first blind')
G.STATE=G.STATES.BLIND_SELECT
G.STATE=G.STATES.PLAY_TAROT;G.CONTROLLER.locks.use=true
ticket.use(ticket,token,G.consumeables)
eq(opened,0,'never open nested inside consumable use')
eq(this_run.gift_state,'pending','claim persisted pending')
Game:update(0.016);eq(opened,0,'waits for native use state restoration')
G.STATE=G.STATES.BLIND_SELECT;G.CONTROLLER.locks.use=false
Game:update(0.016)
eq(opened,1,'opens via native booster lifecycle')
eq(this_run.gift_state,'opened','one-shot state');check(token.removed,'remove ticket only after opening')
Game:update(0.016);eq(opened,1,'does not reopen while pack is up');eq(adds,0,'no planets inside active pack')
check(not ticket.can_use(ticket,token),'cloned ticket cannot duplicate gift')
G.STATE=G.STATES.BLIND_SELECT;SMODS.OPENED_BOOSTER=nil;G.booster_pack=nil
Game:update(0.016)
eq(this_run.gift_state,'complete','selection or skip completes gift')
eq(adds,2,'drain planets after closing within capacity');eq(#G.consumeables.cards,2,'no slot overflow')
Game:update(0.016);eq(adds,2,'no duplicate planets')
local b=registry.p_tyg_gift_rare
local opened_card={ability={extra=3,choose=1,tyg_candidates={'a','b','d'}},config={center=b}}
for i=1,3 do local def=b.create_card(b,opened_card,i);eq(def.key,opened_card.ability.tyg_candidates[i],'exact chosen key')end
this_run.planets_pending=1;Game:update(0.016);eq(adds,2,'full inventory keeps pending reward')
G.consumeables.cards={};Game:update(0.016);eq(adds,3,'pending reward delivered after freeing slot')
this_run.gift_state='unclaimed'
local original_pool=get_current_pool
get_current_pool=function()return {'c'}end
check(not ticket.can_use(ticket,token),'empty rarity pool disables claiming')
local empty_reason=ticket.loc_vars(ticket,{},token).vars[3]
check(type(empty_reason)=='string'and empty_reason:find('没有',1,true),'empty pool reason must be visible in tooltip')
get_current_pool=original_pool
-- Restore the exact pre-pack saved run. It must reuse candidates, not consume RNG.
G.GAME={tyg_run=R.copy(saves[1].run)}
G.consumeables.cards={token};token.removed=false
local old_random=pseudorandom_element
pseudorandom_element=function()error('reload must not reroll the frozen pack')end
Game:update(0.016)
eq(opened,2,'saved pending resumes exactly one pack')
eq(G.GAME.tyg_run.gift_keys[1],saves[1].run.gift_keys[1],'same candidate after reload')
pseudorandom_element=old_random
G.GAME={};Game:update(0.016);eq(opened,2,'other decks unaffected')
-- In-hand gift closes without returning the live hand to the deck.
G.GAME={tyg_run=R.copy(saves[1].run)}
G.STATE=G.STATES.SELECTING_HAND;SMODS.OPENED_BOOSTER=nil
G.consumeables.cards={token};token.removed=false
expected_idle=G.STATES.SELECTING_HAND
Game:update(0.016)
eq(opened,3,'pending gift opens during normal hand selection')
check(SMODS.OPENED_BOOSTER.ability.tyg_preserve_hand,'only in-hand gift records hand preservation')
G.FUNCS.draw_from_hand_to_deck()
eq(returned_to_deck,0,'own in-hand gift closure must not empty the hand')
SMODS.OPENED_BOOSTER.config.center={key='p_buffoon_normal_1'}
eq(G.FUNCS.draw_from_hand_to_deck(),'native','unrelated booster delegates original hand cleanup')
eq(returned_to_deck,1,'normal booster still cleans up its drawn hand')
SMODS.OPENED_BOOSTER=nil;G.GAME.PACK_INTERRUPT=nil;G.STATE=G.STATES.SELECTING_HAND
Game:update(0.016)
eq(G.GAME.tyg_run.gift_state,'complete','in-hand return finishes gift')
print('PASS '..n..' nine-grid Lua assertions (rules and callback contracts)')
print('LIMIT: no native game UI or full ten-ante run was operated.')
