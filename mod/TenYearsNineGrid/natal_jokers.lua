return function(mod,C)
 local function register(key,pos,config,text,calculate,bonus)
  SMODS.Joker{key=key,atlas='natal',pos={x=pos,y=0},rarity=2,cost=6,
   unlocked=true,discovered=true,blueprint_compat=true,eternal_compat=true,perishable_compat=true,
   config=config,in_pool=function()return false end,
   loc_txt={name=({bijie='比劫并肩',guanyin='官印相生',shishang='食伤生财',caixing='财星得用',shayin='杀印相生'})[key],text=text},
   calculate=calculate,calc_dollar_bonus=bonus}
 end
 register('bijie',0,{}, {'{C:mult}+6{}倍率','出牌包含{C:attention}对子{}时','再获得{C:mult}+6{}倍率'},function(self,card,ctx)
  if ctx.joker_main then
   local pair=ctx.poker_hands and ctx.poker_hands.Pair
   return{mult=pair and next(pair)and 12 or 6}
  end
 end)
 register('guanyin',1,{}, {'计分牌中有人头牌时','获得{C:chips}+30{}筹码','以及{C:mult}+8{}倍率'},function(self,card,ctx)
  if ctx.joker_main then
   for _,c in ipairs(ctx.scoring_hand or{})do if c:is_face()then return{chips=30,mult=8}end end
  end
 end)
 register('shishang',2,{}, {'每张计分的{C:attention}非人头牌{}','给予{C:mult}+2{}倍率','每个盲注结束获得{C:money}$2{}'},function(self,card,ctx)
  if ctx.individual and ctx.cardarea==G.play and ctx.other_card and not ctx.other_card:is_face()then return{mult=2}end
 end,function()return 2 end)
 register('caixing',3,{}, {'{C:mult}+4{}倍率；每持有{C:money}$4{}','再获得{C:mult}+1{}倍率','额外倍率最多{C:mult}+20{}'},function(self,card,ctx)
  if ctx.joker_main then return{mult=4+math.min(20,math.floor(math.max(0,G.GAME.dollars or 0)/4))}end
 end)
 register('shayin',4,{}, {'{C:mult}+4{}倍率','出牌不超过{C:attention}3{}张时，改为','{C:chips}+40{}筹码、{C:mult}+12{}倍率'},function(self,card,ctx)
  if ctx.joker_main then
   local n=#(ctx.full_hand or{})
   return n>0 and n<=3 and{chips=40,mult=12}or{mult=4}
  end
 end)
end
