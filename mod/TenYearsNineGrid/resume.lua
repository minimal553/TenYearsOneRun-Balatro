-- Fix only our save's culled UI-preview placeholder, before native card loading.
-- BACK remains authoritative; the engine still rebuilds selected_back itself.
return function()
 if not Game or type(Game.start_run)~='function'then return false end
 local previous=Game.start_run
 function Game:start_run(args)
  local saved=args and args.savetext
  if type(saved)=='table'and type(saved.BACK)=='table'and type(saved.GAME)=='table'
    and(saved.BACK.key=='b_tyg_mingju'or saved.BACK.name=='b_tyg_mingju')
    and(type(saved.GAME.tyg_cycle)=='table'or type(saved.GAME.tyg_run)=='table')then
   local preview=saved.GAME.viewed_back
   -- recursive_table_cull emits embedded quotes in this native build.
   if preview=='"MANUAL_REPLACE"'or preview=='MANUAL_REPLACE'then saved.GAME.viewed_back=nil end
  end
  return previous(self,args)
 end
 return true
end
