-- New-run rules. Legacy v0.3 snapshots remain owned by packs.lua.
return function(mod,R,M)
 local C={}
 C.patterns={
  jushi={key='bijie',name='比劫并肩'},huchi={key='guanyin',name='官印相生'},
  liansheng={key='shishang',name='食伤生财'},xucai={key='caixing',name='财星得用'},
  zhiheng={key='shayin',name='杀印相生'}}
 C.reward_names={'天赐','鸿运','兴旺','顺遂','平稳','薄助','微光','磨砺','逆境'}
 C.legacy_reward_text={
  '生成2张随机塔罗牌','生成1张随机塔罗牌和1张推荐星球牌','生成2张推荐星球牌',
  '生成1张随机塔罗牌','生成1张推荐星球牌','获得$3','获得$1',
  '加入1张普通标准牌','加入1张石头牌'}
 C.reward_text={
  '生成1张灵魂牌','生成1张随机幻灵牌','生成1张随机幻灵牌',
  '生成2张随机塔罗牌','生成2张随机塔罗牌',
  '50%获得2张倍率牌，50%获得2张奖励牌',
  '50%生成1张随机塔罗牌，否则生成1张随机星球牌',
  '50%生成1张随机塔罗牌，否则生成1张随机星球牌','生成1张冥王星牌'}
 function C.reward_version(run,card)
  local a=card and card.ability
  return(a and a.tyg_reward_version)or(run and(run.reward_version or 1))or 2
 end
 function C.reward_description(rank,version)
  local legacy=version==1
  local text=(legacy and C.legacy_reward_text or C.reward_text)[rank]
  local playing=(legacy and rank>=8)or(not legacy and rank==6)
  local note=playing and'加入牌组；战斗中进入当前手牌' or'空位不足时排队，空出后补齐'
  if legacy and(rank==6 or rank==7)then note='立即获得金币'end
  return text,note
 end
 local function tier(v)return type(v)=='number'and v==math.floor(v)and v>=1 and v<=3 end
 function C.grid(natal,luck,version)
  assert(tier(natal)and tier(luck),'Invalid cycle tier')
  local rank=(natal-1)*3+luck
  version=version or 2
  local text=C.reward_description(rank,version)
  return{rank=rank,target_multiplier=1+(rank-1)/8,reward_name=C.reward_names[rank],reward_text=text,reward_version=version}
 end
 function C.prepare_run(profile)
  local p,err=R.validate_profile(profile);assert(p,err)
  local pattern,natal_key,version
  if p.pattern then
   pattern=assert(M and M.by_key[p.pattern.key],'Unrecognized explicit chart pattern')
   natal_key=pattern.joker_key;version=2
  else
   pattern=assert(C.patterns[p.route.key],'Unrecognized legacy natal game template')
   natal_key='j_tyg_'..pattern.key;version=1
  end
  return{version=version,reward_version=2,mode=p.mode,preset_id=p.preset_id,chart=table.concat(p.chart,' '),natal_tier=p.natal_tier,
   natal_key=natal_key,pattern_name=pattern.name,pattern=R.copy(p.pattern),route=R.copy(p.route),
   decades=R.copy(p.decades),current_ante=0,natal_given=false,seen_antes={},
   pending_items={},pending_effects={},used_claims={},next_effect_id=0}
 end
 function C.phase(run,ante)
  local index=math.max(1,math.min(#run.decades,math.floor(ante or 1)))
  local d=run.decades[index];local g=C.grid(run.natal_tier,d.luck_tier,C.reward_version(run))
  g.decade=index;g.gan_zhi=d.gan_zhi;g.luck_tier=d.luck_tier
  g.start_date=d.start_date;g.end_date=d.end_date
  return g
 end
 function C.active()return G and G.GAME and G.GAME.tyg_cycle end
 function C.idle()
  return G and(G.STATE==G.STATES.BLIND_SELECT or G.STATE==G.STATES.SHOP or G.STATE==G.STATES.SELECTING_HAND)
   and not G.booster_pack and not G.OVERLAY_MENU and not(G.SETTINGS and G.SETTINGS.paused)
   and not(G.CONTROLLER and(G.CONTROLLER.locked or(G.CONTROLLER.locks and G.CONTROLLER.locks.use)))
   and not(G.GAME and G.GAME.STOP_USE and G.GAME.STOP_USE>0)
   and not(G.play and G.play.cards and #G.play.cards>0)
 end
 function C.can_claim(card)
  local r=C.active();if not r or not C.idle()then return false end
  local a=card and card.ability or{}
  return not a.tyg_used and not(a.tyg_claim_id and r.used_claims[a.tyg_claim_id])
 end
 function C.queue_effect(rank,card)
  local r=C.active();if not r or not C.reward_names[rank]then return false end
  local a=card and card.ability
  if a and(a.tyg_used or(a.tyg_claim_id and r.used_claims[a.tyg_claim_id]))then return false end
  local version=C.reward_version(r,card)
  if a then a.tyg_used=true;if a.tyg_claim_id then r.used_claims[a.tyg_claim_id]=true end end
  local function enqueue(kind,key,amount)
   r.next_effect_id=r.next_effect_id+1
   r.pending_effects[#r.pending_effects+1]={kind=kind,key=key,amount=amount,id=r.next_effect_id}
  end
  local function tarot()enqueue('Tarot')end
  local function planet()enqueue('Planet',r.route.planet_key)end
  if version==1 then
   if rank==1 then tarot();tarot()
   elseif rank==2 then tarot();planet()
   elseif rank==3 then planet();planet()
   elseif rank==4 then tarot()
   elseif rank==5 then planet()
   elseif rank==6 then enqueue('Money',nil,3)
   elseif rank==7 then enqueue('Money',nil,1)
   elseif rank==8 then enqueue('Playing')
   elseif rank==9 then enqueue('Playing','m_stone')end
  else
   if rank==1 then enqueue('Spectral','c_soul')
   elseif rank==2 or rank==3 then enqueue('Spectral')
   elseif rank==4 or rank==5 then tarot();tarot()
   elseif rank==6 then
    local key=pseudorandom('tyg_reward_pair_'..(r.next_effect_id+1))<0.5 and'm_mult'or'm_bonus'
    enqueue('Playing',key);enqueue('Playing',key)
   elseif rank==7 or rank==8 then
    local kind=pseudorandom('tyg_reward_kind_'..(r.next_effect_id+1))<0.5 and'Tarot'or'Planet'
    enqueue(kind)
   elseif rank==9 then enqueue('Planet','c_pluto')end
  end
  -- Native use is still in PLAY_TAROT here; only the stable update may save.
  r.reward_dirty=true
  return true
 end
 local hooked,blind_hooked=false,false
 function C.install_hooks()
  if not hooked and type(get_blind_amount)=='function'then
   hooked=true;local previous=get_blind_amount
   function get_blind_amount(ante)
    local base=previous(ante);local r=C.active()
    if not r then return base end
    return base*C.phase(r,ante).target_multiplier
   end
  end
  if not blind_hooked and Blind and type(Blind.set_blind)=='function'then
   blind_hooked=true;local previous=Blind.set_blind
   function Blind:set_blind(...)
    local result=previous(self,...)
    if C.active()and type(self.chips)=='number'and self.chips<math.huge and self.chips%1~=0 then
     -- The native HUD rounds with %.0f. Use exactly that threshold too, so
     -- reaching the displayed integer never loses to hidden fractional chips.
     self.chips=tonumber(string.format('%.0f',self.chips))
     self.chip_text=number_format(self.chips)
    end
    return result
   end
  end
 end
 local function room(area)return area and area.cards and area.config and #area.cards<area.config.card_limit end
 function C.update()
  C.install_hooks()
  local r=C.active();if not r or not C.idle()then return end
  local changed=r.reward_dirty or false
  if not r.natal_given and room(G.jokers)then
   local card=SMODS.add_card{set='Joker',key=r.natal_key,area=G.jokers,no_edition=true,key_append='tyg_natal'}
   if card then
    if r.pattern then
     card.ability.tyg_pattern_key=r.pattern.key
     card.ability.tyg_combo=R.copy(r.pattern.combo)
    end
    r.natal_given=true;changed=true
   end
  end
  local ante=math.max(1,math.floor(G.GAME.round_resets.ante or 1))
  if r.current_ante~=ante then r.current_ante=ante;changed=true end
  local claim='ante_'..ante
  if not r.seen_antes[claim]then
   local phase=C.phase(r,ante)
   r.pending_items[#r.pending_items+1]={key='c_tyg_fortune_'..phase.rank,claim_id=claim,reward_version=phase.reward_version}
   r.seen_antes[claim]=true;changed=true
  end
  -- Deliver promises before new tickets, so a full inventory cannot erase cards.
  while #r.pending_effects>0 do
   local e=r.pending_effects[1];local card
   if e.kind=='Money'then ease_dollars(e.amount,true)
   elseif e.kind=='Playing'then
    local target=G.STATE==G.STATES.SELECTING_HAND and G.hand or G.deck
    if not target then break end
    card=SMODS.add_card{set='Base',enhancement=e.key,area=target,no_edition=true,key_append='tyg_playing_'..e.id}
    if not card then break end
    playing_card_joker_effects({card})
   else
    if not room(G.consumeables)then break end
    card=SMODS.add_card{set=e.kind,key=e.key,area=G.consumeables,no_edition=true,soulable=false,
     key_append='tyg_fortune_effect_'..e.id}
    if not card then break end
   end
   table.remove(r.pending_effects,1);changed=true
  end
  while #r.pending_items>0 and room(G.consumeables)do
   local item=r.pending_items[1]
   local card=SMODS.add_card{key=item.key,area=G.consumeables,no_edition=true,key_append='tyg_'..item.claim_id}
   if not card then break end
   card.ability.tyg_claim_id=item.claim_id
   card.ability.tyg_reward_version=item.reward_version or C.reward_version(r)
   table.remove(r.pending_items,1);changed=true
  end
  if changed then r.reward_dirty=nil;save_run()end
 end
 return C
end
