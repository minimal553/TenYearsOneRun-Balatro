-- Run with tests/run_lua_tests.py test_patterns.lua (the game's real Lua 5.1).
-- Hand-built tuples below test isolated rules and valid individual pillars.
-- They do NOT assert year/month and day/hour calendar consistency. Real dated
-- witnesses for all 26 classes live in pattern_calendar_fixtures.json instead.
local loader=loadfile(TEST_ROOT..'/chart_patterns.lua')
assert(loader,'v0.5 chart pattern module must exist')
local M=loader()
local R=assert(loadfile(TEST_ROOT..'/rules.lua'))()
local match_factory=loadfile(TEST_ROOT..'/pattern_matcher.lua')
assert(match_factory,'v0.5 profile matcher module must exist')
local match=match_factory()(R,M)
local ids={'zhengguan','qisha','zhengcai','piancai','zhengyin','pianyin','shishen','shangguan',
 'jianlu','yuejie','yangren','cong_cai','cong_sha','cong_er','cong_shi','quzhi','yanshang','jiase',
 'congge','runxia','hua_tu','hua_jin','hua_shui','hua_mu','hua_huo','changgui'}
assert(#M.catalog==26 and M.ordered==M.catalog,'exactly 26 stable ordered game categories')
for i,key in ipairs(ids) do
 assert(M.catalog[i].key==key and M.by_key[key]==M.catalog[i],'stable catalog ID '..key)
 assert(M.catalog[i].joker_key=='j_tyg_mp_'..key,'stable starter Joker key')
end
local expected={'bijian','jiecai','shishen','shangguan','piancai','zhengcai','qisha','zhengguan','pianyin','zhengyin'}
local stems={'甲','乙','丙','丁','戊','己','庚','辛','壬','癸'}
for i,s in ipairs(stems)do assert(M.ten_god('甲',s)==expected[i],'yang day ten god '..s)end
local yin={'jiecai','bijian','shangguan','shishen','zhengcai','piancai','zhengguan','qisha','zhengyin','pianyin'}
for i,s in ipairs(stems)do assert(M.ten_god('乙',s)==yin[i],'yin day ten god '..s)end
local further_gods={
 'pianyin zhengyin bijian jiecai shishen shangguan piancai zhengcai qisha zhengguan',
 'zhengyin pianyin jiecai bijian shangguan shishen zhengcai piancai zhengguan qisha',
 'qisha zhengguan pianyin zhengyin bijian jiecai shishen shangguan piancai zhengcai',
 'zhengguan qisha zhengyin pianyin jiecai bijian shangguan shishen zhengcai piancai',
 'piancai zhengcai qisha zhengguan pianyin zhengyin bijian jiecai shishen shangguan',
 'zhengcai piancai zhengguan qisha zhengyin pianyin jiecai bijian shangguan shishen',
 'shishen shangguan piancai zhengcai qisha zhengguan pianyin zhengyin bijian jiecai',
 'shangguan shishen zhengcai piancai zhengguan qisha zhengyin pianyin jiecai bijian'}
for n,row in ipairs(further_gods)do
 local i=0;for god in row:gmatch('%S+')do i=i+1;assert(M.ten_god(stems[n+2],stems[i])==god,'full 100-pair ten-god table')end
end
assert(M.ten_god('x','甲')==nil and M.ten_god('甲','x')==nil,'bad stem rejected')
local f=assert(M.analyze({'甲子','丙寅','甲辰','戊午'}))
assert(f.total_weight==80,'50 hidden points and three visible stems at ten points')
assert(f.visible.bijian==1,'day stem is not independent peer evidence')
assert(f.hidden[2][1].stem=='甲' and f.hidden[2][1].weight==12,'month hidden main stem doubled')
assert(f.hidden[2][2].stem=='丙' and f.hidden[2][2].weight==6,'month hidden middle stem doubled')
assert(f.hidden[2][3].stem=='戊' and f.hidden[2][3].weight==2,'month hidden residual stem doubled')
assert(f.gods.bijian==22 and f.gods.jiecai==3,'peer evidence includes other visible and all roots only')
for _,bad in ipairs({{}, {'甲子'}, {'甲丑','丙寅','甲辰','戊午'}, {'坏值','丙寅','甲辰','戊午'},
 {'甲子','丙寅','甲辰','戊午','甲子'}, {'甲子','丙寅',32,'戊午'}})do
 local p,e=M.classify(bad);assert(p==nil and type(e)=='string','invalid chart must error, never changgui')
end
assert(not M.classify(nil),'missing chart rejected')
local ordinary={
 {'zhengguan',{'壬子','辛酉','甲辰','丙寅'}},
 {'qisha',{'壬子','庚申','甲辰','丙寅'}},
 {'zhengcai',{'壬子','己丑','甲辰','丙寅'}},
 {'piancai',{'壬子','戊戌','甲辰','丙寅'}},
 {'zhengyin',{'癸酉','庚子','甲辰','丙寅'}},
 {'pianyin',{'壬申','癸亥','甲辰','丙寅'}},
 {'shishen',{'丙子','丁巳','甲辰','庚申'}},
 {'shangguan',{'壬子','丁未','甲辰','庚申'}},
 {'jianlu',{'庚申','丙寅','甲辰','壬子'}},
 {'yuejie',{'庚申','戊寅','乙丑','壬子'}},
 {'yangren',{'庚申','丁卯','甲辰','壬子'}},
}
for _,case in ipairs(ordinary)do
 local p,e=M.classify(case[2]);assert(p,e)
 assert(p.key==case[1],case[1]..' expected, got '..p.key)
 assert(p.name==M.by_key[p.key].name and #p.reasons>0,'human-readable evidence')
 assert(p.natal_tier>=1 and p.natal_tier<=3,'game tier available')
 local again=assert(M.classify(case[2]));assert(again.key==p.key and again.natal_tier==p.natal_tier,'determinism')
end
-- No 午-born yin day is automatically a yang blade; 戊/己 use the documented 寄火 policy.
assert(M.classify({'壬子','丙午','丁酉','庚戌'}).key=='jianlu','丁午 is 建禄')
assert(M.classify({'壬子','丁巳','戊辰','庚申'}).key=='jianlu','戊巳 follows 寄火 school')
assert(M.classify({'壬子','丙午','己丑','庚申'}).key=='jianlu','己午 follows 寄火 school')
assert(M.classify({'壬子','丙午','戊辰','庚申'}).key=='yangren','戊午 is 阳刃 by chosen school')
local raw={chart={'乙酉','戊子','辛巳','壬辰'},calendar={gender=0},decades={
 {index=1,gan_zhi='己丑',start_date='2010-01-01',end_date='2020-01-01'},
 {index=2,gan_zhi='庚寅',start_date='2020-01-01',end_date='2030-01-01'}}}
local p,e=match(raw);assert(p,e)
assert(R.validate_profile(p),'new matcher stays compatible with production profile validation')
assert(M.by_key[p.route.key] and p.pattern.key==p.route.key,'new identity uses pattern key')
assert(p.rules_version==R.version and p.selected_decade==1,'version and initial decade retained')
assert(raw.pattern==nil and raw.decades[1].luck_tier==nil,'source chart is not mutated')
assert(p.decades[1].affinity_version==M.version and type(p.decades[1].affinity_reason)=='string','decade policy auditable')
assert(p.pattern.natal_tier==p.natal_tier,'one consistent game tier')
assert(not match({chart=raw.chart,decades={{index=1,gan_zhi='甲丑',start_date='a',end_date='b'}}}),'invalid decade errors')
assert(not match({chart=raw.chart,decades={}}),'missing decades error')
local special={
 {'cong_cai',{'戊戌','戊戌','甲戌','戊戌'},{'戊戌','戊戌','甲辰','戊戌'}},
 {'cong_sha',{'辛酉','辛酉','乙酉','辛酉'},{'辛酉','辛酉','乙卯','辛酉'}},
 {'cong_er',{'丙午','丙午','甲戌','丁巳'},{'丙午','丙午','甲寅','丁巳'}},
 {'cong_shi',{'丙午','戊戌','甲申','辛酉'},{'丙午','戊戌','甲寅','辛酉'}},
 {'quzhi',{'甲寅','乙卯','甲辰','乙卯'},{'庚寅','乙卯','甲辰','乙卯'}},
 {'yanshang',{'丙寅','丙午','丙戌','丁巳'},{'壬寅','丙午','丙戌','丁巳'}},
 {'jiase',{'己丑','戊辰','戊辰','己未'},{'乙丑','戊辰','戊辰','己未'}},
 {'congge',{'庚申','辛酉','庚戌','辛酉'},{'丙申','辛酉','庚戌','辛酉'}},
 {'runxia',{'癸亥','壬子','壬子','癸丑'},{'己亥','壬子','壬子','癸丑'}},
 {'hua_tu',{'戊戌','己丑','甲戌','戊辰'},{'戊戌','丁丑','甲戌','戊辰'}},
 {'hua_jin',{'辛酉','庚申','乙酉','辛酉'},{'辛酉','壬申','乙酉','辛酉'}},
 {'hua_shui',{'壬子','辛亥','丙子','壬子'},{'壬子','癸亥','丙子','壬子'}},
 {'hua_mu',{'甲辰','乙卯','丁卯','壬寅'},{'甲辰','乙卯','丁卯','甲寅'}},
 {'hua_huo',{'丙午','戊午','癸巳','丙午'},{'丙午','庚午','癸巳','丙午'}},
}
for _,case in ipairs(special)do
 local positive=assert(M.classify(case[2]));assert(positive.key==case[1],case[1]..' positive got '..positive.key)
 local negative=assert(M.classify(case[3]));assert(negative.key~=case[1],case[1]..' near miss must not qualify')
 assert(positive.status=='倾向','special categories disclose versioned game interpretation')
 local check=positive.features.special_checks[case[1]]
 assert(check and check.passed and #check.gates>=4,'special AND gates are inspectable')
 local rejected=negative.features.special_checks[case[1]]
 assert(rejected and not rejected.passed,'near-miss rejection is inspectable')
end
assert(M.classify({'癸酉','丁丑','甲辰','辛巳'}).key=='changgui','ambiguous non-main month stems retain common category')
assert(M.classify({'壬子','己丑','甲寅','丙辰'}).kind~='transform','mere stem combination is not transformation')
assert(M.classify({'己丑','己丑','甲戌','戊辰'}).key~='hua_tu','competing partners do not transform')
assert(M.classify({'甲寅','乙卯','甲寅','乙卯'}).kind~='dominant','strong element without a complete formation is not 专旺')
local combos={
 {'guanyin',{'癸丑','辛酉','甲寅','壬子'}},
 {'shayin',{'庚申','壬子','甲寅','癸酉'}},
 {'shishengcai',{'丙寅','丁巳','甲辰','戊寅'}},
 {'shangshengcai',{'戊辰','丁未','甲辰','壬子'}},
 {'shangpeiyin',{'癸亥','丁未','甲寅','壬子'}},
 {'shizhi_sha',{'丙寅','庚申','甲辰','丁卯'}},
 {'caishengguan',{'戊辰','辛酉','甲寅','壬子'}},
 {'caizisha',{'戊辰','庚申','甲寅','癸卯'}},
 {'bijieduocai',{'甲寅','乙卯','甲辰','己丑'}},
 {'xiaoduo_shi',{'壬申','丙寅','甲辰','癸亥'}},
 {'guansha',{'庚申','辛酉','甲辰','戊寅'}},
 {'yinbi',{'壬子','甲寅','甲辰','癸亥'}},
}
assert(#M.combo_catalog==12,'twelve supported composite structures')
for _,case in ipairs(combos)do
 local result=assert(M.classify(case[2]));local c=result.combo
 assert(c and c.key==case[1],case[1]..' combo expected, got '..(c and c.key or 'nil'))
 assert(c.reason and c.confidence and #c.trace>=3,'composite gates explain the selected relationship')
 assert(c[1]==nil,'only one optional composite, not a bonus stack')
 local missing=R.copy(case[2])
 for i=1,4 do if i~=3 then
  for j,stem in ipairs(stems)do if missing[i]:sub(1,3)==stem then
   missing[i]=((j-1)%2==0 and '甲' or '乙')..missing[i]:sub(4,6);break
  end end
 end end
 local no_pair=assert(M.classify(missing))
 assert(not no_pair.combo or no_pair.combo.key~=case[1],'missing required visible relation rejects '..case[1])
end
local coappear=assert(M.classify({'辛未','癸卯','甲寅','丙午'}))
assert(not coappear.combo or coappear.combo.key~='guanyin','visible 官印 without roots is not 官印相生')
local wealth_month=assert(M.classify({'丙寅','戊辰','甲辰','壬子'}))
assert(not wealth_month.combo or wealth_month.combo.key~='shishengcai','财格逢食 does not automatically become 食神格生财')
local resource_month=assert(M.classify({'丙寅','癸亥','甲辰','壬子'}))
assert(not resource_month.combo or resource_month.combo.key~='xiaoduo_shi','偏印格透食 is not automatically 食神逢枭')
assert(M.classify({'戊子','戊戌','甲戌','戊戌'}).key~='cong_cai','substantial hidden 印 prevents 从财')
assert(M.classify({'丁酉','辛酉','乙酉','辛酉'}).key~='cong_sha','visible 食神 prevents 从杀')
local following=assert(M.classify({'辛酉','辛酉','乙酉','辛酉'}))
local follow_good=assert(M.decade_affinity(following,'辛酉'))
local follow_resource=assert(M.decade_affinity(following,'壬子'))
local follow_peer=assert(M.decade_affinity(following,'甲寅'))
assert(follow_good>0 and follow_resource<0 and follow_peer<0,'从杀顺势为正，复扶印比不能加分')
for _,case in ipairs(special)do
 local p=assert(M.classify(case[2]));local _,trace=M.decade_affinity(p,'甲子')
 local day=p.features.day_element_index;local resource=(day+4)%5
 if p.kind=='following' then
  assert(trace.element_affinity[day+1]==-1 and trace.element_affinity[resource+1]==-1,'all 从 categories reject restored 印比')
 elseif p.kind=='transform' and day~=p.features.anchor_element then
  assert(trace.element_affinity[day+1]==-1,'restoring independent old element works against 化')
  if resource~=p.features.anchor_element then assert(trace.element_affinity[resource+1]==-1,'old 印 support does not aid 化')end
 end
end
local water_transform=assert(M.classify({'壬子','辛亥','丙子','壬子'}))
assert(M.decade_affinity(water_transform,'壬子')>0,'化水 supported by water')
assert(M.decade_affinity(water_transform,'丙午')<0,'化水 opposed by restored original fire')
local wood_transform=assert(M.classify({'甲辰','乙卯','丁卯','壬寅'}))
local _,wood_trace=M.decade_affinity(wood_transform,'甲子')
assert(wood_trace.element_affinity[1]==1,'化神 equals original 印: retain selected 化神 support')
print('PASS 26 main categories, 14 special near misses, 12 composites, evidence and profile contract')
