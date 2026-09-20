-- Nine fixed challenges. These profiles do not represent a calendar or a birth chart.
return function(R,M,C)
 local P={catalog={}}
 local profiles={}
 local regular=assert(M.by_key.changgui,'Missing regular starter')
 for natal=1,3 do for luck=1,3 do
  local grid=C.grid(natal,luck)
  local id='grid_n'..natal..'_l'..luck
  local name='本命'..R.tier_names[natal]..' · 运'..R.tier_names[luck]
  P.catalog[grid.rank]={id=id,rank=grid.rank,name=name,natal_tier=natal,luck_tier=luck,
   target_multiplier=grid.target_multiplier,reward_name=grid.reward_name,reward_text=grid.reward_text}
  local p={schema_version=1,rules_version=R.version,mode='preset',preset_id=id,export_id='builtin-'..id..'-v1',
   chart={'九宫预设','固定本命','固定运档','游戏挑战'},natal_tier=natal,selected_decade=1,
   pattern={version=M.version,key=regular.key,name=regular.name,status='固定档挑战',
    reasons={'本命档与运档均由玩家选择，8阶段保持不变；未进行生日排盘。'}},
   route={key=regular.key,name='高牌',hand_type='High Card',planet_key='c_pluto'},decades={}}
  for i=1,8 do
   p.decades[i]={index=i,gan_zhi='固定运档',start_date='阶段开始',end_date='阶段结束',luck_tier=luck,
    grid={rank=grid.rank,target_multiplier=grid.target_multiplier,fortune_key='c_tyg_fortune_'..grid.rank}}
  end
  profiles[grid.rank]=assert(R.validate_profile(p))
 end end
 function P.make(rank)
  if type(rank)~='number'or rank~=math.floor(rank)or not profiles[rank]then return nil,'请选择1至9档九宫预设'end
  return R.copy(profiles[rank])
 end
 return P
end
