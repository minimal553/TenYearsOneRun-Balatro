-- UI/start lifecycle contract tests; does not launch or operate a game window.
local count=0
local function ok(v,m)count=count+1;assert(v,m)end
local function eq(a,b,m)ok(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b))end
local loader=loadfile(TEST_ROOT..'/birth_ui.lua')
ok(type(loader)=='function','native birthday wizard module must exist')
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local inputs,starts,quick_starts,deleted,calcs={},0,0,0,0
local last_args,approved,deferred
G={FUNCS={},GAME={selected_back={effect={center={key='b_tyg_mingju'}},name='b_tyg_mingju'}},
 SETTINGS={profile=1,paused=false},PROFILES={{last_choices={deck_choice='b_tyg_mingju',stake_choice='stake_white',seed='QUICK',enable_seed=true}}},
 P_CENTERS={b_tyg_mingju={key='b_tyg_mingju',name='b_tyg_mingju'}},
 C={BLACK={},BLUE={},GREEN={},RED={},WHITE={},UI={TEXT_LIGHT={}}},UIT={R=1,C=2,T=3,O=4},
 CONTROLLER={locks={}},OVERLAY_MENU=nil}
local I
G.FUNCS.start_run=function(e,args)
 starts=starts+1;last_args=args
 if not deferred and not args.savetext and(not args.deck_choice or args.deck_choice.name=='b_tyg_mingju')then approved=I.consume_profile()end
end
G.FUNCS.overlay_menu=function(args)G.OVERLAY_MENU={definition=args.definition}end
G.FUNCS.exit_overlay_menu=function()
 G.OVERLAY_MENU=nil;G.SETTINGS.paused=false;G.CONTROLLER.locks.frame=true
end
local streak_resets=0
G.FUNCS.start_setup_run=function(e)
 if G.OVERLAY_MENU then G.FUNCS.exit_overlay_menu()end
 if G.SETTINGS.current_setup=='New Run'then
  streak_resets=streak_resets+1
  G.FUNCS.start_run(e,{stake=G.forced_stake,seed=G.forced_seed})
 elseif G.SETTINGS.current_setup=='Continue'then
  G.FUNCS.start_run(nil,{savetext=G.SAVED_GAME})
 end
end
Controller={key_hold_update=function(self,key,dt)
 if self.locks.frame or self.frame_buttonpress or(self.locked and not G.SETTINGS.paused)then return end
 if key=='r'and self.held_key_times[key]and self.held_key_times[key]>.7 and not G.SETTINGS.paused then
  streak_resets=streak_resets+1
  self.held_key_times[key]=nil
  G.SETTINGS.current_setup='New Run'
  G.GAME.viewed_back=nil
  G.FUNCS.start_setup_run()
 end
end}
G.FUNCS.text_input_key=function(args)
 local hook=G.CONTROLLER.text_input_hook
 if not hook then return end
 if args.key=='return'then G.CONTROLLER.text_input_hook=nil;return end
 if args.key=='0'then args.key='o'end -- native seed-oriented behavior
 local t=hook.config.ref_table.text;t.ref_table[t.ref_value]=t.ref_table[t.ref_value]..args.key
