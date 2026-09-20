local n=0
local function ok(v,m)n=n+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local ids={'zhengguan','qisha','zhengcai','piancai','zhengyin','pianyin','shishen','shangguan','jianlu','yuejie','yangren','cong_cai','cong_sha','cong_er','cong_shi','quzhi','yanshang','jiase','congge','runxia','hua_tu','hua_jin','hua_shui','hua_mu','hua_huo','changgui'}
local M={catalog={}};for _,id in ipairs(ids)do M.catalog[#M.catalog+1]={key=id,name=id}end
local registry={}
G={GAME={dollars=20,current_round={hands_left=2,discards_left=0}},hand={cards={}},play={}}
SMODS={Joker=function(j)registry[j.key]=j end}
local load=loadfile(TEST_ROOT..'/pattern_jokers.lua')
ok(type(load)=='function','26 pattern Joker implementation exists')
local P=load()({},M)
local function card(rank,suit,enhanced)
 return{base={id=rank},config={center={key=enhanced and'm_stone'or'c_base'}},
  is_face=function()return rank>=11 and rank<=13 end,get_id=function()return rank end,
  is_suit=function(self,s)return s==suit end}
end
local c2,c7,face=card(2,'Hearts'),card(7,'Spades'),card(12,'Clubs')
local function calc(id,ctx,combo)
 local j=assert(registry['mp_'..id]);local c={ability=R.copy(j.config or{})}
 c.ability.tyg_combo=combo and{key=combo,name=combo}or nil
 return j.calculate(j,c,ctx),j,c
end
local total=0
for _,id in ipairs(ids)do
 local j=registry['mp_'..id];ok(j,'catalog has real Joker '..id);total=total+1
 eq(j.atlas,'patterns','new art atlas');ok(not j.in_pool(),'not accidentally added to shop')
 local result=calc(id,{joker_main=true,full_hand={c2},scoring_hand={c2},poker_hands={}})
 ok(result and(result.mult or 0)>=4,'every chart starter has a useful base effect')
end
eq(total,26,'exact26 distinct corresponding centers')
eq(calc('zhengguan',{joker_main=true,full_hand={face},scoring_hand={face}}).mult,10,'official supports faces')
eq(calc('qisha',{joker_main=true,full_hand={c2,c7},scoring_hand={c2}}).mult,12,'seven-kill small hand')
eq(calc('yangren',{joker_main=true,full_hand={1,2,3,4,5},scoring_hand={c2}}).mult,12,'blade counts all played cards')
eq(calc('shishen',{individual=true,cardarea=G.play,other_card=c2}).mult,1,'food rewards nonfaces')
ok(not calc('shishen',{individual=true,cardarea=G.play,other_card=face}),'food excludes faces')
eq(registry.mp_zhengcai.calc_dollar_bonus(),2,'direct wealth cash')
eq(registry.mp_piancai.calc_dollar_bonus(),3,'spare hand wealth')
eq(calc('cong_cai',{joker_main=true}).mult,8,'follow wealth bounded money scaling')
eq(calc('cong_sha',{joker_main=true}).x_mult,1.8,'follow kill no-discard condition')
eq(calc('cong_er',{joker_main=true,scoring_hand={c2,c7}}).mult,12,'follow-output allnonface')
eq(calc('cong_shi',{joker_main=true,scoring_hand={c2,c7,face}}).x_mult,1.5,'three suit momentum')
eq(calc('quzhi',{joker_main=true,poker_hands={Straight={{}}}}).chips,30,'wood straight chips')
eq(calc('yanshang',{individual=true,cardarea=G.play,other_card=c2}).chips,10,'fire Hearts')
eq(calc('congge',{individual=true,cardarea=G.play,other_card=c7}).chips,10,'metal Spades')
eq(calc('runxia',{individual=true,cardarea=G.play,other_card=c2}).chips,10,'water low ranks')
eq(calc('hua_jin',{individual=true,cardarea=G.play,other_card=card(3,'Clubs',true)}).chips,15,'transformed enhanced cards')
eq(calc('hua_huo',{joker_main=true,poker_hands={['Full House']={{}}}}).x_mult,2,'transformed fire fullhouse')
local result,j,c=calc('zhengguan',{joker_main=true,full_hand={face},scoring_hand={face}},'guanyin')
eq(result.mult,13,'exactly one composite bonus stacked on primary')
local vars=j.loc_vars(j,{},c).vars
ok(vars[1]:find('guanyin',1,true),'matched trait name visible');ok(type(vars[2])=='string'and #vars[2]>0,'actual trait effect visible')
local _,food,food_card=calc('shishen',{joker_main=true},'shishengcai')
ok(type(food.calc_dollar_bonus)=='function','wealth-producing trait has actual cash callback')
eq(food.calc_dollar_bonus(food,food_card),1,'食神生财 produces real money after blind')
for key in pairs(P.combos)do
 local r=calc('changgui',{joker_main=true,full_hand={c2,c7,face},scoring_hand={c2,c7,face},poker_hands={Pair={{}}}},key)
 ok(r and r.mult>=4,'all composite callbacks safe')
end
print('PASS '..n..' expanded pattern Joker assertions')
