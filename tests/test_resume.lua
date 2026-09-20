local n=0
local function eq(a,b,m)n=n+1;assert(a==b,(m or'')..': '..tostring(a)..' ~= '..tostring(b))end
local loader=loadfile(TEST_ROOT..'/resume.lua')
assert(type(loader)=='function','resume placeholder fix module must exist')
local calls=0
Game={start_run=function(self,args)
 calls=calls+1
 local s=args.savetext
 if s then
  local g=s.GAME;local selected={atlas='tyg_deck'}
  local shown=g.viewed_back or selected
  self.actual_sprite_atlas=shown.atlas or'centers'
 end
 return'native'
end}
assert(loader()())
for _,marker in ipairs({'"MANUAL_REPLACE"','MANUAL_REPLACE'})do
 local s={BACK={key='b_tyg_mingju',name='b_tyg_mingju'},GAME={viewed_back=marker,selected_back=marker,tyg_cycle={natal_key='j_tyg_bijie'}}}
 local original_back=s.BACK;local original_cycle=s.GAME.tyg_cycle
 eq(Game:start_run({savetext=s}),'native','native return')
 eq(Game.actual_sprite_atlas,'tyg_deck','native sprite resolves actual custom selected back')
 eq(s.GAME.viewed_back,nil,'clear only transient placeholder')
 eq(s.GAME.selected_back,marker,'leave native selected_back replacement to engine')
 eq(s.BACK,original_back,'authoritative saved Back untouched');eq(s.GAME.tyg_cycle,original_cycle,'cycle snapshot untouched')
end
local valid={atlas='valid_preview'}
local s={BACK={key='b_tyg_mingju'},GAME={viewed_back=valid,tyg_run={}}}
Game:start_run({savetext=s});eq(s.GAME.viewed_back,valid,'real preview tables untouched')
local other={BACK={key='b_red',name='Red Deck'},GAME={viewed_back='"MANUAL_REPLACE"',tyg_cycle={}}}
Game:start_run({savetext=other});eq(other.GAME.viewed_back,'"MANUAL_REPLACE"','other deck untouched')
local unknown={BACK={key='b_tyg_mingju'},GAME={viewed_back='unrelated',tyg_cycle={}}}
Game:start_run({savetext=unknown});eq(unknown.GAME.viewed_back,'unrelated','unknown content untouched')
local legacy={BACK={name='b_tyg_mingju'},GAME={viewed_back='"MANUAL_REPLACE"',tyg_run={gift_state='complete'}}}
Game:start_run({savetext=legacy});eq(Game.actual_sprite_atlas,'tyg_deck','old own save art also restores')
eq(Game:start_run({}),'native','fresh new run passes through')
eq(calls,7,'no duplicate native starts')
print('PASS '..n..' scoped resume/real-placeholder assertions')
