-- QA-only fail-closed isolation gate. Executes before conf and game startup.
love.errorhandler=function(message)
 print('TYG_QA_BOOTSTRAP_FAILED '..tostring(message))
 return function()return 2 end
end
local function normalize(path)
 return tostring(path or ''):gsub('\\','/'):gsub('/+$',''):lower()
end
local run=os.getenv('TYG_QA_RUN')
local function from_hex(value)
 assert(value and #value%2==0 and not value:find('[^0-9a-f]'),'invalid expected-path encoding')
 return value:gsub('..',function(pair)return string.char(tonumber(pair,16))end)
end
local expected_save=from_hex(os.getenv('TYG_QA_EXPECT_SAVE_HEX'))
local expected_mods=from_hex(os.getenv('TYG_QA_EXPECT_MODS_HEX'))
assert(run and #run>0,'QA refuses to start without a run identity')
assert(expected_save and expected_mods,'QA refuses missing expected isolation paths')
assert(normalize(love.filesystem.getSaveDirectory())==normalize(expected_save),
 'QA SAVE ISOLATION FAILURE: '..love.filesystem.getSaveDirectory())
assert(normalize(require('lovely').mod_dir)==normalize(expected_mods),
 'QA MOD ISOLATION FAILURE: '..tostring(require('lovely').mod_dir))
assert(normalize(love.filesystem.getAppdataDirectory())..'/balatro'==normalize(expected_save),
 'QA engine APPDATA is not the expected private parent')
TYG_RUNTIME_QA={run=run,save_directory=love.filesystem.getSaveDirectory(),
 mods_directory=require('lovely').mod_dir,bootstrap_passed=true}
-- Defense before any game or mod code: even if a later patch stops matching,
-- never load the Steam native library. The driver also rejects attempted loads.
local native_require=require
function require(name)
 if name=='luasteam'then
  TYG_RUNTIME_QA.steam_require_attempted=true
  error('TYG QA BLOCKED Steam native module before loading',2)
 end
 return native_require(name)
end
print('TYG_QA_BOOTSTRAP_OK '..run..' save='..TYG_RUNTIME_QA.save_directory)
