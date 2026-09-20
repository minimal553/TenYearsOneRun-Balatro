-- Profile adapter kept separate from the unchanged v0.2 scoring module.
return function(R,M)
 assert(type(R)=='table' and type(M)=='table','Missing pattern matcher dependencies')
 return function(raw)
  if type(raw)~='table' or type(raw.decades)~='table' or #raw.decades<1 or #raw.decades>12 then
   return nil,'排盘或大运数据不完整'
  end
  local pattern,err=M.classify(raw.chart);if not pattern then return nil,err end
  local p=R.copy(raw)
  p.schema_version=1;p.rules_version=R.version;p.mode='ingame';p.selected_decade=1
  p.pattern=pattern;p.natal_tier=pattern.natal_tier
  p.day_element=pattern.features.day_element;p.score=pattern.features.game_grade.score
  p.weights=R.copy(pattern.features.elements)
  local row=M.by_key[pattern.key]
  p.route={key=row.key,name=row.name,planet_key=row.planet_key}
  for _,d in ipairs(p.decades)do
   if type(d)~='table' then return nil,'大运条目无效' end
   local affinity,trace=M.decade_affinity(pattern,d.gan_zhi)
   if affinity==nil then return nil,trace end
   d.affinity=affinity;d.affinity_version=M.version;d.affinity_reason=trace.reason;d.affinity_trace=trace
   d.luck_tier=affinity>=0.3 and 1 or(affinity<=-0.3 and 3 or 2)
   local rank=(p.natal_tier-1)*3+d.luck_tier
   d.grid={rank=rank,target_multiplier=1+(rank-1)/8,fortune_key='c_tyg_fortune_'..rank}
  end
  return R.validate_profile(p)
 end
end
