return function(mod,C)
 SMODS.ConsumableType{key='TygFortune',primary_colour=G.C.GREEN,secondary_colour=G.C.RED,
  collection_rows={5,4},shop_rate=0,
  loc_txt={name='大运签',collection='大运签',undiscovered={name='未发现的大运签',text={'在命局牌组推进大运时获得'}}}}
 for rank=1,9 do
  local tier=rank
  local text={C.reward_text[tier]}
  if tier<=5 then text[#text+1]='{C:inactive}空位不足时排队，空出后补齐{}'
  elseif tier>=8 then text[#text+1]='{C:inactive}加入牌组；战斗中进入当前手牌{}'end
  text[#text+1]='{C:inactive}大运奖励；不会打开任何卡包{}'
  SMODS.Consumable{key='fortune_'..tier,set='TygFortune',atlas='fortune',pos={x=0,y=0},
   cost=0,unlocked=true,discovered=true,in_pool=function()return false end,
   loc_txt={name=C.reward_names[tier]..'·运签',text=text},
   can_use=function(self,card)return C.can_claim(card)end,
   use=function(self,card)C.queue_effect(tier,card)end}
 end
end
