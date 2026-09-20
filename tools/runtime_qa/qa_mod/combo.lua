-- Real-calendar composite witness; all actions use the live engine's callbacks.
function TYG_QA_SCENARIOS.combo(qa,note,capture,finish)
 local step='start';local at=love.timer.getTime();local C,starter,before_cash,expected_cash
 local cash_bonus_rows=0;local chosen,estimated,before_chips,before_hands;local hands_played=0
 local function advance(next_step)step=next_step;at=love.timer.getTime();note('combo_'..step)end
 local function ready()return C and C.idle()and not G.CONTROLLER.lock_input end
 local function type_field(id,text)
  G.FUNCS.select_text_input(assert(G.OVERLAY_MENU:get_UIE_by_ID(id),'missing native input '..id))
  for i=1,#text do G.FUNCS.text_input_key{key=text:sub(i,i)}end
  G.FUNCS.text_input_key{key='return'}
 end
 local function best_visible_hand()
  -- Evaluate only the current visible hand. No deck peeking, synthetic cards,
  -- score mutation or state mutation: select the best normal hand for this
  -- fixture's one shishen Joker (+4 and +1 per non-face scoring card).
  local best,best_score={},-1
  local candidate={}
  local function inspect()
   local key,_,_,scoring=G.FUNCS.get_poker_hand_info(candidate)
   local hand=assert(G.GAME.hands[key]);local chips,mult=hand.chips,hand.mult+4
   for _,card in ipairs(scoring)do
    chips=chips+card:get_chip_bonus()
    if not card:is_face()then mult=mult+1 end
   end
   local score=chips*mult
   if score>best_score then best_score=score;best={};for i,card in ipairs(candidate)do best[i]=card end end
  end
  local function enumerate(start)
   if #candidate>0 then inspect()end
   if #candidate==5 then return end
   for i=start,#G.hand.cards do candidate[#candidate+1]=G.hand.cards[i];enumerate(i+1);candidate[#candidate]=nil end
  end
  enumerate(1);return best,best_score
 end
 local original_row=add_round_eval_row
 add_round_eval_row=function(args)
  if starter and args.card==starter and args.bonus then
   assert(args.dollars==1,'native cashout did not evaluate exactly the composite dollar')
   cash_bonus_rows=cash_bonus_rows+1
   note('combo_native_cashout_row',{dollars=args.dollars,key=starter.config.center.key})
  end
  return original_row(args)
 end
 return function()
  assert(love.timer.getTime()-at<80,'composite stage timeout: '..step)
  if G.STATE==G.STATES.GAME_OVER then error('native composite fixture lost; no result is fabricated')end
  if step=='start'then
   local mod=assert(SMODS.Mods.ten_years_nine_grid);C=assert(mod.tyg_cycles)
   G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'},stake=1,seed='TYGCOMBO'})
   advance('entry')
  elseif step=='entry'and G.OVERLAY_MENU then
   G.FUNCS.tyg_choose_birth();advance('birthday')
  elseif step=='birthday'and G.OVERLAY_MENU then
   type_field('tyg_birth_date','19010908');type_field('tyg_birth_time','1800')
   G.FUNCS.tyg_birth_gender{to_key=2};G.FUNCS.tyg_birth_match()
   local p=assert(SMODS.Mods.ten_years_nine_grid.tyg_birth.current_profile(),'real composite fixture did not match')
   assert(p.pattern.key=='shishen'and p.pattern.combo and p.pattern.combo.key=='shishengcai',
    'real-calendar composite identity changed')
   assert(#p.pattern.combo.trace>=3 and #p.pattern.reasons>0,'composite has no inspectable basis')
   qa.fixture={date='1901-09-08',time='18:00',gender=1,pattern=p.pattern.key,
    combo=p.pattern.combo.key,chart=p.chart,combo_trace=p.pattern.combo.trace}
   advance('preview')
  elseif step=='preview'and love.timer.getTime()-at>2 then
   capture('runtime-qa-combo-preview.png',function()G.FUNCS.tyg_birth_start();advance('initial')end)
   advance('capture_preview')
  elseif step=='initial'and ready()and C.active().natal_given then
   local r=C.active();starter=assert(G.jokers.cards[1])
   assert(#G.jokers.cards==1 and r.version==2 and r.natal_key=='j_tyg_mp_shishen','composite created wrong/multiple starters')
   assert(starter.config.center.key==r.natal_key and starter.ability.tyg_pattern_key=='shishen','actual card identity mismatch')
   assert(r.pattern.combo.key=='shishengcai'and starter.ability.tyg_combo.key=='shishengcai','composite not installed on actual card')
   assert(starter.ability.tyg_combo~=r.pattern.combo,'card and run composite must be independent snapshots')
   assert(starter:calculate_dollar_bonus()==1,'actual native Card bonus callback does not pay $1')
   note('combo_card_verified',{pattern=r.pattern.key,combo=starter.ability.tyg_combo.key,bonus=1})
   advance('initial_settle')
  elseif step=='initial_settle'and ready()and love.timer.getTime()-at>2 then
   capture('runtime-qa-combo-initial.png',function()
    G.FUNCS.select_blind(assert(G.blind_select_opts.small:get_UIE_by_ID('select_blind_button')))
    advance('play')
   end)
   advance('capture_initial')
  elseif step=='play'and G.STATE==G.STATES.SELECTING_HAND and ready()then
   assert(G.GAME.current_round.hands_left>0,'no native hands remain')
   qa.blind=qa.blind or{chips=G.GAME.blind.chips,text=G.GAME.blind.chip_text}
   chosen,estimated=best_visible_hand()
   assert(#chosen>0 and estimated>0,'no normal scoring hand found')
   before_chips=G.GAME.chips;before_hands=G.GAME.current_round.hands_left
   G.hand:unhighlight_all();for _,card in ipairs(chosen)do G.hand:add_to_highlighted(card)end
   note('combo_native_play',{cards=#chosen,estimated=estimated,chips_before=before_chips,hands_before=before_hands})
   G.FUNCS.play_cards_from_highlighted();hands_played=hands_played+1;advance('score')
  elseif step=='score'then
   if G.STATE==G.STATES.SELECTING_HAND and ready()then
    assert(G.GAME.current_round.hands_left==before_hands-1,'native hand count mismatch')
    assert(G.GAME.chips-before_chips==estimated,'normal-card prediction differs from actual native score')
    advance('play')
   elseif G.STATE==G.STATES.ROUND_EVAL and G.round_eval and cash_bonus_rows>0 then
    assert(qa.blind.chips>0 and G.GAME.chips>=qa.blind.chips,'cashout reached without a real blind win')
    assert(cash_bonus_rows==1,'composite cashout bonus duplicated')
    advance('cashout')
   end
  elseif step=='cashout'and G.round_eval and love.timer.getTime()-at>2 then
   -- Native add_round_eval_row creates the cashout button in a separate UIBox
   -- aligned to round_eval, not as a child inside round_eval.UIRoot.
   local cash_button
   for _,box in pairs(G.I.UIBOX)do
    cash_button=box:get_UIE_by_ID('cash_out_button');if cash_button then break end
   end
   if not cash_button then return end
   before_cash=G.GAME.dollars;expected_cash=G.GAME.current_round.dollars
   assert(expected_cash and expected_cash>=4,'native cashout must include blind $3 plus composite $1')
   note('combo_cashout_verified',{bonus_rows=cash_bonus_rows,total=expected_cash,hands_played=hands_played,
    score=G.GAME.chips,threshold=qa.blind.chips})
   capture('runtime-qa-combo-cashout.png',function()G.FUNCS.cash_out(cash_button);advance('shop')end)
   advance('capture_cashout')
  elseif step=='shop'and G.STATE==G.STATES.SHOP and ready()then
   assert(G.GAME.dollars==before_cash+expected_cash,'native cashout money did not reach the run')
   qa.cashout={bonus=1,total=expected_cash,before=before_cash,after=G.GAME.dollars,hands_played=hands_played}
   save_run();advance('save')
  elseif step=='save'and ready()then
   local raw=get_compressed(G.SETTINGS.profile..'/save.jkr');if not raw then return end
   local saved=STR_UNPACK(raw);local r=saved.GAME and saved.GAME.tyg_cycle
   if not r or saved.STATE~=G.STATES.SHOP or saved.GAME.dollars~=G.GAME.dollars then return end
   assert(r.pattern.combo and r.pattern.combo.key=='shishengcai','saved run lost its composite')
   qa.expected_reload={ante=1,natal_key=r.natal_key,pattern_key='shishen',combo_key='shishengcai',
    hand_count=#G.hand.cards,playing_count=#G.playing_cards,consumeable_count=#G.consumeables.cards,
    claim1_used=false,dollars=G.GAME.dollars,bonus=1}
   love.filesystem.write('runtime-qa-reload-expected.json',JSON.encode(qa.expected_reload))
   capture('runtime-qa-combo-saved.png',finish);advance('capture_save')
  end
 end
end
