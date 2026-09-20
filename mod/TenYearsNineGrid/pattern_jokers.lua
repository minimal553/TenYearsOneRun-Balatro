-- One starter center per pattern. Composite bonuses live on that one card.
return function(mod,M)
 local P={}
 P.combos={
  guanyin={name='官印相生',text='计分有人头牌：再+3倍率'},
  shayin={name='杀印相生',text='出牌不超过3张：再+3倍率'},
  shishengcai={name='食神生财',text='每个盲注结束再获得$1'},
  shangshengcai={name='伤官生财',text='每个盲注结束再获得$1'},
  shangpeiyin={name='伤官配印',text='出牌不超过3张：再+20筹码'},
  shizhi_sha={name='食神制杀',text='人头与非人头都计分：再+3倍率'},
  caishengguan={name='财生官',text='持有至少$10：再+3倍率'},
  caizisha={name='财滋七杀',text='持有至少$15且打出5张：再+3倍率'},
  bijieduocai={name='比劫夺财',text='出牌包含对子：再+25筹码'},
  xiaoduo_shi={name='枭印夺食',text='计分牌全部为人头牌：再+3倍率'},
  guansha={name='官杀并见',text='人头与非人头都计分：再+20筹码'},
  yinbi={name='印比相扶',text='包含对子且留手至少3张：再+3倍率'}}
 local descriptions={
  zhengguan={'计分有人头牌时，另{C:mult}+6{}倍率'},
  qisha={'打出不超过{C:attention}3{}张时，另{C:mult}+8{}倍率'},
  zhengcai={'每个盲注结束获得{C:money}$2{}'},
  piancai={'盲注结束尚有出牌次数时','额外获得{C:money}$3{}'},
  zhengyin={'每张留在手中的未失效人头牌','{C:chips}+10{}筹码，最多{C:chips}+60{}'},
  pianyin={'打出不超过{C:attention}3{}张时，{C:chips}+40{}筹码'},
  shishen={'每张计分的非人头牌另给{C:mult}+1{}倍率'},
  shangguan={'至少{C:attention}3{}张非人头牌计分时','另{C:mult}+8{}倍率'},
  jianlu={'每手{C:chips}+30{}筹码'},
  yuejie={'出牌包含{C:attention}对子{}时，另{C:mult}+6{}倍率'},
  yangren={'打出完整{C:attention}5{}张牌时，另{C:mult}+8{}倍率'},
  cong_cai={'每持有{C:money}$5{}再{C:mult}+1{}倍率','额外最多{C:mult}+16{}倍率'},
  cong_sha={'本轮弃牌次数用完后，给予{X:mult,C:white}X1.8{}倍率'},
  cong_er={'计分牌全部为非人头牌时','另{C:mult}+8{}倍率'},
  cong_shi={'计分牌含至少{C:attention}3{}种花色时','给予{X:mult,C:white}X1.5{}倍率'},
  quzhi={'出牌包含顺子时，{C:chips}+30{}筹码','并另{C:mult}+6{}倍率'},
  yanshang={'每张计分红桃给予{C:chips}+10{}筹码'},
  jiase={'至少{C:attention}2{}张未增强牌计分时','{C:chips}+40{}筹码'},
  congge={'每张计分黑桃给予{C:chips}+10{}筹码'},
  runxia={'每张计分的{C:attention}2至5{}给予{C:chips}+10{}筹码'},
  hua_tu={'计分牌恰好包含{C:attention}2{}种花色时','{C:chips}+50{}筹码'},
  hua_jin={'每张计分增强牌给予{C:chips}+15{}筹码'},
  hua_shui={'计分牌含至少{C:attention}2{}种花色时','另{C:mult}+6{}倍率'},
  hua_mu={'出牌包含顺子或同花时','另{C:mult}+6{}倍率'},
  hua_huo={'出牌包含葫芦时，给予{X:mult,C:white}X2{}倍率'},
  changgui={'每手{C:chips}+20{}筹码','{C:inactive}常规归类，不强判特殊格局{}'}}
 local function enhanced(card)
  return card.config and card.config.center and card.config.center.key~='c_base'
 end
 local function has(ctx,name)
  local hands=ctx.poker_hands and ctx.poker_hands[name]
  return hands and next(hands)~=nil
 end
 local function stats(ctx)
  local s={n=0,faces=0,nonfaces=0,plain=0,suits=0,played=#(ctx.full_hand or{})}
  local suits={}
  for _,card in ipairs(ctx.scoring_hand or{})do
   if not card.debuff then
    s.n=s.n+1
    if card:is_face()then s.faces=s.faces+1 else s.nonfaces=s.nonfaces+1 end
    if not enhanced(card)then s.plain=s.plain+1 end
    for _,suit in ipairs({'Hearts','Diamonds','Clubs','Spades'})do if card:is_suit(suit)then suits[suit]=true end end
   end
  end
  for _ in pairs(suits)do s.suits=s.suits+1 end
  return s
 end
 local function apply_combo(out,key,ctx,s)
  local dollars=G.GAME.dollars or 0
  local mult,chips=0,0
  if key=='guanyin'and s.faces>0 then mult=3
  elseif key=='shayin'and s.played>0 and s.played<=3 then mult=3
  elseif key=='shangpeiyin'and s.played>0 and s.played<=3 then chips=20
  elseif key=='shizhi_sha'and s.faces>0 and s.nonfaces>0 then mult=3
  elseif key=='caishengguan'and dollars>=10 then mult=3
  elseif key=='caizisha'and dollars>=15 and s.played==5 then mult=3
  elseif key=='bijieduocai'and has(ctx,'Pair')then chips=25
  elseif key=='xiaoduo_shi'and s.n>0 and s.faces==s.n then mult=3
  elseif key=='guansha'and s.faces>0 and s.nonfaces>0 then chips=20
  elseif key=='yinbi'and has(ctx,'Pair')and G.hand and #G.hand.cards>=3 then mult=3 end
  if mult>0 then out.mult=out.mult+mult end
  if chips>0 then out.chips=(out.chips or 0)+chips end
 end
 for index,definition in ipairs(M.catalog)do
  local key=definition.key
  local text={'每手{C:mult}+4{}倍率'}
  for _,line in ipairs(assert(descriptions[key],'Missing pattern behavior '..key))do text[#text+1]=line end
  text[#text+1]='{C:attention}#1#{}';text[#text+1]='{C:inactive}#2#{}'
  local function bonus(self,card)
   local amount=key=='zhengcai'and 2 or(key=='piancai'and(G.GAME.current_round.hands_left or 0)>0 and 3 or 0)
   local combo=card and card.ability and card.ability.tyg_combo
   if combo and(combo.key=='shishengcai'or combo.key=='shangshengcai')then amount=amount+1 end
   return amount>0 and amount or nil
  end
  SMODS.Joker{
   key='mp_'..key,atlas='patterns',pos={x=(index-1)%5,y=math.floor((index-1)/5)},
   rarity=2,cost=6,unlocked=true,discovered=true,blueprint_compat=true,eternal_compat=true,perishable_compat=true,
   config={extra={}},in_pool=function()return false end,
   loc_txt={name=definition.name,text=text},calc_dollar_bonus=bonus,
   loc_vars=function(self,info_queue,card)
    local combo=card and card.ability and card.ability.tyg_combo
    local effect=combo and P.combos[combo.key]
    return{vars={effect and('组合：'..(combo.name or effect.name))or'组合：无附加词条',
     effect and effect.text or'开局按命盘匹配；一张牌最多一个组合'}}
   end,
   calculate=function(self,card,ctx)
    if ctx.individual and ctx.cardarea==G.play and ctx.other_card then
     local c=ctx.other_card
     if key=='shishen'and not c:is_face()then return{mult=1}
     elseif key=='yanshang'and c:is_suit('Hearts')then return{chips=10}
     elseif key=='congge'and c:is_suit('Spades')then return{chips=10}
     elseif key=='runxia'and c:get_id()>=2 and c:get_id()<=5 then return{chips=10}
     elseif key=='hua_jin'and enhanced(c)then return{chips=15}end
    end
    if not ctx.joker_main then return end
    local s=stats(ctx);local out={mult=4}
    if key=='zhengguan'and s.faces>0 then out.mult=10
    elseif key=='qisha'and s.played>0 and s.played<=3 then out.mult=12
    elseif key=='zhengyin'then
     local faces=0;for _,c in ipairs(G.hand and G.hand.cards or{})do if not c.debuff and c:is_face()then faces=faces+1 end end
     out.chips=math.min(60,faces*10)
    elseif key=='pianyin'and s.played>0 and s.played<=3 then out.chips=40
    elseif key=='shangguan'and s.nonfaces>=3 then out.mult=12
    elseif key=='jianlu'then out.chips=30
    elseif key=='yuejie'and has(ctx,'Pair')then out.mult=10
    elseif key=='yangren'and s.played==5 then out.mult=12
    elseif key=='cong_cai'then out.mult=4+math.min(16,math.floor(math.max(0,G.GAME.dollars or 0)/5))
    elseif key=='cong_sha'and G.GAME.current_round.discards_left==0 then out.x_mult=1.8
    elseif key=='cong_er'and s.n>0 and s.nonfaces==s.n then out.mult=12
    elseif key=='cong_shi'and s.suits>=3 then out.x_mult=1.5
    elseif key=='quzhi'and has(ctx,'Straight')then out.chips=30;out.mult=10
    elseif key=='jiase'and s.plain>=2 then out.chips=40
    elseif key=='hua_tu'and s.suits==2 then out.chips=50
    elseif key=='hua_shui'and s.suits>=2 then out.mult=10
    elseif key=='hua_mu'and(has(ctx,'Straight')or has(ctx,'Flush'))then out.mult=10
    elseif key=='hua_huo'and has(ctx,'Full House')then out.x_mult=2
    elseif key=='changgui'then out.chips=20 end
    local combo=card.ability.tyg_combo
    if combo and P.combos[combo.key]then apply_combo(out,combo.key,ctx,s)end
    return out
   end}
 end
 return P
end
