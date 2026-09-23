-- Owned QA process only. Drives real native UI callbacks; no production mocks.
local function preset_scenario(rank)
 return function(qa,note,capture,finish,native_blind_amount)
  local step='start';local at=love.timer.getTime();local C,I,P;local preview=1
  local classifications=0;local hand_before,playing_before;local drained,legendary_key,high_card_level
  local function advance(s)step=s;at=love.timer.getTime();note('preset_'..s)end
  local function ready()return C and C.idle()and not G.CONTROLLER.lock_input end
  local function button(node,key)
   if node.config and node.config.button==key then return node end
   for _,child in pairs(node.children or{})do local found=button(child,key);if found then return found end end
  end
  local function click(key)
   local event=assert(G.OVERLAY_MENU and button(G.OVERLAY_MENU.UIRoot,key),'visible button missing: '..key)
   G.FUNCS[key](event)
  end
  local function fortune(claim)
   for _,card in ipairs(G.consumeables.cards)do if card.ability.tyg_claim_id==claim then return card end end
  end
  return function()
   assert(love.timer.getTime()-at<60,'preset stage timeout: '..step)
   if step=='start'then
    local mod=assert(SMODS.Mods.ten_years_nine_grid);C=mod.tyg_cycles;I=mod.tyg_birth;P=mod.tyg_presets
    assert(P and #P.catalog==9,'nine preset API absent')
    local original=mod.tyg_patterns.classify
    mod.tyg_patterns.classify=function(...)classifications=classifications+1;return original(...)end
    G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'},stake=1,seed='TYGPRESET'})
    advance('entry')
   elseif step=='entry'and G.OVERLAY_MENU and love.timer.getTime()-at>.4 then
    assert(button(G.OVERLAY_MENU.UIRoot,'tyg_choose_birth'),'birthday route not visible')
    assert(not I.current_profile(),'mode selection already created a profile')
    capture('runtime-qa-entry-modes.png',function()click('tyg_choose_preset');advance('grid')end)
    advance('capture_entry')
   elseif step=='grid'and love.timer.getTime()-at>.4 then
    for i=1,9 do assert(button(G.OVERLAY_MENU.UIRoot,'tyg_preset_pick_'..i),'missing grid choice '..i)end
    capture('runtime-qa-preset-grid.png',function()advance('choose')end);advance('capture_grid')
   elseif step=='choose'then
    click('tyg_preset_pick_'..preview);advance('preview')
   elseif step=='preview'and love.timer.getTime()-at>.35 then
    local p=assert(I.current_profile());local r=C.prepare_run(p);local phase=C.phase(r,1)
    assert(p.mode=='preset'and r.mode=='preset'and r.preset_id==P.catalog[preview].id,'preset identity was not copied')
    assert(phase.rank==preview and phase.target_multiplier==1+(preview-1)/8,'wrong preview target')
    assert(r.natal_key=='j_tyg_mp_changgui'and not r.pattern.combo,'preset has wrong starter')
    for ante=1,9 do assert(C.phase(r,ante).rank==preview,'preset does not stay fixed across stages')end
    assert(classifications==0,'preset selection incorrectly called the classifier')
    note('preset_preview_verified',{rank=preview,id=p.preset_id,target=phase.target_multiplier,reward=phase.reward_text})
    capture('runtime-qa-preset-preview-'..preview..'.png',function()
     click('tyg_entry_modes');click('tyg_choose_preset')
     if preview<9 then preview=preview+1;advance('choose')
     else click('tyg_preset_pick_'..rank);advance('confirm')end
    end)
    advance('capture_preview')
   elseif step=='confirm'and love.timer.getTime()-at>.4 then
    click('tyg_preset_start');advance('initial')
   elseif step=='initial'and ready()and C.active()and C.active().natal_given and fortune('ante_1')then
    local r=C.active()
    assert(r.mode=='preset'and r.preset_id==P.catalog[rank].id,'actual run lost selected mode')
    assert(#G.jokers.cards==1 and G.jokers.cards[1].config.center.key=='j_tyg_mp_changgui','wrong actual starter')
    assert(not G.jokers.cards[1].ability.tyg_combo,'preset unexpectedly attached a composite')
    assert(fortune('ante_1').config.center.key=='c_tyg_fortune_'..rank,'wrong initial fortune')
    assert(G.GAME.win_ante==8 and r.current_ante==1,'wrong starting stage/win condition')
    assert(classifications==0,'preset launch used birthday classifier')
    advance('initial_settle')
   elseif step=='initial_settle'and ready()and love.timer.getTime()-at>1 then
    capture('runtime-qa-preset-initial.png',function()
     G.FUNCS.select_blind(assert(G.blind_select_opts.small:get_UIE_by_ID('select_blind_button')))
     advance('hand')
    end);advance('capture_initial')
   elseif step=='hand'and ready()and G.STATE==G.STATES.SELECTING_HAND then
    local expected=tonumber(string.format('%.0f',native_blind_amount(1)*(1+(rank-1)/8)))
    assert(G.GAME.blind.chips==expected,'actual preset blind threshold mismatch')
    assert(tonumber((G.GAME.blind.chip_text:gsub(',','')))==expected,'displayed threshold mismatch')
    qa.preset={rank=rank,id=C.active().preset_id,threshold=expected,classifier_calls=classifications}
    hand_before=#G.hand.cards;playing_before=#G.playing_cards
    local ticket=assert(fortune('ante_1'));assert(ticket:can_use_consumeable(),'preset fortune cannot be used')
    G.FUNCS.use_card{config={ref_table=ticket}};advance('reward')
   elseif step=='reward'and ready()and #C.active().pending_effects==0 then
    drained=drained or love.timer.getTime();if love.timer.getTime()-drained<1.5 then return end
    assert(not G.booster_pack and G.STATE==G.STATES.SELECTING_HAND,'preset reward opened wrong UI')
    if rank==1 then
     assert(#G.consumeables.cards==1 and G.consumeables.cards[1].config.center.key=='c_soul','best preset must give original Soul')
    else
     assert(#G.consumeables.cards==1 and G.consumeables.cards[1].config.center.key=='c_pluto','last preset must give Pluto')
    end
    assert(#G.hand.cards==hand_before and #G.playing_cards==playing_before,'consumable delivery must not alter playing cards')
    note('preset_reward_verified',qa.preset)
    capture('runtime-qa-preset-reward.png',function()
     local card=G.consumeables.cards[1];assert(card:can_use_consumeable(),'native Soul/Pluto not usable')
     high_card_level=G.GAME.hands['High Card'].level
     G.FUNCS.use_card{config={ref_table=card}};advance(rank==1 and'soul'or'planet')
    end);advance('capture_reward')
   elseif step=='soul'and ready()then
    assert(#G.consumeables.cards==0 and #G.jokers.cards==2,'Soul did not consume itself and create exactly1Joker')
    local legendary=G.jokers.cards[2]
    assert(legendary.config.center.rarity==4,'Soul generated a non-Legendary Joker')
    legendary_key=legendary.config.center.key;qa.soul_legendary=legendary_key
    note('original_soul_created_legendary',{key=legendary_key,rarity=4})
    capture('runtime-qa-soul-legendary.png',function()ease_ante(1);advance('ante')end);advance('capture_soul')
   elseif step=='planet'and ready()then
    assert(#G.consumeables.cards==0 and G.GAME.hands['High Card'].level==high_card_level+1,'Pluto did not upgrade High Card')
    high_card_level=G.GAME.hands['High Card'].level;qa.pluto_level=high_card_level
    note('original_pluto_used',{high_card_level=high_card_level})
    ease_ante(1);advance('ante')
   elseif step=='ante'and ready()and C.active().current_ante==2 then
    assert(C.phase(C.active(),2).rank==rank,'next preset stage changed difficulty')
    assert(C.active().seen_antes.ante_2,'next stage fortune was not tracked')
    if not fortune('ante_2')then
     assert(rank==1 and #C.active().pending_items==1,'next stage ticket not queued correctly')
     G.FUNCS.sell_card{config={ref_table=G.consumeables.cards[1]}}
    end
    advance('save_ready')
   elseif step=='save_ready'and ready()and fortune('ante_2')then
    assert(fortune('ante_2').config.center.key=='c_tyg_fortune_'..rank,'next stage fortune changed rank')
    save_run();advance('save')
   elseif step=='save'and ready()and love.timer.getTime()-at>.5 then
    local raw=get_compressed(G.SETTINGS.profile..'/save.jkr');if not raw then return end
    local saved=STR_UNPACK(raw);local r=saved and saved.GAME and saved.GAME.tyg_cycle
    if not r or r.current_ante~=2 or #saved.cardAreas.hand.cards~=#G.hand.cards then return end
    -- The native worker may still expose the older ante2/full-inventory save.
    -- Its ante and hand count are identical, so also require the delivered
    -- ticket and emptied queue to be on disk before ending this QA process.
    if #r.pending_items~=0 or #r.pending_effects~=0 then return end
    local stored=saved.cardAreas.consumeables.cards
    if #stored~=#G.consumeables.cards then return end
    for i,card in ipairs(G.consumeables.cards)do
     if not stored[i].save_fields or stored[i].save_fields.center~=card.config.center.key then return end
    end
    assert(r.mode=='preset'and r.preset_id==P.catalog[rank].id,'serialized preset missing')
    qa.expected_reload={ante=2,natal_key=r.natal_key,pattern_key='changgui',mode='preset',
     preset_id=r.preset_id,rank=rank,hand_count=#G.hand.cards,playing_count=#G.playing_cards,
     consumeable_count=#G.consumeables.cards,claim1_used=true,reward_version=2,
     joker_count=#G.jokers.cards,legendary_key=legendary_key,high_card_level=rank==9 and high_card_level or nil}
    love.filesystem.write('runtime-qa-reload-expected.json',JSON.encode(qa.expected_reload))
    capture('runtime-qa-preset-saved.png',finish);advance('capture_save')
   end
  end
 end
end
TYG_QA_SCENARIOS.preset1=preset_scenario(1)
TYG_QA_SCENARIOS.preset9=preset_scenario(9)

-- Continue a recorded0.6synthetic save, then actually use its old rank9ticket.
-- This validates the old promise, not just that its snapshot loads.
function TYG_QA_SCENARIOS.legacy9(qa,note,capture,finish)
 local loaded=false;local requested=false;local before_hand,before_playing;local done=false
 local resume=TYG_QA_SCENARIOS.reload(qa,note,capture,function()loaded=true end)
 return function()
  if not loaded then resume();return end
  local C=SMODS.Mods.ten_years_nine_grid.tyg_cycles
  if done or not C.idle()then return end
  if not requested then
   local r=C.active();assert(not r.reward_version or r.reward_version==1,'old save unexpectedly adopted new table')
   local ticket
   for _,card in ipairs(G.consumeables.cards)do if card.config.center.key=='c_tyg_fortune_9'then ticket=card end end
   assert(ticket and ticket:can_use_consumeable(),'old rank9ticket missing/unusable')
   before_hand=#G.hand.cards;before_playing=#G.playing_cards;requested=true
   G.FUNCS.use_card{config={ref_table=ticket}};return
  end
  if #C.active().pending_effects>0 then return end
  assert(#G.hand.cards==before_hand+1 and #G.playing_cards==before_playing+1,'old rank9promise changed instead of adding stone')
  assert(#G.consumeables.cards==0,'old rank9became a new Pluto consumable')
  local added=G.playing_cards[#G.playing_cards];assert(added.config.center.key=='m_stone','old enhancement not preserved')
  note('legacy_rank9_stone_preserved',{playing=#G.playing_cards,hand=#G.hand.cards,enhancement=added.config.center.key})
  done=true;capture('runtime-qa-legacy-reward.png',finish)
 end
end
