return function(mod,C)
 SMODS.ConsumableType{key='TygFortune',primary_colour=G.C.GREEN,secondary_colour=G.C.RED,
  collection_rows={5,4},shop_rate=0,
  loc_txt={name='大运签',collection='大运签',undiscovered={name='未发现的大运签',text={'在命局牌组推进大运时获得'}}}}
 for rank=1,9 do
  local tier=rank
  SMODS.Consumable{key='fortune_'..tier,set='TygFortune',atlas='fortune',pos={x=0,y=0},
   cost=0,unlocked=true,discovered=true,in_pool=function()return false end,
   loc_txt={name=C.reward_names[tier]..'·运签',text={
    '#1#','{C:inactive}#2#{}','{C:inactive}大运奖励；不会打开任何卡包{}'}},
   loc_vars=function(self,info_queue,card)
    local text,note=C.reward_description(tier,C.reward_version(C.active(),card))
    return{vars={text,note}}
   end,
   can_use=function(self,card)return C.can_claim(card)end,
   use=function(self,card)C.queue_effect(tier,card)end}
 end
end
