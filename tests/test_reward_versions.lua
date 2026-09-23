-- Reward contracts exercise the real cycle module; only engine boundaries are adapted.
local n,failures=0,{}
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local function check(name,fn)
 local passed,err=pcall(fn)
 if not passed then failures[#failures+1]=name..': '..tostring(err)end
end
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local C=assert(loadfile(TEST_ROOT..'/cycles.lua'))()({},R)
local p=R.demo_profile()
local function area(limit)return{cards={},config={card_limit=limit}}end
local random_calls,roll,added,saves,contexts,money=0,0.25,{},{},{},0
function pseudorandom(seed)
 ok(type(seed)=='string'and seed:find('tyg'),'reward branch uses a native named seed')
 random_calls=random_calls+1;return roll
end
function save_run()
 saves[#saves+1]={run=R.copy(G.GAME.tyg_cycle),state=G.STATE,
  locked=G.CONTROLLER.locked,locks=R.copy(G.CONTROLLER.locks)}
end
function playing_card_joker_effects(cards)contexts[#contexts+1]=cards end
function ease_dollars(amount)money=money+amount end
SMODS={add_card=function(args)
 local card={ability={set=args.set},config={center={key=args.key or'c_native_random',set=args.set}}}
 args.area.cards[#args.area.cards+1]=card;added[#added+1]=args
 return card
end}
local function reset(version,value)
 local run=C.prepare_run(p);run.reward_version=version
 run.natal_given=true;run.current_ante=1;run.seen_antes.ante_1=true
 G={GAME={tyg_cycle=run,round_resets={ante=1}},STATE=1,
  STATES={BLIND_SELECT=1,SHOP=2,SELECTING_HAND=3,PLAY_TAROT=6},SETTINGS={},CONTROLLER={locks={}},
  jokers=area(0),consumeables=area(2),hand=area(8),deck=area(52),play=area(5)}
 random_calls=0;roll=value or 0.25;added={};saves={};contexts={};money=0
 return run
end
check('new run and default preview',function()
 local run=C.prepare_run(p)
 eq(run.reward_version,2,'new snapshot has independent reward version')
 local expected={'灵魂','幻灵','幻灵','2张随机塔罗','2张随机塔罗','2张倍率牌','50%','50%','冥王星'}
 for rank=1,9 do
  local g=C.grid(math.floor((rank-1)/3)+1,(rank-1)%3+1)
  ok(g.reward_text:find(expected[rank],1,true),'new preview text for rank '..rank)
  eq(g.reward_version,2,'preview identifies reward version')
 end
end)
check('unversioned run phase retains v0.6',function()
 local run=reset(nil)
 eq(C.phase(run,1).reward_text,'生成2张随机塔罗牌','saved old phase retains old promise')
 eq(C.phase(run,1).reward_version,1,'missing version means v0.6')
 eq(C.grid(3,3,1).reward_text,'加入1张石头牌','explicit old preview')
 eq(C.grid(3,3,2).reward_text,'生成1张冥王星牌','explicit new preview')
end)
for rank=1,9 do
 check('new matrix rank '..rank,function()
  local run=reset(2);local ticket={ability={tyg_claim_id='test_'..rank,tyg_reward_version=2}}
  ok(C.queue_effect(rank,ticket),'claim succeeds')
  local expected_count=({1,1,1,2,2,2,1,1,1})[rank]
  local expected_kind=({'Spectral','Spectral','Spectral','Tarot','Tarot','Playing','Tarot','Tarot','Planet'})[rank]
  eq(#run.pending_effects,expected_count,'new count')
  for _,e in ipairs(run.pending_effects)do
   eq(e.kind,expected_kind,'new kind')
   if rank==1 then eq(e.key,'c_soul','fixed original Soul')end
   if rank==6 then eq(e.key,'m_mult','whole pair has Mult enhancement')end
   if rank==9 then eq(e.key,'c_pluto','fixed High Card planet')end
  end
  eq(random_calls,(rank>=6 and rank<=8)and 1 or 0,'one branch draw only where needed')
  eq(#saves,0,'claim defers persistence to the stable update boundary')
  local before=random_calls
  ok(not C.queue_effect(rank,ticket),'used card cannot claim twice')
  ok(not C.queue_effect(rank,{ability={tyg_claim_id='test_'..rank,tyg_reward_version=2}}),'copied claim cannot claim twice')
  eq(random_calls,before,'duplicates cannot reroll')
  G.STATE=G.STATES.SELECTING_HAND;C.update()
  eq(#saves,1,'stable update persists the completed claim')
  eq(saves[1].state,G.STATES.SELECTING_HAND,'saved state is resumable')
  ok(saves[1].run.used_claims['test_'..rank],'stable save retains claim deduplication')
  eq(#run.pending_effects,0,'all promised effects delivered')
  eq(#added,expected_count,'no direct Joker or booster added')
  for _,args in ipairs(added)do
   if rank==6 then eq(args.area,G.hand,'enhanced pair enters current battle hand');eq(args.enhancement,'m_mult','native Mult center')
   else eq(args.area,G.consumeables,'actual consumable goes into inventory');eq(args.soulable,false,'random consumables never inject Soul or Black Hole')end
  end
  if rank==6 then eq(#contexts,2,'each permanent playing card triggers growth context')end
  eq(#G.jokers.cards,0,'fortune does not create a legendary Joker directly')
 end)
end
for _,rank in ipairs({6,7,8})do
 check('second half branch rank '..rank,function()
  local run=reset(2,0.5)
  C.queue_effect(rank,{ability={tyg_claim_id='boundary'}})
  eq(random_calls,1,'50 percent boundary still draws once')
  if rank==6 then
   eq(#run.pending_effects,2,'Bonus branch is still one pair')
   eq(run.pending_effects[1].key,'m_bonus','0.5 chooses Bonus')
   eq(run.pending_effects[2].key,'m_bonus','no mixed enhancement pair')
   G.STATE=G.STATES.SHOP;C.update()
   eq(#G.deck.cards,2,'pair is permanent deck addition outside combat')
   eq(#contexts,2,'Bonus cards trigger both addition contexts')
  else
   eq(#run.pending_effects,1,'Planet branch gives exactly one card')
   eq(run.pending_effects[1].kind,'Planet','0.5 chooses random Planet')
   eq(run.pending_effects[1].key,nil,'random Planet is not route recommendation')
  end
 end)
end
check('native consumable animation never saves its transient state',function()
 local run=reset(2,0.75);G.consumeables.config.card_limit=0
 G.STATE=G.STATES.PLAY_TAROT;G.CONTROLLER.locks.use=true
 local ticket={ability={tyg_claim_id='native_animation'}}
 ok(C.queue_effect(7,ticket),'native use locks its reward branch during animation')
 eq(#saves,0,'PLAY_TAROT cannot be persisted by claim')
 eq(G.STATE,G.STATES.PLAY_TAROT,'claim preserves native animation state')
 ok(G.CONTROLLER.locks.use,'claim preserves native use lock')
 eq(random_calls,1,'claim picks its branch once')
 C.update();eq(#saves,0,'animation update cannot save')
 G.STATE=G.STATES.BLIND_SELECT
 C.update();eq(#saves,0,'restored state still waits for native use lock')
 G.CONTROLLER.locks.use=false;G.CONTROLLER.locked=true
 C.update();eq(#saves,0,'controller lock still prevents persistence')
 G.CONTROLLER.locked=false;G.GAME.STOP_USE=1
 C.update();eq(#saves,0,'native stop-use boundary still prevents persistence')
 G.GAME.STOP_USE=0;C.update()
 eq(#saves,1,'stable full inventory still persists pending reward')
 eq(#added,0,'full slots do not need a delivery to trigger persistence')
 eq(saves[1].state,G.STATES.BLIND_SELECT,'saved state is the restored stable state')
 eq(saves[1].locked,false,'saved controller is unlocked')
 eq(saves[1].locks.use,false,'saved native use lock is released')
 eq(#saves[1].run.pending_effects,1,'stable snapshot keeps the full promise')
 eq(saves[1].run.pending_effects[1].kind,'Planet','stable snapshot keeps selected branch')
 ok(saves[1].run.used_claims.native_animation,'stable snapshot keeps consumed claim')
 ok(not C.queue_effect(7,ticket),'used ticket remains blocked after stable persistence')
 C.update();C.update()
 eq(#saves,1,'unchanged full inventory does not keep saving')
 eq(random_calls,1,'animation and stable updates never reroll')
end)
check('full inventory and resume keep selected branch',function()
 local run=reset(2,0.75);G.consumeables.config.card_limit=0
 local ticket={ability={tyg_claim_id='persisted'}};C.queue_effect(7,ticket)
 local selected=R.copy(run.pending_effects[1])
 C.update();C.update();eq(#run.pending_effects,1,'full slots retain promise')
 eq(#saves,1,'full slots save the locked claim once at stable update')
 local snapshot=R.copy(saves[1].run)
 eq(random_calls,1,'full inventory updates cannot reroll')
 G.GAME.tyg_cycle=snapshot;roll=0
 ok(not C.queue_effect(7,{ability={tyg_claim_id='persisted'}}),'reload keeps claim consumed')
 G.consumeables.config.card_limit=2;C.update();C.update()
 eq(#added,1,'reload delivers once')
 eq(added[1].set,selected.kind,'reload keeps chosen Planet branch')
 eq(added[1].key,selected.key,'reload keeps saved key')
 eq(random_calls,1,'delivery never invokes reward branch RNG')
end)
check('tickets carry version and inherit legacy version',function()
 local run=reset(2);run.seen_antes={};G.consumeables.config.card_limit=0
 C.update();eq(run.pending_items[1].reward_version,2,'queued new ticket carries reward version')
 G.GAME.tyg_cycle=R.copy(run);G.consumeables.config.card_limit=2;C.update()
 eq(G.consumeables.cards[1].ability.tyg_reward_version,2,'delivered ticket carries reward version')
 local legacy=reset(nil)
 legacy.pending_items={{key='c_tyg_fortune_1',claim_id='old_pending'}}
 C.update();eq(G.consumeables.cards[1].ability.tyg_reward_version,1,'old queued ticket inherits old run')
 C.queue_effect(1,G.consumeables.cards[1]);eq(#legacy.pending_effects,2,'legacy ticket still pays two Tarot')
 eq(legacy.pending_effects[1].kind,'Tarot','legacy ticket keeps matrix')
end)
check('ticket version overrides run in both directions',function()
 local run=reset(2);C.queue_effect(6,{ability={tyg_reward_version=1}})
 eq(run.pending_effects[1].kind,'Money','old ticket in new run still gives cash')
 eq(run.pending_effects[1].amount,3,'old amount retained');eq(random_calls,0,'old ticket has no new branch')
 run=reset(nil);C.queue_effect(1,{ability={tyg_reward_version=2}})
 eq(#run.pending_effects,1,'new ticket in legacy run gives one card')
 eq(run.pending_effects[1].key,'c_soul','ticket explicit version wins')
end)
check('legacy concrete queued effects drain without reinterpretation',function()
 local run=reset(2)
 run.pending_effects={{kind='Money',amount=3,id=1},{kind='Playing',key='m_stone',id=2},
  {kind='Tarot',key='c_emperor',id=3},{kind='Planet',key='c_jupiter',id=4}}
 run.next_effect_id=4;C.update()
 eq(money,3,'old pending cash unchanged')
 eq(added[1].enhancement,'m_stone','old pending stone unchanged')
 eq(added[2].key,'c_emperor','old concrete Tarot key unchanged')
 eq(added[3].key,'c_jupiter','old recommended planet unchanged')
 eq(#run.pending_effects,0,'old FIFO drains');eq(random_calls,0,'old concrete effects never reroll')
end)
check('partial Tarot delivery preserves FIFO before next ticket',function()
 local run=reset(2);G.consumeables.config.card_limit=1
 C.queue_effect(4,{ability={tyg_claim_id='two_tarot'}})
 run.pending_items={{key='c_tyg_fortune_9',claim_id='later',reward_version=2}}
 C.update();eq(#run.pending_effects,1,'second Tarot survives one-slot capacity')
 eq(#run.pending_items,1,'next ticket waits behind effects')
 G.consumeables.cards={};C.update();eq(added[2].set,'Tarot','second Tarot delivered before ticket')
 eq(#run.pending_items,1,'ticket still waits for its own slot')
 G.consumeables.cards={};C.update();eq(added[3].key,'c_tyg_fortune_9','ticket follows completed effect FIFO')
end)
if #failures>0 then error(table.concat(failures,'\n'))end
print('PASS '..n..' versioned reward/branch/persistence assertions')
