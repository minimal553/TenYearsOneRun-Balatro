return function(mod,R)
 local P={}
 local rarity_keys={'Common','Uncommon','Rare'}
 local pack_keys={'p_tyg_gift_common','p_tyg_gift_uncommon','p_tyg_gift_rare'}
 local own_packs={p_tyg_gift_common=true,p_tyg_gift_uncommon=true,p_tyg_gift_rare=true}
 local hand_guard_installed=false
 local function install_hand_guard()
  if hand_guard_installed or not G or not G.FUNCS or type(G.FUNCS.draw_from_hand_to_deck)~='function'then return end
  hand_guard_installed=true
  local previous=G.FUNCS.draw_from_hand_to_deck
  function G.FUNCS.draw_from_hand_to_deck(...)
   local booster=SMODS.OPENED_BOOSTER
   local center=booster and booster.config and booster.config.center
   -- Native pack cleanup returns the whole hand to the deck. Our no-draw gift
   -- may interrupt a live hand: preserve it, without changing other packs.
   if G and G.GAME and G.STATE==G.STATES.SMODS_BOOSTER_OPENED
     and G.GAME.PACK_INTERRUPT==G.STATES.SELECTING_HAND
     and center and own_packs[center.key]
     and booster.ability and booster.ability.tyg_preserve_hand then return end
   return previous(...)
  end
 end
 install_hand_guard()
 local function active()return G and G.GAME and G.GAME.tyg_run end
 local function idle()
  return G and(G.STATE==G.STATES.BLIND_SELECT or G.STATE==G.STATES.SHOP or G.STATE==G.STATES.SELECTING_HAND)
   and not G.booster_pack and not G.OVERLAY_MENU and not(G.SETTINGS and G.SETTINGS.paused)
   and not(G.CONTROLLER and(G.CONTROLLER.locked or(G.CONTROLLER.locks and G.CONTROLLER.locks.use)))
   and not(G.GAME and G.GAME.STOP_USE and G.GAME.STOP_USE>0)
   and not(G.play and G.play.cards and #G.play.cards>0)
 end
 function P.eligible(tier)
  local pool=get_current_pool('Joker',rarity_keys[tier],false,'tyg_gift')
  return R.filter_pool(pool,G.P_CENTERS,tier)
 end
 local function claim_reason(r)
  if not r then return '仅命局牌组可领取'end
  if r.gift_state~='unclaimed'then return '本局礼包已领取或正在领取'end
  if not idle()then return '请在选盲注、商店或等待出牌时使用'end
  if not G.jokers or #G.jokers.cards>=G.jokers.config.card_limit then return '请先空出一个小丑槽'end
  if #P.eligible(r.rarity)==0 then return '当前没有可用的对应稀有度小丑'end
  return nil
 end
 local function choose_keys(tier)
  local pool=P.eligible(tier)
  return R.pick_unique(pool,3,function(size,i)
   local indices={};for j=1,size do indices[j]=j end
   return pseudorandom_element(indices,pseudoseed('tyg_gift_'..tier..'_'..i))
  end)
 end
 local keys={'common','uncommon','rare'}
 for tier,key in ipairs(keys)do
  local tier_number=tier
  SMODS.Booster{
   key='gift_'..key,kind='TygGift',atlas='legacy_booster',pos={x=0,y=0},
   cost=0,weight=0,unlocked=true,discovered=true,draw_hand=false,config={extra=3,choose=1},
   in_pool=function()return false end,
   loc_txt={name=R.rarity_names[tier]..'命局包',group_name=R.rarity_names[tier]..'命局包',
    text={'所有候选均为{C:attention}'..R.rarity_names[tier]..'{}小丑','选择{C:attention}1{}张加入构筑'}},
   update_pack=SMODS.Booster.update_pack,create_UIBox=SMODS.Booster.create_UIBox,
   create_card=function(self,booster,index)
    local selected=booster.ability.tyg_candidates
    local key=selected and selected[index]
    assert(key and #R.filter_pool({key},G.P_CENTERS,tier_number)==1,'Tyg gift pool lost an exact-rarity candidate')
    return{set='Joker',key=key,area=G.pack_cards,skip_materialize=true,soulable=false,key_append='tyg_exact_gift'}
   end
  }
 end
 SMODS.Consumable{
  key='gift',set='Tarot',atlas='fortune',pos={x=0,y=0},cost=0,
  unlocked=true,discovered=true,in_pool=function()return false end,
  loc_txt={name='旧版小丑礼包券',text={'{C:inactive}仅用于继续0.3版旧存档{}','打开本局的{C:attention}#1#{}小丑包','全部候选同稀有度，最多三选一',
   '附赠{C:planet}#2#{}张推荐牌型星球牌','{C:inactive}选盲注、商店或等待出牌时可用{}','{C:inactive}需空出一个小丑槽{}',
   '{C:inactive}每局仅一次，复制不能重复领取{}','{C:inactive}#3#{}'}},
  loc_vars=function(self,info_queue,card)
   local r=active();return{vars={r and R.rarity_names[r.rarity]or'指定档次',r and r.planets_pending or 0,
    (r and r.last_error)or claim_reason(r)or'可领取；星球牌在开包后送入空槽'}}
  end,
  keep_on_use=function()return true end,
  can_use=function(self,card)
   return claim_reason(active())==nil
  end,
  use=function(self,card,area)
   local r=active()
   if r and r.gift_state=='unclaimed'then r.gift_state='pending';r.last_error=nil end
  end
 }
 local function find_ticket()
  for _,c in ipairs(G.consumeables and G.consumeables.cards or{})do
   if c.config.center.key=='c_tyg_gift'then return c end
  end
 end
 function P.update()
  install_hand_guard()
  local r=active()
  if not r or not idle()then return end
  if r.gift_state=='pending'then
   local token=find_ticket()
   if not token then r.gift_state='unclaimed';r.last_error='礼包券不在消耗品栏';return end
   if not G.jokers or #G.jokers.cards>=G.jokers.config.card_limit then return end
   local chosen=R.filter_pool(r.gift_keys,G.P_CENTERS,r.rarity)
   if #chosen==0 then chosen=choose_keys(r.rarity)end
   if #chosen==0 then r.gift_state='unclaimed';r.last_error='当前没有可用的对应稀有度小丑';return end
   local center=G.P_CENTERS[pack_keys[r.rarity]]
   if not center then r.gift_state='unclaimed';r.last_error='礼包尚未注册';return end
   local card=Card(G.play.T.x,G.play.T.y,G.CARD_W*1.27,G.CARD_H*1.27,G.P_CARDS.empty,center,{bypass_discovery_center=true,bypass_discovery_ui=true})
   local modifiers=G.GAME.modifiers or{}
   card.ability.tyg_candidates=chosen
   card.ability.tyg_preserve_hand=G.STATE==G.STATES.SELECTING_HAND
   card.ability.extra=#chosen-(modifiers.booster_size_mod or 0)
   card.ability.choose=1-(modifiers.booster_choice_mod or 0)
   card.cost=0;card.from_tag=true;r.gift_keys=R.copy(chosen)
   -- Native save_run ignores booster states. Save here, after consumable use
   -- has restored an idle state, with both the ticket and deterministic choices.
   save_run()
   r.gift_state='opening'
   G.FUNCS.use_card({config={ref_table=card}},nil,true)
   if SMODS.OPENED_BOOSTER==card and G.STATE==G.STATES.SMODS_BOOSTER_OPENED then
    r.gift_state='opened'
    token:remove_from_deck();if token.area then token.area:remove_card(token)end;token:start_dissolve()
    card:start_materialize()
   else
    r.gift_state='unclaimed';r.last_error='暂不能开包，请稍后再试';card:remove()
   end
   return
  end
  if r.gift_state=='opened'then r.gift_state='complete';save_run()end
  if r.gift_state=='complete'and(r.planets_pending or 0)>0 and G.consumeables then
   local changed=false
   while r.planets_pending>0 and #G.consumeables.cards<G.consumeables.config.card_limit do
    SMODS.add_card{set='Planet',key=r.route.planet_key,area=G.consumeables,no_edition=true,key_append='tyg_planet_reward'}
    r.planets_pending=r.planets_pending-1;changed=true
   end
   if changed then save_run()end
  end
 end
 return P
end
