-- This driver is appended only in the private QA mod directory.
-- It retains native update, draw, Card, UI, EventManager and filesystem code.
assert(TYG_RUNTIME_QA and TYG_RUNTIME_QA.bootstrap_passed,'QA bootstrap did not run')
local qa=TYG_RUNTIME_QA
local native_blind_amount=get_blind_amount
local scenario_update
qa.status='running';qa.scenario=os.getenv('TYG_QA_SCENARIO')or'smoke'
qa.events={};qa.screenshots={};qa.started=love.timer.getTime()
local function note(name,details)
 local snapshot=details and JSON and JSON.decode(JSON.encode(details))or details
 qa.events[#qa.events+1]={name=name,details=snapshot,time=love.timer.getTime()-qa.started,
  stage=G and G.STAGE,state=G and G.STATE}
 print('TYG_QA '..name..' '..(details and JSON and JSON.encode(details)or''))
end
local function report()
 assert(JSON and JSON.encode,'native Steamodded JSON encoder unavailable')
 love.filesystem.write('runtime-qa-result-'..qa.scenario..'.json',JSON.encode(qa))
end
local function fail(message)
 qa.status='failed';qa.error=tostring(message);note('failed',qa.error)
 if JSON then pcall(report)end
 love.event.quit(2)
end
local function finish()
 qa.status='passed';note('passed');report();love.event.quit(0)
end
local function capture(filename,after)
 love.graphics.captureScreenshot(function(data)
  local ok,err=xpcall(function()
   data:encode('png',filename);qa.screenshots[#qa.screenshots+1]=filename
   note('screenshot_saved',filename)
   if after then after()end
  end,debug.traceback)
  if not ok then fail(err)end
 end)
end
local function find_button(node,name)
 if node.config and node.config.button==name then return node end
 for _,child in pairs(node.children or{})do
  local found=find_button(child,name);if found then return found end
 end
end
local original_load=love.load
function love.load(...)
 G.SETTINGS.WINDOW.screenmode='Windowed'
 G.SETTINGS.screen_res={w=1280,h=800}
 G.SETTINGS.SOUND.volume=0
 G.SETTINGS.language='zh_CN'
 G.F_HTTP_SCORES=false;G.F_CRASH_REPORTS=false
 G.F_SKIP_TUTORIAL=true
 original_load(...)
 assert(qa.steam_branch_disabled and not qa.steam_require_attempted,'QA Steam branch patch did not apply')
 assert(not G.STEAM,'QA Steam isolation failed')
 assert(not package.loaded.luasteam,'QA loaded the Steam native integration unexpectedly')
 -- Observe only this mod's save requests. Never change the native save/state.
 local native_save=save_run
 save_run=function(...)
  local caller=debug.getinfo(2,'S')
  if caller and caller.source:lower():find('cycles.lua',1,true)then
   local cycle=SMODS.Mods.ten_years_nine_grid.tyg_cycles
   qa.cycle_save_count=(qa.cycle_save_count or 0)+1
   if not cycle.idle()then
    qa.unsafe_cycle_save=true
    error('Cycle attempted to persist an unstable native state '..tostring(G.STATE))
   end
   note('cycle_save_stable',{state=G.STATE,ordinal=qa.cycle_save_count})
  end
  return native_save(...)
 end
 love.window.setTitle('TenYearsNineGrid QA '..qa.run)
 love.window.setPosition(-32000,-32000)
 qa.love_version=love._version;qa.game_version=G.VERSION;qa.steamodded_version=SMODS.version
 qa.extra_mods={}
 for id in (os.getenv('TYG_QA_EXPECT_EXTRA_IDS')or''):gmatch('[^,]+')do
  local extra=assert(SMODS.Mods[id],'expected compatibility mod absent: '..id)
  assert(not extra.disabled and extra.can_load~=false,'expected compatibility mod disabled: '..id)
  qa.extra_mods[#qa.extra_mods+1]={id=id,version=extra.version}
 end
 qa.window={width=love.graphics.getWidth(),height=love.graphics.getHeight(),offscreen=true}
 note('engine_loaded',{steam_disabled=true,back_registered=G.P_CENTERS.b_tyg_mingju~=nil})
 assert(G.P_CENTERS.b_tyg_mingju,'production deck was not registered')
 if qa.scenario~='smoke'then
  scenario_update=assert(TYG_QA_SCENARIOS[qa.scenario],'unknown native QA scenario')(
   qa,note,capture,finish,native_blind_amount)
 end
 qa.ready_at=love.timer.getTime()
end
local original_update=love.update
function love.update(dt)
 original_update(dt)
 if qa.status~='running'then return end
 local ok,err=xpcall(function()
  assert(not G.STEAM,'Steam became active inside QA')
  if G.OVERLAY_MENU and G.OVERLAY_MENU.UIRoot then
   local unlock=find_button(G.OVERLAY_MENU.UIRoot,'continue_unlock')
   if unlock then G.FUNCS.continue_unlock(unlock);note('native_unlock_dismissed');return end
  end
  if love.timer.getTime()-qa.ready_at>(qa.scenario=='smoke'and 45 or 200)then error('native scenario timeout')end
  if not qa.menu_requested and love.timer.getTime()-qa.ready_at>1 then
   qa.menu_requested=true
   if G.STATE==G.STATES.SPLASH or G.STAGE~=G.STAGES.MAIN_MENU then G:main_menu('splash')end
   note('main_menu_requested')
  end
  local menu=G.MAIN_MENU_UI
  if not qa.menu_ready and(not qa.last_menu_probe or love.timer.getTime()-qa.last_menu_probe>10)then
   qa.last_menu_probe=love.timer.getTime()
   note('menu_probe',{state=G.STATE,has_menu=menu~=nil,lock_input=G.CONTROLLER.lock_input,
    ui_y=menu and menu.VT and menu.VT.y,target_y=menu and menu.T and menu.T.y})
  end
  if menu and menu:get_UIE_by_ID('main_menu_play')then qa.menu_seen_at=qa.menu_seen_at or love.timer.getTime()end
  local settled=menu and menu.T and menu.VT and math.abs(menu.T.y-menu.VT.y)<.03
  if qa.menu_requested and qa.menu_seen_at and settled and menu.states.visible
    and not G.CONTROLLER.lock_input and not qa.menu_ready
    and love.timer.getTime()-qa.menu_seen_at>2 then
   qa.menu_ready=true
   note('main_menu_stable',{play_button=true,ui_y=menu.VT.y,target_y=menu.T.y})
   if qa.scenario=='smoke'then capture('runtime-qa-main-menu.png',finish)end
  end
  if qa.menu_ready and scenario_update then scenario_update()end
 end,debug.traceback)
 if not ok then fail(err)end
end
love.errorhandler=function(message)
 fail(message)
 return function()return 2 end
end
TYG_QA_INSTALL_QUIT_OBSERVER(qa,note,report)
