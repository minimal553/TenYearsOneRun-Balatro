local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local loader=loadfile(TEST_ROOT..'/cycles.lua')
ok(type(loader)=='function','new cycles module exists')
local C=loader()({},R)
for natal=1,3 do for luck=1,3 do
 local g=C.grid(natal,luck);local rank=(natal-1)*3+luck
 eq(g.rank,rank,'nine distinct ranks');eq(g.target_multiplier,1+(rank-1)/8,'clear 1x to 2x targets')
end end
eq(C.grid(1,1).target_multiplier*600,600,'best baseline600')
eq(C.grid(3,3).target_multiplier*600,1200,'worst baseline1200')
local p=R.demo_profile();p.decades={}
for i=1,8 do p.decades[i]={index=i,gan_zhi='甲子',start_date='2000-01-01',end_date='2010-01-01',luck_tier=(i-1)%3+1}end
local s=C.prepare_run(p)
eq(s.natal_key,'j_tyg_shishang','birth archetype determines unique starter')
eq(s.pattern_name,'食伤生财','recognizable pattern name')
eq(#s.decades,8,'eight actual decades');eq(C.phase(s,2).rank,2,'advance fortune with ante')
eq(C.phase(s,10).decade,8,'endless explicitly retains last known decade')
ok(not s.natal_given,'starter starts pending');eq(#s.pending_items,0,'no hidden old gift')
for route,key in pairs({jushi='bijie',huchi='guanyin',liansheng='shishang',xucai='caixing',zhiheng='shayin'})do
 p.route.key=route;eq(C.prepare_run(p).natal_key,'j_tyg_'..key,'five distinct natal starters')
end
local added={};local money=0;local saves=0;local contexts={}
local function area(limit)return{cards={},config={card_limit=limit}}end
G={GAME={tyg_cycle=s,round_resets={ante=1}},STATE=1,
 STATES={BLIND_SELECT=1,SHOP=2,SELECTING_HAND=3,PLAY_TAROT=4},SETTINGS={},
 CONTROLLER={locks={}},jokers=area(5),consumeables=area(2),hand=area(8),deck=area(52),play=area(5),P_CENTERS={}}
SMODS={add_card=function(a)
 local card={config={center={key=a.key or'c_random',set=a.set}},ability={set=a.set}}
 a.area.cards[#a.area.cards+1]=card;added[#added+1]=a;return card
end,calculate_context=function(context)contexts[#contexts+1]=context end}
function ease_dollars(v,instant)ok(instant==true,'money applied before persisting emptied queue');money=money+v end
function save_run()saves=saves+1 end
function get_blind_amount(a)return 600 end
function number_format(v)return string.format('%.0f',v)end
Blind={set_blind=function(self,v)self.chips=v;self.chip_text=number_format(v);return'native'end}
function playing_card_joker_effects(cards)contexts[#contexts+1]={playing_card_added=true,cards=cards}end
C.install_hooks()
local blind=setmetatable({},{__index=Blind})
eq(blind:set_blind(506.25),'native','blind hook preserves native return')
eq(blind.chips,506,'shown506 means actual506, not hidden506.25')
blind:set_blind(412.5);eq(blind.chips,tonumber(number_format(412.5)),'same half-rounding as native display')
C.update()
eq(#G.jokers.cards,1,'one natal on new run');eq(G.jokers.cards[1].config.center.key,s.natal_key,'right natal')
eq(#G.consumeables.cards,1,'ante1 gives one fortune');eq(G.consumeables.cards[1].config.center.key,'c_tyg_fortune_1','best reward item')
C.update();eq(#G.consumeables.cards,1,'no repeated reward');eq(#G.jokers.cards,1,'no repeated starter')
eq(get_blind_amount(1),600,'best factor applies once');eq(get_blind_amount(3),750,'future preview uses future luck')
G.GAME.round_resets.ante=2;C.update();eq(#G.consumeables.cards,2,'ante2 reward once')
G.GAME.round_resets.ante=3;C.update();eq(#s.pending_items,1,'full inventory queues new fortune')
G.GAME.round_resets.ante=2;C.update();eq(#s.pending_items,1,'ante rewind cannot farm reward')
G.consumeables.cards={};C.update();eq(#G.consumeables.cards,1,'pending fortune delivered with room')
eq(G.consumeables.cards[1].config.center.key,'c_tyg_fortune_3','FIFO keeps correct reward')
G.consumeables.cards={};C.queue_effect(1);eq(#s.pending_effects,2,'rank1 means exactly2 Tarot')
C.update();eq(#G.consumeables.cards,2,'two real Tarot delivered')
eq(G.consumeables.cards[1].ability.set,'Tarot','not a Joker pack');eq(G.consumeables.cards[2].ability.set,'Tarot','second is Tarot')
C.queue_effect(2);C.update();eq(#s.pending_effects,2,'full inventory never silently drops promised effects')
G.consumeables.cards={};C.update();eq(G.consumeables.cards[2].config.center.key,s.route.planet_key,'rank2 recommended planet')
C.queue_effect(6);C.update();eq(money,3,'rank6 gives3 dollars')
C.queue_effect(7);C.update();eq(money,4,'rank7 gives1 dollar')
G.STATE=G.STATES.SELECTING_HAND
C.queue_effect(9);C.update();eq(#G.hand.cards,1,'stone enters current hand')
eq(added[#added].enhancement,'m_stone','stone enhancement explicit')
ok(contexts[#contexts].playing_card_added,'new playing card triggers growth effects')
G.STATE=G.STATES.SHOP;C.queue_effect(8);C.update();eq(#G.deck.cards,1,'ordinary reward joins deck outside combat')
local before=#added;local restored=R.copy(s);G.GAME.tyg_cycle=restored;C.update();eq(#added,before,'restore does not duplicate startup or rewards')
G.GAME.tyg_cycle=nil;eq(get_blind_amount(3),600,'other decks/legacy unaffected');C.update();eq(#added,before,'other decks no rewards')
blind:set_blind(506.25);eq(blind.chips,506.25,'other decks retain their native threshold behavior')
local expected_counts={2,2,2,1,1,0,0,0,0}
for rank=1,9 do
 local run=C.prepare_run(p);run.natal_given=true;run.seen_antes.ante_1=true
 G.GAME.tyg_cycle=run;G.GAME.round_resets.ante=1;G.STATE=G.STATES.SELECTING_HAND
 G.consumeables=area(2);G.hand=area(8)
 local ticket={ability={tyg_claim_id='ante_1'}}
 ok(C.queue_effect(rank,ticket),'each rank queues promised effect')
 ok(not C.queue_effect(rank,ticket),'same ticket cannot pay twice')
 ok(not C.queue_effect(rank,{ability={tyg_claim_id='ante_1'}}),'copied claim id cannot pay twice')
 C.update();eq(#G.consumeables.cards,expected_counts[rank],'exact consumable count for every rank')
 eq(#run.pending_effects,0,'delivered effects queue drains')
 if rank==1 or rank==4 then eq(G.consumeables.cards[1].ability.set,'Tarot','actual Tarot effect')end
 if rank==3 or rank==5 then eq(G.consumeables.cards[1].ability.set,'Planet','actual Planet effect')end
 if rank==8 or rank==9 then eq(#G.hand.cards,1,'every playing reward reaches hand')end
end
ok(saves>0,'persistent progress saved')
print('PASS '..n..' natal/cycle/fortune assertions')
