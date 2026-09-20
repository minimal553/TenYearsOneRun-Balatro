-- Actual callbacks and EventManager run inside the owned game process.
-- Fixtures are synthetic; no real saved birth data is loaded.
TYG_QA_SCENARIOS={}
function TYG_QA_SCENARIOS.cycle(qa,note,capture,finish,native_blind_amount)
 local step='menu';local at=love.timer.getTime();local original_hand,original_deck
 local cycle,initial_rank;local fixture_rank,fixture_card,fixture_before,rank1_blocker,rank1_queue_seen,fixture_drained_at
 local last_probe
 local playing_contexts=0
 local natal_triggers=0;local hand_play_before
 local natal_center=assert(G.P_CENTERS.j_tyg_mp_shishen,'expanded natal center missing')
 local native_natal_calculate=natal_center.calculate
 natal_center.calculate=function(self,card,context)
  local result=native_natal_calculate(self,card,context)
  if context.individual and context.cardarea==G.play and result and result.mult==1 then
   natal_triggers=natal_triggers+1
  end
  return result
 end
 local original_context=SMODS.calculate_context
 SMODS.calculate_context=function(context,...)
  if context.playing_card_added then playing_contexts=playing_contexts+1 end
  return original_context(context,...)
 end
 local function advance(next_step)step=next_step;at=love.timer.getTime();note('cycle_'..step)end
 local function ready()
  return cycle and cycle.idle()and not G.CONTROLLER.lock_input
 end
 local function cards(area)
  local list={};for i,card in ipairs(area.cards)do list[i]=card end;return list
 end
 local function identity(area,expected,label)
  assert(#area.cards==#expected,label..' count changed')
  for i,card in ipairs(expected)do assert(area.cards[i]==card,label..' identity/order changed')end
 end
 local function fortune(claim)
  for _,card in ipairs(G.consumeables.cards)do
   if card.ability.tyg_claim_id==claim then return card end
  end
 end
 local function find_option(node,callback)
  local config=node.config or{}
  if config.button=='option_cycle'and config.ref_value=='r'and config.ref_table
   and config.ref_table.opt_callback==callback then return node end
  for _,child in pairs(node.children or{})do
   local match=find_option(child,callback);if match then return match end
  end
 end
 local function begin_fixture()
  fixture_card=SMODS.add_card{key='c_tyg_fortune_'..fixture_rank,area=G.consumeables,no_edition=true}
  fixture_card.ability.tyg_claim_id='qa_fixture_rank_'..fixture_rank
  rank1_blocker=nil;rank1_queue_seen=false;fixture_drained_at=nil
  if fixture_rank==1 then
   rank1_blocker=SMODS.add_card{set='Planet',key=cycle.active().route.planet_key,area=G.consumeables,no_edition=true}
  end
  local set={};for _,card in ipairs(G.playing_cards)do set[card]=true end
  fixture_before={hand=cards(G.hand),deck=cards(G.deck),playing=#G.playing_cards,
   capacity=G.deck.config.card_limit,contexts=playing_contexts,dollars=G.GAME.dollars,playing_set=set}
  assert(fixture_card:can_use_consumeable(),'fixture fortune cannot be used')
  note('fixture_fortune_granted',{rank=fixture_rank,claim=fixture_card.ability.tyg_claim_id,
   source='QA fixture; separate from normal per-ante grant'})
  G.FUNCS.use_card{config={ref_table=fixture_card}}
  advance('fixture_reward')
 end
 local function next_fixture()
  if fixture_rank==9 then save_run();advance('save')
  else fixture_rank=fixture_rank+1;advance('fixture_clear')end
 end
 return function()
  assert(love.timer.getTime()-at<80,'cycle stage timeout: '..step)
  if not last_probe or love.timer.getTime()-last_probe>10 then
   last_probe=love.timer.getTime()
   local r=cycle and cycle.active()
   note('cycle_probe',{step=step,state=G.STATE,paused=G.SETTINGS.paused,
    locked=G.CONTROLLER.locked,locks=G.CONTROLLER.locks,lock_input=G.CONTROLLER.lock_input,
    has_overlay=G.OVERLAY_MENU~=nil,has_cycle=r~=nil,natal_given=r and r.natal_given,
    stop_use=G.GAME.STOP_USE,play=G.play and #G.play.cards,
    jokers=G.jokers and #G.jokers.cards,consumeables=G.consumeables and #G.consumeables.cards})
   if step=='initial'then capture('runtime-qa-initial-diagnostic.png')end
  end
  if step=='menu'then
   local mod=assert(SMODS.Mods.ten_years_nine_grid,'production mod missing')
   cycle=assert(mod.tyg_cycles,'0.4 cycle API missing')
   for _,key in ipairs({'tyg_deck','tyg_fortune','tyg_natal','tyg_patterns','tyg_legacy_booster'})do
    assert(G.ASSET_ATLAS[key]and G.ASSET_ATLAS[key].image,'custom atlas missing: '..key)
   end
   capture('runtime-qa-menu.png',function()
    G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'},stake=1,seed='TYGQA04'})
    advance('entry')
   end)
   advance('capture_menu')
  elseif step=='entry'and G.OVERLAY_MENU then
   G.FUNCS.tyg_choose_birth();advance('birthday')
  elseif step=='birthday'and G.OVERLAY_MENU then
   for _,field in ipairs({{'tyg_birth_date','20050412'},{'tyg_birth_time','030'}})do
    local element=assert(G.OVERLAY_MENU:get_UIE_by_ID(field[1]),'real birthday field missing')
    G.FUNCS.select_text_input(element)
    for i=1,#field[2]do G.FUNCS.text_input_key{key=field[2]:sub(i,i)}end
    G.FUNCS.text_input_key{key='return'}
   end
   G.FUNCS.tyg_birth_gender{to_key=2}
   G.FUNCS.tyg_birth_match()
   local profile=assert(SMODS.Mods.ten_years_nine_grid.tyg_birth.current_profile(),'030 native input did not match')
   assert(profile.natal_tier==1 and profile.decades[1].luck_tier==2,'fixture rank drifted')
   assert(profile.pattern and profile.pattern.key=='shishen'and not profile.pattern.combo,'pattern fixture identity drifted')
   assert(#profile.pattern.reasons>0,'no visible matching basis')
   local next_decade=assert(find_option(G.OVERLAY_MENU.UIRoot,'tyg_birth_decade'),'native preview arrow absent')
   for i=1,5 do G.FUNCS.option_cycle(next_decade)end
   advance('preview')
  elseif step=='preview'and love.timer.getTime()-at>2 then
   capture('runtime-qa-birthday-preview.png',function()
    G.FUNCS.tyg_birth_start();advance('initial')
   end)
   advance('capture_preview')
  elseif step=='initial'and ready()then
   local r=assert(cycle.active(),'new cycle snapshot absent')
   if not r.natal_given or not fortune('ante_1')then return end
   assert(G.GAME.win_ante==8 and not G.GAME.tyg_run,'new run must use eight-ante cycle')
   assert(r.current_ante==1,'preview selection incorrectly changed starting decade')
   assert(#G.jokers.cards==1 and G.jokers.cards[1].config.center.key==r.natal_key,'exclusive natal Joker mismatch')
   assert(r.version==2 and r.pattern.key=='shishen'and r.natal_key=='j_tyg_mp_shishen','new run fell back to old five templates')
   assert(G.jokers.cards[1].ability.tyg_pattern_key=='shishen','starter has no saved pattern identity')
   local M=SMODS.Mods.ten_years_nine_grid.tyg_patterns
   assert(#M.catalog==26,'incomplete pattern catalog')
   for i,row in ipairs(M.catalog)do
    local center=assert(G.P_CENTERS[row.joker_key],'pattern center missing '..row.key)
    assert(center.atlas=='tyg_patterns'and center.pos.x==(i-1)%5 and center.pos.y==math.floor((i-1)/5),'wrong pattern atlas cell')
    local sample=SMODS.create_card{set='Joker',key=row.joker_key,area=G.jokers,skip_materialize=true,no_edition=true}
    assert(sample.children.center.atlas.image==G.ASSET_ATLAS.tyg_patterns.image,'actual pattern sprite has wrong image')
    sample:remove()
   end
   note('all_pattern_centers_verified',{count=26,starter=r.natal_key,status=r.pattern.status})
   assert(G.GAME.selected_back.effect.center.key=='b_tyg_mingju'and G.GAME.selected_back.atlas=='tyg_deck',
    'new run did not select the real custom back')
   for _,card in ipairs(G.playing_cards)do
    assert(card.children.back.atlas.image==G.ASSET_ATLAS.tyg_deck.image,'new playing card uses wrong back texture')
   end
   local ticket=fortune('ante_1');initial_rank=cycle.phase(r,1).rank
   assert(initial_rank==2 and ticket.config.center.key=='c_tyg_fortune_2','first fortune rank mismatch')
   assert(ticket.config.center.set=='TygFortune'and ticket.config.center.atlas=='tyg_fortune','fortune is not custom type/art')
   assert(not G.booster_pack and G.STATE==G.STATES.BLIND_SELECT,'new run auto-opened a pack')
   note('initial_verified',{natal_key=r.natal_key,rank=initial_rank,ante=r.current_ante})
   advance('initial_settle')
  elseif step=='initial_settle'and ready()and love.timer.getTime()-at>2 then
   capture('runtime-qa-initial-run.png',function()
    local option=assert(G.blind_select_opts.small,'native small-blind UI absent')
    local button=assert(option:get_UIE_by_ID('select_blind_button'),'native blind button absent')
    G.FUNCS.select_blind(button);advance('hand')
   end)
   advance('capture_initial')
  elseif step=='hand'and G.STATE==G.STATES.SELECTING_HAND and ready()then
   assert(#G.hand.cards>0,'blind must draw native hand')
   local shown=tonumber((G.GAME.blind.chip_text:gsub(',','')))
   assert(shown and G.GAME.blind.chips==shown,'actual blind threshold differs from its displayed integer')
   note('threshold_display_verified',{chips=G.GAME.blind.chips,text=G.GAME.blind.chip_text})
   original_hand=cards(G.hand);original_deck=cards(G.deck)
   local ticket=assert(fortune('ante_1'),'initial ticket disappeared')
   assert(ticket:can_use_consumeable(),'fortune not usable after entering blind')
   G.FUNCS.use_card({config={ref_table=ticket}})
   advance('reward')
  elseif step=='reward'and ready()then
   local r=cycle.active()
   if #r.pending_effects>0 then return end
   assert(not G.booster_pack and G.STATE==G.STATES.SELECTING_HAND,'fortune opened a booster or lost state')
   identity(G.hand,original_hand,'hand');identity(G.deck,original_deck,'deck')
   assert(r.used_claims.ante_1,'fortune claim was not persisted')
   assert(#G.consumeables.cards==2,'rank two must give exactly two consumables')
   local sets={};for _,card in ipairs(G.consumeables.cards)do sets[card.ability.set]=(sets[card.ability.set]or 0)+1 end
   assert(sets.Tarot==1 and sets.Planet==1,'rank two must give Tarot plus recommended Planet')
   note('native_fortune_verified',{hand=#G.hand.cards,tarot=sets.Tarot,planet=sets.Planet})
   advance('reward_settle')
  elseif step=='reward_settle'and ready()and love.timer.getTime()-at>1 then
   capture('runtime-qa-fortune-used.png',function()
    local selected
    for _,card in ipairs(G.hand.cards)do
     if card.config.center.key=='c_base'and not card:is_face()and(not selected or card.base.nominal<selected.base.nominal)then selected=card end
    end
    assert(selected,'no normal non-face fixture card available to play')
    hand_play_before={hands=G.GAME.current_round.hands_left,deck=#G.deck.cards,
     hand=#G.hand.cards,chips=G.GAME.chips,triggers=natal_triggers}
    G.hand:unhighlight_all();G.hand:add_to_highlighted(selected)
    G.FUNCS.play_cards_from_highlighted();advance('native_hand')
   end)
   advance('capture_reward')
  elseif step=='native_hand'and G.STATE==G.STATES.SELECTING_HAND and ready()then
   assert(G.GAME.current_round.hands_left==hand_play_before.hands-1,'native play did not spend exactly one hand')
   assert(G.GAME.chips>hand_play_before.chips,'native scoring produced no chips')
   assert(natal_triggers>hand_play_before.triggers,'exclusive natal Joker did not participate in real scoring')
   assert(#G.hand.cards==hand_play_before.hand and #G.deck.cards==hand_play_before.deck-1,
    'native play/draw cycle did not refill exactly one card')
   note('native_hand_verified',{chips=G.GAME.chips,hands_left=G.GAME.current_round.hands_left,
    hand=#G.hand.cards,deck=#G.deck.cards,natal_triggers=natal_triggers-hand_play_before.triggers})
   advance('native_hand_settle')
  elseif step=='native_hand_settle'and ready()and love.timer.getTime()-at>1 then
   capture('runtime-qa-native-hand-played.png',function()ease_ante(1);advance('ante')end)
   advance('capture_native_hand')
  elseif step=='ante'and ready()and cycle.active().current_ante==2 then
   local r=cycle.active();local phase=cycle.phase(r,2)
   assert(G.GAME.round_resets.ante==2 and r.seen_antes.ante_2,'native ease_ante did not advance cycle')
   assert(math.abs(get_blind_amount(2)-native_blind_amount(2)*phase.target_multiplier)<.001,
    'dynamic target multiplier differs from native base')
   assert(#G.consumeables.cards==2 and #r.pending_items==1,'full consumable inventory must queue new fortune')
   assert(r.pending_items[1].claim_id=='ante_2','wrong queued claim')
   note('ante_queue_verified',{rank=phase.rank,multiplier=phase.target_multiplier,pending=#r.pending_items})
   G.FUNCS.sell_card{config={ref_table=G.consumeables.cards[1]}}
   advance('deliver_ante')
  elseif step=='deliver_ante'and ready()and fortune('ante_2')then
   assert(#cycle.active().pending_items==0 and #G.consumeables.cards==2,'queued fortune did not fill exactly one slot')
   fixture_rank=1;advance('fixture_clear')
  elseif step=='fixture_clear'and ready()then
   if #G.consumeables.cards>0 then G.FUNCS.sell_card{config={ref_table=G.consumeables.cards[1]}}
   else begin_fixture()end
  elseif step=='fixture_reward'and ready()and love.timer.getTime()-at>.5 then
   local r=cycle.active()
   assert(#G.consumeables.cards<=G.consumeables.config.card_limit,'fortune overflowed consumable capacity')
   assert(not G.booster_pack and G.STATE==G.STATES.SELECTING_HAND,'fixture fortune opened a pack/lost hand state')
   if fixture_rank==1 and not rank1_queue_seen then
    assert(#r.pending_effects==1 and #G.consumeables.cards==2,'second Tarot must wait behind full slots')
    rank1_queue_seen=true;note('rank1_second_tarot_queued',{pending=1,inventory=2})
    G.FUNCS.sell_card{config={ref_table=rank1_blocker}};return
   end
   if #r.pending_effects>0 then return end
   -- C.update drains effects after native CardArea.update in this frame.
   -- Give the real next-frame capacity/context updates time to finish.
   fixture_drained_at=fixture_drained_at or love.timer.getTime()
   if love.timer.getTime()-fixture_drained_at<.3 then return end
   local sets={};for _,card in ipairs(G.consumeables.cards)do sets[card.ability.set]=(sets[card.ability.set]or 0)+1 end
   local expected_tarot=({[1]=2,[2]=1,[4]=1})[fixture_rank]or 0
   local expected_planet=({[2]=1,[3]=2,[5]=1})[fixture_rank]or 0
   assert((sets.Tarot or 0)==expected_tarot and(sets.Planet or 0)==expected_planet,
    'native fortune output mismatch for rank '..fixture_rank)
   assert(#G.consumeables.cards==expected_tarot+expected_planet,'unexpected reward type')
   if fixture_rank==6 or fixture_rank==7 then
    assert(G.GAME.dollars==fixture_before.dollars+(fixture_rank==6 and 3 or 1),'money reward mismatch')
   end
   if fixture_rank<8 then
    identity(G.hand,fixture_before.hand,'fixture hand');identity(G.deck,fixture_before.deck,'fixture deck')
   else
    assert(#G.playing_cards==fixture_before.playing+1,'reward not added to permanent playing cards')
    assert(#G.hand.cards==#fixture_before.hand+1,'in-blind generated card did not join current hand')
    assert(G.deck.config.card_limit==fixture_before.capacity+1,'permanent deck capacity did not increase')
    assert(playing_contexts==fixture_before.contexts+1,'playing_card_added must trigger exactly once')
    local added;for _,card in ipairs(G.playing_cards)do if not fixture_before.playing_set[card]then added=card end end
    assert(added and added.config.center.key==(fixture_rank==9 and'm_stone'or'c_base'),'playing enhancement mismatch')
   end
   assert(not cycle.queue_effect(fixture_rank,fixture_card),'used or copied fixture repeated its reward')
   note('native_fixture_verified',{rank=fixture_rank,tarot=expected_tarot,planet=expected_planet,
    hand=#G.hand.cards,permanent_cards=#G.playing_cards,booster=false})
   if fixture_rank==1 then advance('rank1_screenshot')else next_fixture()end
  elseif step=='rank1_screenshot'and ready()and love.timer.getTime()-at>1 then
   capture('runtime-qa-rank1-two-tarots.png',next_fixture);advance('capture_rank1')
  elseif step=='save'and ready()then
   local data=get_compressed(G.SETTINGS.profile..'/save.jkr')
   if not data then return end
   local saved=STR_UNPACK(data);local r=saved.GAME and saved.GAME.tyg_cycle
   if not r or r.current_ante~=2 or #saved.cardAreas.hand.cards~=#G.hand.cards then return end
   qa.expected_reload={ante=2,natal_key=r.natal_key,pattern_key=r.pattern.key,combo_key=r.pattern.combo and r.pattern.combo.key,hand_count=#G.hand.cards,
    playing_count=#G.playing_cards,consumeable_count=#G.consumeables.cards,claim1_used=true}
   love.filesystem.write('runtime-qa-reload-expected.json',JSON.encode(qa.expected_reload))
   capture('runtime-qa-cycle-saved.png',finish);advance('capture_save')
  end
 end
end

function TYG_QA_SCENARIOS.reload(qa,note,capture,finish)
 local requested=false;local seen;local expected=JSON.decode(assert(love.filesystem.read('runtime-qa-reload-expected.json')))
 local reclassifications=0
 local matcher=SMODS.Mods.ten_years_nine_grid.tyg_patterns
 if matcher then
  local classify=matcher.classify
  matcher.classify=function(...)reclassifications=reclassifications+1;return classify(...)end
 end
 return function()
  local mod=assert(SMODS.Mods.ten_years_nine_grid);local cycle=assert(mod.tyg_cycles)
  if not requested then
   local saved=assert(get_compressed(G.SETTINGS.profile..'/save.jkr'),'private save is missing')
   G.SAVED_GAME=STR_UNPACK(saved)
   note('reload_saved_back',{name=G.SAVED_GAME.BACK.name,key=G.SAVED_GAME.BACK.key,
    viewed_type=type(G.SAVED_GAME.GAME.viewed_back),viewed_value=tostring(G.SAVED_GAME.GAME.viewed_back),
    registered_name=G.P_CENTERS.b_tyg_mingju.name,registered_atlas=G.P_CENTERS.b_tyg_mingju.atlas})
   G.FUNCS.start_run(nil,{savetext=G.SAVED_GAME});requested=true;note('reload_requested');return
  end
  if not cycle.idle()or not cycle.active()then return end
  local r=cycle.active()
  if not qa.back_checked then
   local back=G.GAME.selected_back
   local sprite=G.deck.cards[#G.deck.cards].children.back
   local correct_image=sprite.atlas.image==G.ASSET_ATLAS.tyg_deck.image
   note('reload_live_back',{name=back.name,key=back.effect.center.key,atlas=back.atlas,
    viewed_type=type(G.GAME.viewed_back),viewed_value=tostring(G.GAME.viewed_back),
    sprite_atlas_key=sprite.atlas.key,sprite_atlas_name=sprite.atlas.name,correct_image=correct_image})
   assert(back.effect.center.key=='b_tyg_mingju'and back.atlas=='tyg_deck','saved deck identity/atlas not restored')
   assert(correct_image,'actual reloaded playing-card back uses the wrong texture')
   for _,card in ipairs(G.playing_cards)do
    assert(card.children.back.atlas.image==G.ASSET_ATLAS.tyg_deck.image,'a reloaded playing card uses wrong back texture')
   end
   qa.back_checked=true
  end
  assert(not G.OVERLAY_MENU,'continue unexpectedly asked for birthday')
  assert(r.current_ante==expected.ante and r.natal_key==expected.natal_key,'cycle identity changed on reload')
  if expected.mode then assert(r.mode==expected.mode,'entry mode lost on reload')end
  if expected.preset_id then
   assert(r.preset_id==expected.preset_id,'preset identity lost on reload')
   for ante=1,9 do assert(cycle.phase(r,ante).rank==expected.rank,'fixed preset tiers changed on reload')end
  end
  assert((not not r.used_claims.ante_1)==expected.claim1_used,'fortune claim status changed on reload')
   assert(#G.jokers.cards==1 and G.jokers.cards[1].config.center.key==r.natal_key,'natal Joker duplicated on reload')
   if expected.pattern_key then
    assert(r.pattern and r.pattern.key==expected.pattern_key,'saved pattern changed on reload')
    assert(G.jokers.cards[1].ability.tyg_pattern_key==expected.pattern_key,'card pattern identity lost')
    local combo=G.jokers.cards[1].ability.tyg_combo
    assert((combo and combo.key)==expected.combo_key,'card composite changed on reload')
    assert((r.pattern.combo and r.pattern.combo.key)==expected.combo_key,'run composite changed on reload')
   end
  assert(reclassifications==0,'saved pattern was reclassified on resume')
  qa.resume_classify_calls=reclassifications
  if expected.bonus then assert(G.jokers.cards[1]:calculate_dollar_bonus()==expected.bonus,'resumed combo bonus lost')end
  if expected.dollars then assert(G.GAME.dollars==expected.dollars,'saved native cashout money changed')end
  assert(#G.hand.cards==expected.hand_count and #G.playing_cards==expected.playing_count,'playing cards lost or duplicated on reload')
  assert(#G.consumeables.cards==expected.consumeable_count and #r.pending_items==0,'fortune duplicated on reload')
  seen=seen or love.timer.getTime()
  if love.timer.getTime()-seen>2 and not qa.capture_requested then
   qa.capture_requested=true;note('reload_verified',expected)
   capture('runtime-qa-reloaded.png',finish)
  end
 end
end
