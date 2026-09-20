-- Native menu flow. The calculator is a pure function; no browser or process IPC.
return function(mod,R,calculate,C,P)
 local I={}
 local session,approved,launching,overlay,internal_close,pending_restart
 local wrapped={}
 local field_ids={tyg_birth_date=true,tyg_birth_time=true}
 local function clear_input()
  if G.CONTROLLER and field_ids[G.CONTROLLER.text_input_id]then
   G.CONTROLLER.text_input_hook=nil;G.CONTROLLER.text_input_id=nil
   -- The old overlay owns and removes its keyboard UI; clear the controller ref.
   G.CONTROLLER.screen_keyboard=nil
  end
 end
 local function discard()
  clear_input();session=nil;approved=nil;launching=false;overlay=nil;pending_restart=nil
 end
 local function close()
  clear_input();internal_close=true
  G.FUNCS.exit_overlay_menu()
  internal_close=false;overlay=nil
 end
 local function textrow(text,scale)
  return{n=G.UIT.R,config={align='cm',padding=.07},nodes={{n=G.UIT.T,config={text=text,scale=scale or .3,colour=G.C.UI.TEXT_LIGHT}}}}
 end
 local function dynamic(key,scale)
  return{n=G.UIT.R,config={align='cm',padding=.09},nodes={{n=G.UIT.O,config={object=DynaText{
   string={{ref_table=session.display,ref_value=key}},colours={G.C.UI.TEXT_LIGHT},scale=scale or .3,maxw=8.5,silent=true,shadow=true}}}}}
 end
 local function input_column(label,key,id,width,length,prompt)
  return{n=G.UIT.C,config={align='cm',padding=.12},nodes={textrow(label,.29),
   create_text_input{id=id,ref_table=session.form,ref_value=key,w=width,h=.55,max_length=length,
    text_scale=.45,prompt_text=prompt,extended_corpus=true,all_caps=false}}}
 end
 local function summary()
  local p=session.profile;local run=C.prepare_run(p);local r=C.phase(run,p.selected_decade)
  session.display.chart=table.concat(p.chart,' ')
  session.display.pattern='专属小丑：'..run.pattern_name
  local pattern=run.pattern
  session.display.evidence=pattern and((pattern.status or'游戏归类')..'：'..((pattern.reasons or{})[1]or'按当前规则匹配'))or'旧版游戏模板'
  session.display.combo=pattern and pattern.combo and('组合：'..pattern.combo.name)or'组合：无附加词条'
  session.display.result='本命'..R.tier_names[p.natal_tier]..' · 本运'..R.tier_names[r.luck_tier]..'｜目标 '..r.target_multiplier..'倍'
  session.display.reward='第'..r.rank..'档 '..r.reward_name..'运签：'..r.reward_text
  if session.mode=='preset'then
   session.display.result='本命'..R.tier_names[p.natal_tier]..' · 运'..R.tier_names[r.luck_tier]..'｜目标 '..r.target_multiplier..'倍'
  else
   session.display.dates=r.start_date:sub(1,10)..' 至 '..r.end_date:sub(1,10)
  end
 end
 local function show()
  clear_input()
  local nodes={}
  if not session.mode then
   nodes[#nodes+1]=textrow('选择这一局的入口',.5)
   nodes[#nodes+1]=UIBox_button{label={'九宫预设'},button='tyg_choose_preset',minw=6,minh=.75,colour=G.C.GREEN}
   nodes[#nodes+1]=textrow('直接选择本命档与运档，8阶段固定档挑战。',.27)
   nodes[#nodes+1]=UIBox_button{label={'输入生日'},button='tyg_choose_birth',minw=6,minh=.75,colour=G.C.BLUE}
   nodes[#nodes+1]=textrow('生日匹配26种格局起手，随真实大运调整档次。',.27)
   nodes[#nodes+1]=dynamic('error',.25)
  elseif session.mode=='preset'then
   nodes[#nodes+1]=textrow(session.profile and'九宫预设 · 确认挑战'or'九宫预设 · 选择档次',.5)
   nodes[#nodes+1]=textrow('固定档挑战：本命档与运档在8阶段均保持不变。',.27)
   if not session.profile then
    nodes[#nodes+1]=textrow('每行本命上／中／下；每列运上／中／下',.25)
    for natal=1,3 do
     local row={n=G.UIT.R,config={align='cm',padding=.06},nodes={}}
     for luck=1,3 do
      local grid=C.grid(natal,luck)
      row.nodes[#row.nodes+1]={n=G.UIT.C,config={align='cm',padding=.04},nodes={
       UIBox_button{label={'本命'..R.tier_names[natal]..' · 运'..R.tier_names[luck],
        '目标×'..grid.target_multiplier..' · '..grid.reward_name..'签'},
        button='tyg_preset_pick_'..grid.rank,minw=2.5,minh=.8,scale=.3,colour=G.C.BLUE}}}
     end
     nodes[#nodes+1]=row
    end
   else
    summary();nodes[#nodes+1]=dynamic('pattern',.34)
    nodes[#nodes+1]=textrow('统一常规命局小丑 · 无组合词条 · 推荐高牌／冥王星',.27)
    nodes[#nodes+1]=dynamic('result',.36);nodes[#nodes+1]=dynamic('reward',.28)
    nodes[#nodes+1]=textrow('每升1底注推进1阶段并获得运签；无尽沿用第8阶段。',.25)
    nodes[#nodes+1]=UIBox_button{label={'开始这一局'},button='tyg_preset_start',minw=6,minh=.65,colour=G.C.GREEN}
    nodes[#nodes+1]=UIBox_button{label={'重选九宫预设'},button='tyg_preset_edit',minw=6,minh=.5,colour=G.C.BLUE}
   end
   nodes[#nodes+1]=textrow('预设不生成生日、四柱或真实大运年月。',.23)
  elseif not session.profile then
   nodes[#nodes+1]=textrow('输入生日，生成这一局',.5)
   nodes[#nodes+1]=textrow('公历 · 北京时间 UTC+8 · 不作真太阳时校正',.25)
   nodes[#nodes+1]={n=G.UIT.R,config={align='cm'},nodes={
    input_column('出生日期：年 月 日','date','tyg_birth_date',4.1,10,'YYYYMMDD'),
    input_column('出生时间：如7:30','time','tyg_birth_time',2.5,5,'7:30')}}
   nodes[#nodes+1]=create_option_cycle{label='排运参数',options={'请选择','男命口径','女命口径'},
    current_option=session.sex_option,opt_callback='tyg_birth_gender',w=4.8,scale=.8,no_pips=true,cycle_shoulders=false}
   nodes[#nodes+1]=dynamic('error',.27)
   nodes[#nodes+1]=UIBox_button{label={'匹配命局'},button='tyg_birth_match',minw=6,minh=.65,colour=G.C.GREEN}
  else
   nodes[#nodes+1]=textrow('命局已匹配',.5)
   summary();nodes[#nodes+1]=dynamic('chart',.4);nodes[#nodes+1]=dynamic('pattern',.34)
   nodes[#nodes+1]=dynamic('combo',.27);nodes[#nodes+1]=dynamic('evidence',.23)
   local options={};for _,d in ipairs(session.profile.decades)do options[#options+1]='第'..d.index..'步 '..d.gan_zhi end
   nodes[#nodes+1]=create_option_cycle{label='预览大运（开局从第1步）',options=options,current_option=session.profile.selected_decade,
    opt_callback='tyg_birth_decade',w=5.6,scale=.8,no_pips=true,cycle_shoulders=false}
   nodes[#nodes+1]=dynamic('dates',.28);nodes[#nodes+1]=dynamic('result',.36)
   nodes[#nodes+1]=dynamic('reward',.28)
   nodes[#nodes+1]=UIBox_button{label={'开始这一局'},button='tyg_birth_start',minw=6,minh=.65,colour=G.C.GREEN}
   nodes[#nodes+1]=UIBox_button{label={'修改生日'},button='tyg_birth_edit',minw=6,minh=.5,colour=G.C.BLUE}
  end
  if session.mode then
   nodes[#nodes+1]=UIBox_button{label={'返回选择入口'},button='tyg_entry_modes',minw=6,minh=.5,colour=G.C.BLUE}
  end
  nodes[#nodes+1]=textrow('游戏化归类，非人生判断；生日不写入设置。',.23)
  G.SETTINGS.paused=true
  G.FUNCS.overlay_menu{definition=create_UIBox_generic_options{back_func='tyg_birth_cancel',back_label='取消',
   contents={{n=G.UIT.C,config={align='cm',padding=.12},nodes=nodes}},minw=8.2}}
  overlay=G.OVERLAY_MENU
 end
 local function request(launch)
  if session or launching then return end
  session={launch=launch,form={date='',time=''},sex_option=1,display={error=''}}
  show()
 end
 local function own_name(name)
  local center=G.P_CENTERS and G.P_CENTERS.b_tyg_mingju
  return name=='b_tyg_mingju'or(center and name==center.name)
 end
 local function native_own(e,args)
  if args.savetext or args.challenge then return false end
  if args.deck_choice then
   return own_name(type(args.deck_choice)=='table'and args.deck_choice.name or args.deck_choice)
  end
  local game=G.GAME or{}
  local restarting=e and e.config and e.config.id=='restart_button'
  local back=not restarting and game.viewed_back or game.selected_back
  if not back then back=game.selected_back end
  return back and(own_name(back.name)or(back.effect and back.effect.center and own_name(back.effect.center.key)))
 end
 function I.consume_profile()
  local p=approved;approved=nil;launching=false
  return p
 end
 function I.current_profile()return session and session.profile or approved end
 -- Native button events retain the UIBox that created them. Once a page has
 -- been replaced, a queued click from that page must not act on the new one.
 local function current_event(e)return not(e and e.UIBox)or e.UIBox==overlay end
 local function change_mode(mode)
  clear_input();approved=nil;session.mode=mode;session.profile=nil
  session.form={date='',time=''};session.sex_option=1
  session.display={error=mode=='birth'and'时间可填730、0730或7:30；请选择排运参数。'or''}
  show()
 end
 G.FUNCS.tyg_entry_modes=function(e)
  if current_event(e)and session then change_mode(nil)end
 end
 G.FUNCS.tyg_choose_birth=function(e)
  if current_event(e)and session and not session.mode then change_mode('birth')end
 end
 G.FUNCS.tyg_choose_preset=function(e)
  if not current_event(e)or not session or session.mode then return end
  if not P then session.display.error='九宫预设未加载。';return end
  change_mode('preset')
 end
 for rank=1,9 do
  local selected=rank
  G.FUNCS['tyg_preset_pick_'..selected]=function(e)
   if not current_event(e)or not session or session.mode~='preset'or session.profile then return end
   session.profile=assert(P.make(selected));show()
  end
 end
 G.FUNCS.tyg_preset_edit=function(e)
  if current_event(e)and session and session.mode=='preset'and session.profile then session.profile=nil;show()end
 end
 G.FUNCS.tyg_birth_cancel=function(e)
  if not current_event(e)or not session then return end
  discard();close()
 end
 G.FUNCS.tyg_birth_gender=function(args)
  if session and session.mode=='birth'and not session.profile and type(args.to_key)=='number'and args.to_key>=1 and args.to_key<=3 then
   session.sex_option=args.to_key
  end
 end
 G.FUNCS.tyg_birth_match=function(e)
  if not current_event(e)or not session or session.mode~='birth'or session.profile then return end
  clear_input()
  local date=session.form.date:gsub('%-','')
  if not date:match('^%d%d%d%d%d%d%d%d$')then
   session.display.error='出生日期须为8位数字，例如20000229。';return
  end
  local raw_time=session.form.time
  local hour,minute=raw_time:match('^(%d%d?):(%d%d)$')
  if not hour and raw_time:match('^%d%d%d%d?$')then
   hour,minute=raw_time:sub(1,-3),raw_time:sub(-2)
  end
  if not hour or tonumber(hour)>23 or tonumber(minute)>59 then
   session.display.error='出生时间无效：可填730、0730或7:30，范围00:00至23:59。';return
  end
  local time=string.format('%02d%02d',tonumber(hour),tonumber(minute))
  if session.sex_option~=2 and session.sex_option~=3 then session.display.error='请选择男命或女命排运口径。';return end
  local now=os.date('!%Y%m%d%H%M',os.time()+8*3600)
  if date..time>now then session.display.error='出生时间不能晚于当前时间。';return end
  local p,err=calculate{date=date:sub(1,4)..'-'..date:sub(5,6)..'-'..date:sub(7,8),
   time=time:sub(1,2)..':'..time:sub(3,4),gender=session.sex_option==2 and 1 or 0}
  if not p then session.display.error=err or'无法匹配，请核对输入。';return end
  local valid,validation_error=R.validate_profile(p)
  if not valid then session.display.error=validation_error;return end
  session.profile=valid;session.profile.selected_decade=1;show()
 end
 G.FUNCS.tyg_birth_decade=function(args)
  if session and session.mode=='birth'and session.profile and type(args.to_key)=='number'and args.to_key==math.floor(args.to_key)
    and args.to_key>=1 and args.to_key<=#session.profile.decades then
   session.profile.selected_decade=args.to_key;summary()
  end
 end
 G.FUNCS.tyg_birth_edit=function(e)
  if current_event(e)and session and session.mode=='birth'and session.profile then session.profile=nil;session.display.error='可修改出生信息后重新匹配。';show()end
 end
 local function start(mode,e)
  if not current_event(e)or not session or session.mode~=mode or not session.profile or launching then return end
  local launch=session.launch
  approved=R.copy(session.profile);approved.selected_decade=1;launching=true;session=nil
  close()
  local success,result=pcall(launch)
  if not success then approved=nil;launching=false;error(result)end
  return result
 end
 G.FUNCS.tyg_birth_start=function(e)return start('birth',e)end
 G.FUNCS.tyg_preset_start=function(e)return start('preset',e)end
 function I.update()
  local pending=pending_restart
  if not pending then return end
  if G.GAME~=pending.game then discard();return end
  local ctrl=pending.controller
  -- exit_overlay_menu sets a one-frame input lock. Do not clear native locks.
  if G.SETTINGS.paused or ctrl.locked or ctrl.locks.frame or ctrl.frame_buttonpress then return end
  pending_restart=nil
  ctrl.held_key_times.r=pending.held
  local success,result=pcall(pending.previous,ctrl,'r',0)
  if not success then approved=nil;launching=false;error(result)end
 end
 function I.install_hooks()
  if not wrapped.setup and type(G.FUNCS.start_setup_run)=='function'then
   local previous=G.FUNCS.start_setup_run;wrapped.setup=true
   G.FUNCS.start_setup_run=function(e)
    if launching or G.SETTINGS.current_setup~='New Run'or not native_own(e,{challenge=G.challenge_tab})then
     return previous(e)
    end
    local names={'run_setup_seed','setup_seed','forced_seed','challenge_tab','forced_stake'}
    local frozen={};for _,name in ipairs(names)do frozen[name]=G[name]end
    local viewed=G.GAME.viewed_back
    return request(function()
     G.SETTINGS.current_setup='New Run';G.GAME.viewed_back=viewed
     for _,name in ipairs(names)do G[name]=frozen[name]end
     return previous(e)
    end)
   end
  end
  if not wrapped.held and Controller and type(Controller.key_hold_update)=='function'then
   local previous=Controller.key_hold_update;wrapped.held=true
   function Controller:key_hold_update(key,dt)
    local held=self.held_key_times and self.held_key_times[key]
    if not launching and key=='r'and held and held>.7 and not G.SETTINGS.paused
      and not self.locked and not self.locks.frame and not self.frame_buttonpress
      and G.STAGE==G.STAGES.RUN and not G.GAME.challenge
      and native_own({config={id='restart_button'}},{})then
     self.held_key_times[key]=nil
     local pending={previous=previous,controller=self,held=held,game=G.GAME}
     return request(function()pending_restart=pending end)
    end
    return previous(self,key,dt)
   end
  end
  if not wrapped.start and type(G.FUNCS.start_run)=='function'then
   local previous=G.FUNCS.start_run;wrapped.start=true
   G.FUNCS.start_run=function(e,args)
    args=args or{}
    if launching or not native_own(e,args)then return previous(e,args)end
    local frozen=R.copy(args)
    return request(function()return previous(e,frozen)end)
   end
  end
  local rs=SMODS.RunSelect
  if not wrapped.run_select and rs and rs.Functions and type(rs.Functions.start_run)=='function'then
   local previous=rs.Functions.start_run;wrapped.run_select=true
   rs.Functions.start_run=function(quick,skip)
    local profile=G.PROFILES[G.SETTINGS.profile]
    local choices=quick and profile.last_choices or rs.Setup.choices
    if launching or not choices or not own_name(choices.deck_choice)then return previous(quick,skip)end
    local frozen_choices=R.copy(choices)
    local frozen_setup=R.copy(rs.Setup.choices)
    return request(function()
     rs.Setup.choices=R.copy(frozen_setup)
     if quick then profile.last_choices=R.copy(frozen_choices)else rs.Setup.choices=R.copy(frozen_choices)end
     return previous(quick,skip)
    end)
   end
  end
  if not wrapped.exit and type(G.FUNCS.exit_overlay_menu)=='function'then
   local previous=G.FUNCS.exit_overlay_menu;wrapped.exit=true
   G.FUNCS.exit_overlay_menu=function(...)
    if not internal_close and session and G.OVERLAY_MENU==overlay then discard()end
    return previous(...)
   end
  end
  if not wrapped.text and type(G.FUNCS.text_input_key)=='function'then
   local previous=G.FUNCS.text_input_key;wrapped.text=true
   G.FUNCS.text_input_key=function(args)
    local ctrl=G.CONTROLLER
    if ctrl and ctrl.text_input_hook and field_ids[ctrl.text_input_id]then
     local key=args and args.key
     if type(key)=='string'and #key==1 then
      if not key:match('^[0-9:%-]$')then return end
      local config=ctrl.text_input_hook.config.ref_table
      local t=config.text
      if #t.ref_table[t.ref_value]<(config.max_length or 10)then
       TRANSPOSE_TEXT_INPUT(0)
       MODIFY_TEXT_INPUT{letter=key,text_table=t,pos=t.current_position+1}
       TRANSPOSE_TEXT_INPUT(1)
      end
      return
     end
    end
    return previous(args)
   end
  end
 end
 return I
end
