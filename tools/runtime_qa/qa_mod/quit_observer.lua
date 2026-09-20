-- Observe the engine's native quit decision; never request, cancel or replace it.
function TYG_QA_INSTALL_QUIT_OBSERVER(qa,note,report)
 local previous=love.quit
 love.quit=function(...)
  local before=qa.status
  local trace=debug.traceback('native love.quit observed',2)
  local values,count={},0
  local function collect(...)values={...};count=select('#',...)end
  if previous then collect(previous(...))end
  local cancelled=not not values[1]
  if before=='running'and not cancelled then
   qa.status='failed';qa.error='Native engine quit before the QA scenario completed'
  end
  note('quit_observed',{status_before=before,cancelled=cancelled,trace=trace})
  pcall(report)
  return unpack(values,1,count)
 end
end
