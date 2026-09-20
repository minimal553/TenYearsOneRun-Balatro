local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local C=assert(loadfile(TEST_ROOT..'/cycles.lua'))()({},R)
local jokers,items,types={},{},{}
G={C={GREEN={},RED={},UI={TEXT_LIGHT={}}},GAME={dollars=16},play={}}
SMODS={Joker=function(v)jokers[v.key]=v end,Consumable=function(v)items[v.key]=v end,ConsumableType=function(v)types[v.key]=v end}
local jload=loadfile(TEST_ROOT..'/natal_jokers.lua')
ok(type(jload)=='function','five natal Joker module exists');jload()({},C)
local count=0;for _,j in pairs(jokers)do count=count+1;eq(j.atlas,'natal','custom natal artwork');ok(not j.in_pool(),'exclusive starter not random shop pool')end
eq(count,5,'five unique natal Jokers')
local function calc(key,context)
 local j=jokers[key];local card={ability=R.copy(j.config or{})}
 return j.calculate(j,card,context)
end
eq(calc('bijie',{joker_main=true,poker_hands={Pair={{}}}}).mult,12,'pair cooperation')
eq(calc('bijie',{joker_main=true,poker_hands={}}).mult,6,'bijie base')
local face={is_face=function()return true end};local number={is_face=function()return false end}
eq(calc('guanyin',{joker_main=true,scoring_hand={face}}).mult,8,'official seal supports faces')
eq(calc('guanyin',{joker_main=true,scoring_hand={face}}).chips,30,'official seal chips')
ok(not calc('guanyin',{joker_main=true,scoring_hand={number}}),'no face no official-seal trigger')
eq(calc('shishang',{individual=true,cardarea=G.play,other_card=number}).mult,2,'non-face expression')
ok(not calc('shishang',{individual=true,cardarea=G.play,other_card=face}),'faces excluded')
eq(jokers.shishang.calc_dollar_bonus(),2,'expression becomes money after blind')
eq(calc('caixing',{joker_main=true}).mult,8,'money gives bounded mult')
G.GAME.dollars=1000;eq(calc('caixing',{joker_main=true}).mult,24,'money ceiling')
eq(calc('shayin',{joker_main=true,full_hand={1,2,3}}).mult,12,'small hand defense')
eq(calc('shayin',{joker_main=true,full_hand={1,2,3}}).chips,40,'small hand chips')
eq(calc('shayin',{joker_main=true,full_hand={1,2,3,4}}).mult,4,'large hand fallback')
local fload=loadfile(TEST_ROOT..'/fortunes.lua')
ok(type(fload)=='function','nine fortune module exists');fload()({},C)
ok(types.TygFortune,'fortune has its own type, not Tarot')
local requested
C.can_claim=function(card)return not card.ability.tyg_used end
C.queue_effect=function(rank,card)requested=rank;card.ability.tyg_used=true end
for i=1,9 do
 local f=items['fortune_'..i];ok(f,'all nine items registered')
 eq(f.set,'TygFortune','not an Emperor or Tarot');eq(f.atlas,'fortune','custom envelope')
 ok(not f.in_pool(),'reward items do not pollute normal shops')
 local card={ability={}};ok(f.can_use(f,card),'usable item')
 f.use(f,card);eq(requested,i,'honest effect rank');ok(not f.can_use(f,card),'same item not twice')
end
print('PASS '..n..' natal Joker / fortune definitions assertions')