end
function create_text_input(args)
 inputs[args.id]=args
 args.text={ref_table=args.ref_table,ref_value=args.ref_value,current_position=#args.ref_table[args.ref_value]}
 return{input=args}
end
function create_option_cycle(args)return{cycle=args}end
function create_UIBox_generic_options(args)return args end
function UIBox_button(args)return args end
function DynaText(args)return args end
function TRANSPOSE_TEXT_INPUT(delta)
 local t=G.CONTROLLER.text_input_hook.config.ref_table.text
 t.current_position=math.max(0,math.min(#t.ref_table[t.ref_value],t.current_position+(delta or 0)))
end
function MODIFY_TEXT_INPUT(args)
 local t=args.text_table;local value=t.ref_table[t.ref_value]
 t.ref_table[t.ref_value]=value:sub(1,args.pos-1)..args.letter..value:sub(args.pos)
end
SMODS={RunSelect={Setup={choices={deck_choice='b_tyg_mingju',stake_choice='stake_red',seed='NEWSEED',enable_seed=true}},Functions={}}}
SMODS.RunSelect.Functions.start_run=function(quick,skip)
 quick_starts=quick_starts+1
 local access=quick and G.PROFILES[1].last_choices or SMODS.RunSelect.Setup.choices
 last_args=R.copy(access)
 if skip then deleted=deleted+1;approved=I.consume_profile()
 else G.FUNCS.start_run(nil,{deck_choice={name=access.deck_choice},stake_choice=access.stake_choice,seed=access.seed})end
end
local matched_input
local function calc(data)
 calcs=calcs+1
 matched_input=data
 if data.date~='2000-02-29'or(data.time~='00:00'and data.time~='07:30')or data.gender~=1 then return nil,'输入无效' end
 local p=R.demo_profile();p.mode='ingame';p.decades={
  {index=1,gan_zhi='甲子',start_date='2004-01-01',end_date='2014-01-01',luck_tier=3},
  {index=2,gan_zhi='乙丑',start_date='2014-01-01',end_date='2024-01-01',luck_tier=1}}
 return p
end
local M=assert(loadfile(TEST_ROOT..'/chart_patterns.lua'))()
local C=assert(loadfile(TEST_ROOT..'/cycles.lua'))()({},R,M)
-- Keep setup usable before the new factory exists so mode flow has its own RED.
local preset_loader=loadfile(TEST_ROOT..'/presets.lua')
local P=preset_loader and preset_loader()(R,M,C)
I=loader()({},R,calc,C,P)
I.install_hooks()
local function overlay_buttons()
 local buttons={}
 local function visit(node)
  if type(node)~='table'then return end
  if node.button then buttons[node.button]=node end
  for _,child in pairs(node)do if type(child)=='table'then visit(child)end end
 end
 visit(G.OVERLAY_MENU);return buttons
end
local function choose_birth()G.FUNCS.tyg_choose_birth()end
local function fill()
 choose_birth()
 inputs.tyg_birth_date.ref_table[inputs.tyg_birth_date.ref_value]='20000229'
 inputs.tyg_birth_time.ref_table[inputs.tyg_birth_time.ref_value]='0000'
 G.FUNCS.tyg_birth_gender({to_key=2})
end
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'},stake=3,seed='ABC'})
eq(starts,0,'opening wizard must not start or delete run')
ok(G.OVERLAY_MENU,'birthday overlay shown')
local mode_buttons=overlay_buttons()
ok(mode_buttons.tyg_choose_preset and mode_buttons.tyg_choose_birth,'new run first offers both entry modes')
ok(not inputs.tyg_birth_date,'mode page does not create or retain birthday inputs')
choose_birth()
eq(inputs.tyg_birth_date.ref_table[inputs.tyg_birth_date.ref_value],'','fresh birthday input')
G.FUNCS.tyg_birth_match()
eq(calcs,0,'empty inputs rejected before calculating')
eq(starts,0,'empty inputs do not start game')
-- Literal zero is supported only in the birthday input widgets.
local date_args=inputs.tyg_birth_date
G.CONTROLLER.text_input_id='tyg_birth_date';G.CONTROLLER.text_input_hook={config={ref_table=date_args}}
G.FUNCS.text_input_key({key='0'})
eq(date_args.ref_table[date_args.ref_value],'0','birthday zero remains a digit')
local seed={value=''}
G.CONTROLLER.text_input_id='seed';G.CONTROLLER.text_input_hook={config={ref_table={text={ref_table=seed,ref_value='value'}}}}
G.FUNCS.text_input_key({key='0'});eq(seed.value,'o','other native input behavior unchanged')
G.CONTROLLER.text_input_hook=nil
fill();G.FUNCS.tyg_birth_match()
eq(calcs,1,'valid date matched in-game')
eq(starts,0,'matching only previews before confirmation')
G.FUNCS.tyg_birth_decade({to_key=2})
G.FUNCS.tyg_birth_start()
eq(starts,1,'confirmed native run starts once')
eq(last_args.seed,'ABC','seed preserved');eq(last_args.stake,3,'stake preserved')
eq(approved.selected_decade,1,'previewing later decade never skips initial natal phase')
ok(not I.consume_profile(),'approved profile is one-shot')
G.FUNCS.tyg_birth_start();eq(starts,1,'double click cannot launch twice')
-- New run always prompts; cancel and ESC clear all pending approval.
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
choose_birth()
eq(inputs.tyg_birth_date.ref_table[inputs.tyg_birth_date.ref_value],'','next new run asks again')
G.FUNCS.tyg_birth_cancel();eq(starts,1,'cancel preserves current run')
ok(not G.OVERLAY_MENU and not I.consume_profile(),'cancel leaves no approval')
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
G.CONTROLLER.text_input_hook=nil -- native first ESC defocuses; second calls exit.
G.FUNCS.exit_overlay_menu()
G.FUNCS.tyg_birth_start();eq(starts,1,'ESC cannot leave a launchable session')
-- Non-own decks and continue saves bypass birthday entirely.
G.FUNCS.start_run(nil,{deck_choice={name='Red Deck'}});eq(starts,2,'other deck bypass')
G.FUNCS.start_run(nil,{savetext={BACK={name='b_tyg_mingju'}}});eq(starts,3,'saved run bypass')
-- Quick restart may directly delete_run; gate must be before that function.
SMODS.RunSelect.Functions.start_run(true,true)
eq(deleted,0,'R/quick restart cannot delete before birthday confirmation')
G.PROFILES[1].last_choices.seed='MUTATED'
fill();G.FUNCS.tyg_birth_match();G.FUNCS.tyg_birth_start()
eq(deleted,1,'quick restart forwarded once after confirmation')
eq(last_args.seed,'QUICK','quick-start seed preserved')
-- Normal SMODS path must not open a second birthday gate downstream.
SMODS.RunSelect.Functions.start_run(false,false)
SMODS.RunSelect.Setup.choices.seed='MUTATED'
fill();G.FUNCS.tyg_birth_match();G.FUNCS.tyg_birth_start()
eq(starts,4,'nested normal start goes through exactly once')
eq(last_args.seed,'NEWSEED','selected normal seed preserved')
ok(not G.OVERLAY_MENU,'confirmation closes birthday overlay')
-- Native wipe starts asynchronously; stale UI callbacks must not clear approval.
deferred=true
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'},seed='ASYNC'})
fill();G.FUNCS.tyg_birth_match();G.FUNCS.tyg_birth_start()
G.FUNCS.tyg_birth_cancel()
approved=I.consume_profile()
ok(approved and approved.chart,'late cancel cannot destroy approved deferred run')
-- Invalid input never starts and never silently supplies a sample profile.
deferred=false
local before_starts,before_calcs=starts,calcs
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
choose_birth()
inputs.tyg_birth_date.ref_table.date='20000229'
inputs.tyg_birth_time.ref_table.time='0000'
G.FUNCS.tyg_birth_match()
eq(calcs,before_calcs,'gender selection is required before matching')
G.FUNCS.tyg_birth_gender({to_key=2})
inputs.tyg_birth_date.ref_table.date='99990101'
G.FUNCS.tyg_birth_match()
eq(calcs,before_calcs,'future date rejected before matching')
inputs.tyg_birth_date.ref_table.date='20000230'
G.FUNCS.tyg_birth_match()
eq(calcs,before_calcs+1,'calculator receives syntactically valid but invalid date')
G.FUNCS.tyg_birth_start()
eq(starts,before_starts,'invalid calculation cannot start a sample run')
ok(not I.current_profile(),'invalid input has no matched profile')
G.FUNCS.tyg_birth_cancel()
-- Upstream start_setup_run and held-R clear streak before calling start_run.
G.SETTINGS.current_setup='New Run'
G.forced_stake=5;G.forced_seed='SETUP'
local setup_starts=starts
G.FUNCS.start_setup_run()
eq(streak_resets,0,'setup gate precedes native streak reset')
G.FUNCS.tyg_birth_cancel()
eq(starts,setup_starts,'cancel setup has no launch side effect')
G.FUNCS.start_setup_run()
fill();G.FUNCS.tyg_birth_match();G.FUNCS.tyg_birth_start()
eq(streak_resets,1,'confirmed setup preserves native streak semantics')
eq(starts,setup_starts+1,'confirmed setup launches once')
eq(last_args.seed,'SETUP','upstream setup seed preserved')
G.STAGES={RUN=2};G.STAGE=2
G.CONTROLLER.locks.frame=nil
G.CONTROLLER.held_key_times={r=.8}
Controller.key_hold_update(G.CONTROLLER,'r',.016)
eq(streak_resets,1,'held-R gate precedes native streak reset')
G.FUNCS.tyg_birth_cancel()
eq(streak_resets,1,'cancel held-R preserves streak')
G.CONTROLLER.locks.frame=nil
G.CONTROLLER.held_key_times.r=.8
Controller.key_hold_update(G.CONTROLLER,'r',.016)
fill();G.FUNCS.tyg_birth_match();G.FUNCS.tyg_birth_start()
I.update()
eq(streak_resets,1,'confirmed held-R waits for native overlay frame unlock')
G.CONTROLLER.locks.frame=nil;G.CONTROLLER.frame_buttonpress=false
I.update()
eq(streak_resets,3,'confirmed held-R retains original upstream callbacks')
eq(starts,setup_starts+2,'held-R confirmation starts once')
-- Regression: shorthand 730 must be treated as 07:30, not a silent dead end.
for _,time in ipairs({'730','0730','7:30','07:30'})do
 G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
 fill();inputs.tyg_birth_time.ref_table.time=time
 G.FUNCS.tyg_birth_match()
 ok(I.current_profile(),'accepted common time spelling '..time)
 eq(matched_input.time,'07:30','normalizes time before calling calendar')
 G.FUNCS.tyg_birth_cancel()
end
for _,time in ipairs({'24:00','2360','7:3','7::30','-730','73',''})do
 local calls_before=calcs
 G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
 fill();inputs.tyg_birth_time.ref_table.time=time
 G.FUNCS.tyg_birth_match()
 ok(not I.current_profile(),'reject invalid or ambiguous time '..time)
 eq(calcs,calls_before,'bad time rejected before calendar')
 G.FUNCS.tyg_birth_cancel()
end
-- Both previews can return to mode selection; old callbacks cannot cross modes.
local prior_starts,prior_calcs,prior_streak=starts,calcs,streak_resets
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'},stake=8,seed='PRESET'})
G.FUNCS.tyg_choose_preset()
local grid_buttons=overlay_buttons();local choices=0
for key in pairs(grid_buttons)do if key:match('^tyg_preset_pick_%d$')then choices=choices+1 end end
eq(choices,9,'grid exposes all nine challenges')
G.FUNCS.tyg_preset_pick_5()
local preset=I.current_profile();ok(preset and preset.mode=='preset','selection previews preset')
eq(preset.natal_tier,2,'middle grid natal');eq(preset.decades[1].luck_tier,2,'middle grid luck')
eq(starts,prior_starts,'selection does not launch');eq(calcs,prior_calcs,'preset does not call calendar')
ok(overlay_buttons().tyg_entry_modes,'preset preview can return to mode page')
G.FUNCS.tyg_birth_start();eq(starts,prior_starts,'stale birth confirm cannot launch preset')
G.FUNCS.tyg_birth_match();eq(calcs,prior_calcs,'stale birth match cannot calculate preset')
G.FUNCS.tyg_entry_modes();ok(not I.current_profile(),'return to modes clears preset preview')
choose_birth();fill();G.FUNCS.tyg_birth_match()
ok(overlay_buttons().tyg_entry_modes,'birthday preview can return to modes')
G.FUNCS.tyg_preset_start();eq(starts,prior_starts,'stale preset confirm cannot launch birthday')
G.FUNCS.tyg_preset_pick_9();eq(I.current_profile().mode,'ingame','stale grid selection cannot replace birth preview')
G.FUNCS.tyg_entry_modes();choose_birth()
G.CONTROLLER.text_input_id='tyg_birth_date';G.CONTROLLER.text_input_hook={config={ref_table=inputs.tyg_birth_date}}
G.CONTROLLER.screen_keyboard={}
G.FUNCS.tyg_entry_modes()
ok(not G.CONTROLLER.text_input_hook and not G.CONTROLLER.text_input_id and not G.CONTROLLER.screen_keyboard,'mode switch releases native input')
G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_9()
G.FUNCS.tyg_preset_start();G.FUNCS.tyg_preset_start()
eq(starts,prior_starts+1,'preset confirmation launches exactly once');eq(last_args.seed,'PRESET','preset seed preserved')
eq(last_args.stake,8,'preset stake preserved');eq(approved.mode,'preset','preset approved for real run')
eq(approved.preset_id,P.make(9).preset_id,'approved selection is exact');eq(streak_resets,prior_streak,'direct preview switching has no streak side effects')
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_1();G.FUNCS.exit_overlay_menu()
G.FUNCS.tyg_preset_start();eq(starts,prior_starts+1,'ESC cancels preset without launch')
ok(not I.consume_profile(),'ESC clears preset approval')
-- Native UIElements retain their original UIBox; a delayed click from that box
-- must never confirm or cancel a later preview, even if its mode is the same.
G.FUNCS.start_run(nil,{deck_choice={name='b_tyg_mingju'}})
G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_1()
local stale_event={UIBox=G.OVERLAY_MENU}
G.FUNCS.tyg_entry_modes();G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_9()
local fresh_profile=I.current_profile();local fresh_overlay=G.OVERLAY_MENU
G.FUNCS.tyg_preset_start(stale_event)
eq(starts,prior_starts+1,'old native preview event cannot start a newer selection')
G.FUNCS.tyg_birth_cancel(stale_event)
eq(I.current_profile(),fresh_profile,'old cancel event cannot clear current preview')
G.FUNCS.tyg_entry_modes(stale_event)
eq(G.OVERLAY_MENU,fresh_overlay,'old mode navigation cannot clear current preview')
G.FUNCS.tyg_preset_edit(stale_event)
eq(I.current_profile(),fresh_profile,'old edit event cannot clear current preset')
G.FUNCS.tyg_birth_cancel()
-- Fixed-challenge cancellation also gates upstream mutation on setup/held-R/Quick.
local before_deleted,before_streak,before_direct=deleted,streak_resets,starts
G.SETTINGS.current_setup='New Run';G.FUNCS.start_setup_run()
G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_1();G.FUNCS.tyg_birth_cancel()
eq(streak_resets,before_streak,'preset setup cancel preserves streak');eq(starts,before_direct,'preset setup cancel preserves run')
G.CONTROLLER.locks.frame=nil;G.CONTROLLER.held_key_times.r=.8
Controller.key_hold_update(G.CONTROLLER,'r',.016)
G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_1();G.FUNCS.tyg_birth_cancel()
eq(streak_resets,before_streak,'preset held-R cancel preserves streak')
SMODS.RunSelect.Functions.start_run(true,true)
G.FUNCS.tyg_choose_preset();G.FUNCS.tyg_preset_pick_1();G.FUNCS.tyg_birth_cancel()
eq(deleted,before_deleted,'preset quick cancel cannot delete run')
-- A saved snapshot bypasses both entry modes without adding source metadata.
local saved_old={BACK={name='b_tyg_mingju'},tyg_cycle={version=2,natal_key='j_tyg_mp_shishen'}}
G.FUNCS.start_run(nil,{savetext=saved_old})
eq(starts,before_direct+1,'old Continue bypasses modes');eq(last_args.savetext,saved_old,'Continue receives exact existing save')
eq(saved_old.tyg_cycle.mode,nil,'Continue cannot relabel legacy snapshot')
print('PASS '..count..' native birthday input/start lifecycle assertions')
