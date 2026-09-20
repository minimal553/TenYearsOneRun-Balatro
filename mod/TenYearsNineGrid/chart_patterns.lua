-- Versioned game taxonomy, not a prediction of a person's life.
-- Every stem/branch is evaluated; the day stem itself is not peer evidence.
local M={version='tyg-patterns-0.5.0',catalog={},by_key={}}
M.ordered=M.catalog
local stems={'甲','乙','丙','丁','戊','己','庚','辛','壬','癸'}
local branches={'子','丑','寅','卯','辰','巳','午','未','申','酉','戌','亥'}
local elements={'木','火','土','金','水'}
local gods={'bijian','jiecai','shishen','shangguan','piancai','zhengcai','qisha','zhengguan','pianyin','zhengyin'}
local god_names={bijian='比肩',jiecai='劫财',shishen='食神',shangguan='伤官',piancai='偏财',zhengcai='正财',
 qisha='七杀',zhengguan='正官',pianyin='偏印',zhengyin='正印'}
local stem_index,branch_index={},{}
for i,s in ipairs(stems)do stem_index[s]=i-1 end
for i,b in ipairs(branches)do branch_index[b]=i-1 end
-- Each branch totals ten; order is 本/中/余气. 午、亥 use 7:3.
local hidden={
 {{9,10}},{{5,6},{9,3},{7,1}},{{0,6},{2,3},{4,1}},{{1,10}},
 {{4,6},{1,3},{9,1}},{{2,6},{4,3},{6,1}},{{3,7},{5,3}},{{5,6},{3,3},{1,1}},
 {{6,6},{8,3},{4,1}},{{7,10}},{{4,6},{7,3},{3,1}},{{8,7},{0,3}}}
local lu={2,3,5,6,5,6,8,9,11,0}
local blade={[0]=3,[2]=6,[4]=6,[6]=9,[8]=0}
local definitions={
 {'zhengguan','正官格','ordinary','c_pluto'},{'qisha','七杀格','ordinary','c_pluto'},
 {'zhengcai','正财格','ordinary','c_venus'},{'piancai','偏财格','ordinary','c_venus'},
 {'zhengyin','正印格','ordinary','c_jupiter'},{'pianyin','偏印格','ordinary','c_jupiter'},
 {'shishen','食神格','ordinary','c_saturn'},{'shangguan','伤官格','ordinary','c_saturn'},
 {'jianlu','建禄格','month_peer','c_mercury'},{'yuejie','月劫格','month_peer','c_mercury'},
 {'yangren','阳刃格','month_peer','c_mercury'},
 {'cong_cai','从财格','following','c_venus'},{'cong_sha','从杀格','following','c_pluto'},
 {'cong_er','从儿格','following','c_saturn'},{'cong_shi','从势格','following','c_saturn'},
 {'quzhi','曲直格','dominant','c_jupiter'},{'yanshang','炎上格','dominant','c_jupiter'},
 {'jiase','稼穑格','dominant','c_venus'},{'congge','从革格','dominant','c_mercury'},
 {'runxia','润下格','dominant','c_saturn'},
 {'hua_tu','化土格','transform','c_venus'},{'hua_jin','化金格','transform','c_mercury'},
 {'hua_shui','化水格','transform','c_saturn'},{'hua_mu','化木格','transform','c_jupiter'},
 {'hua_huo','化火格','transform','c_pluto'},{'changgui','常规命局','general','c_pluto'}}
for _,d in ipairs(definitions)do
 local row={key=d[1],name=d[2],family=d[3],planet_key=d[4],joker_key='j_tyg_mp_'..d[1]}
 M.catalog[#M.catalog+1]=row;M.by_key[row.key]=row
end
local function element(s)return math.floor(s/2)end
local function ten_god(day,other)
 local delta=(element(other)-element(day))%5
 local same=day%2==other%2
 return gods[delta*2+(same and 1 or 2)]
end
function M.ten_god(day,other)
 if stem_index[day]==nil or stem_index[other]==nil then return nil end
 return ten_god(stem_index[day],stem_index[other])
end
local function parts(pillar)
 if type(pillar)~='string' or #pillar~=6 then return nil end
 local s,b=stem_index[pillar:sub(1,3)],branch_index[pillar:sub(4,6)]
 if s==nil or b==nil or s%2~=b%2 then return nil end
 return s,b
end
local function game_grade(f)
 local rooted,flow=0,0
 for i,s in ipairs(f.stem_indices)do
  if i~=3 and f.root_elements[element(s)+1]>=6 then rooted=rooted+1 end
 end
 for e=0,4 do if f.elements[e+1]>=12 and f.elements[(e+1)%5+1]>=12 then flow=flow+1 end end
 local main_visible=f.visible_stems[f.month.main_stem]>0
 local score=50+rooted*6+math.min(12,flow*4)+(main_visible and 6 or 0)
 score=score-math.min(14,#f.clashes*3+(f.month_clashed and 8 or 0))
 f.game_grade={version=M.version,score=score,rooted_visible=rooted,flow_links=flow,
  month_main_visible=main_visible,clash_count=#f.clashes,
  explanation='游戏结构分：透干根气、五行相生环节与支冲；不按格名评吉凶'}
 return score>=72 and 1 or(score>=57 and 2 or 3)
end
function M.analyze(chart)
 if type(chart)~='table' or #chart~=4 then return nil,'须提供四个有效干支柱' end
 local ss,bb={},{}
 for i=1,4 do
  local s,b=parts(chart[i]);if s==nil then return nil,'第'..i..'柱干支或阴阳配对无效' end
  ss[i],bb[i]=s,b
 end
 local day=ss[3]
 local f={day_stem=stems[day+1],day_element=elements[element(day)+1],day_element_index=element(day),
  stem_indices=ss,branch_indices=bb,gods={},visible={},roots={},visible_stems={},
  elements={0,0,0,0,0},root_elements={0,0,0,0,0},element_visible={0,0,0,0,0},
  root_branches={0,0,0,0,0},hidden={},clashes={},total_weight=80}
 for _,g in ipairs(gods)do f.gods[g]=0;f.visible[g]=0;f.roots[g]=0 end
 for _,s in ipairs(stems)do f.visible_stems[s]=0 end
 for i,s in ipairs(ss)do
  if i~=3 then
   local g,e=ten_god(day,s),element(s)+1
   f.gods[g]=f.gods[g]+10;f.visible[g]=f.visible[g]+1
   f.visible_stems[stems[s+1]]=f.visible_stems[stems[s+1]]+1
   f.elements[e]=f.elements[e]+10;f.element_visible[e]=f.element_visible[e]+1
  end
  f.hidden[i]={};local found={}
  for rank,h in ipairs(hidden[bb[i]+1])do
   local g,e,w=ten_god(day,h[1]),element(h[1])+1,h[2]*(i==2 and 2 or 1)
   f.gods[g]=f.gods[g]+w;f.roots[g]=f.roots[g]+w
   f.elements[e]=f.elements[e]+w;f.root_elements[e]=f.root_elements[e]+w
   f.hidden[i][rank]={stem=stems[h[1]+1],god=g,weight=w,rank=rank,element=elements[e]}
   found[e]=true
  end
  for e in pairs(found)do f.root_branches[e]=f.root_branches[e]+1 end
 end
 for i=1,3 do for j=i+1,4 do
  if (bb[i]-bb[j])%12==6 then
   f.clashes[#f.clashes+1]={left=i,right=j,branches=branches[bb[i]+1]..branches[bb[j]+1]}
   if i==2 or j==2 then f.month_clashed=true end
  end
 end end
 f.month_clashed=f.month_clashed or false
 f.month={branch=branches[bb[2]+1],main_stem=f.hidden[2][1].stem,main_god=f.hidden[2][1].god,
  main_element=element(hidden[bb[2]+1][1][1]),hidden=f.hidden[2]}
 f.groups={peer=f.gods.bijian+f.gods.jiecai,output=f.gods.shishen+f.gods.shangguan,
  wealth=f.gods.piancai+f.gods.zhengcai,authority=f.gods.qisha+f.gods.zhengguan,
  resource=f.gods.pianyin+f.gods.zhengyin}
 f.support_share=(f.groups.peer+f.groups.resource)/80
 f.natal_tier=game_grade(f)
 return f
end
local function ordinary(f)
 local day,month=f.stem_indices[3],f.branch_indices[2]
 if month==lu[day+1] then return 'jianlu','明确匹配',{'月令为日干临官禄位','戊己采用寄火建禄规则'} end
 if month==blade[day] then return 'yangren','明确匹配',{'阳日干逢本规则月刃','仅五阳干取阳刃'} end
 if f.month.main_god=='bijian' or f.month.main_god=='jiecai' then
  return 'yuejie','明确匹配',{'月令本气属比劫','未归入建禄或阳刃'}
 end
 local candidates={}
 for _,h in ipairs(f.hidden[2])do
  if h.god~='bijian' and h.god~='jiecai' and f.visible_stems[h.stem]>0 then
   candidates[#candidates+1]=h
   if h.rank==1 then
    f.month.selected_stem=h.stem
    return h.god,'明确匹配',{'月令本气'..h.stem..'透干','据月令取'..god_names[h.god]}
   end
  end
 end
 if #candidates==1 then
  local h=candidates[1];f.month.selected_stem=h.stem
  return h.god,'明确匹配',{'月令藏'..h.stem..'且透干','本气未透，取唯一透出藏干'}
 end
 if #candidates>1 then
  return 'changgui','常规归类',{'月令多项藏干同时透出','无唯一取格依据，保留常规命局'}
 end
 f.month.selected_stem=f.month.main_stem
 return f.month.main_god,'倾向',{'月令藏干未透出','依本气'..f.month.main_stem..'作游戏归类'}
end
-- Special patterns are AND gates, not nearest-template scores.
local transform_keys={'hua_tu','hua_jin','hua_shui','hua_mu','hua_huo'}
local transform_elements={2,3,4,0,1}
local dominant_keys={'quzhi','yanshang','jiase','congge','runxia'}
local formations={
 {{{2,3,4},'寅卯辰'},{{11,3,7},'亥卯未'}},
 {{{5,6,7},'巳午未'},{{2,6,10},'寅午戌'}},
 {},
 {{{8,9,10},'申酉戌'},{{5,9,1},'巳酉丑'}},
 {{{11,0,1},'亥子丑'},{{8,0,4},'申子辰'}}}
local function gates(f,key,list)
 local pass=true
 for _,g in ipairs(list)do if not g.pass then pass=false end end
 f.special_checks[key]={passed=pass,gates=list}
 return pass
end
local function gate(id,pass,value,required)return {id=id,pass=pass,value=value,required=required}end
local function special(f)
 f.special_checks={}
 local day,e=f.stem_indices[3],f.day_element_index
 local slot=day%5+1
 local target,key=transform_elements[slot],transform_keys[slot]
 local partner=(day+5)%10
 local partners=f.visible_stems[stems[partner+1]]
 local adjacent=f.stem_indices[2]==partner or f.stem_indices[4]==partner
 local controller=(target+3)%5
 local chemical=gates(f,key,{
  gate('one_adjacent_partner',partners==1 and adjacent,partners,'月或时唯一合干'),
  gate('no_competing_day_stem',f.visible_stems[f.day_stem]==0,f.visible_stems[f.day_stem],'无同日干争合'),
  gate('target_in_season',f.month.main_element==target,f.month.main_element,'化神为月令本气'),
  gate('target_weight',f.elements[target+1]>=40,f.elements[target+1],'>=40/80'),
  gate('target_visible_rooted',f.element_visible[target+1]>=1 and f.root_branches[target+1]>=2,
   f.root_branches[target+1],'化神透干且至少两支有根'),
  gate('old_element_micro_root',e==target or f.root_elements[e+1]<=6,f.root_elements[e+1],'异于化神的原气根<=6'),
  gate('no_target_controller',f.element_visible[controller+1]==0 and f.elements[controller+1]<=8,
   f.elements[controller+1],'克化神不透且<=8'),
  gate('month_unclashed',not f.month_clashed,f.month_clashed,'月支无六冲')})
 local present={};for _,b in ipairs(f.branch_indices)do present[b]=true end
 local formation
 if e==2 then
  local count=0;for _,b in ipairs({1,4,7,10})do if present[b] then count=count+1 end end
  if count>=3 then formation='三种以上季土支' end
 else
  for _,set in ipairs(formations[e+1])do
   local all=true;for _,b in ipairs(set[1])do if not present[b] then all=false end end
   if all then formation=set[2];break end
  end
 end
 local own,resource,control=f.elements[e+1],f.elements[(e+4)%5+1],(e+3)%5
 local dominant=gates(f,dominant_keys[e+1],{
  gate('full_branch_formation',formation~=nil,formation or '不全','完整三合/三会；土为三种季土'),
  gate('own_in_season',f.month.main_element==e,f.month.main_element,'日元同类当月令'),
  gate('own_dominance',own>=48,own,'>=48/80'),
  gate('own_resource_share',own+resource>=60,own+resource,'同类与生助>=60/80'),
  gate('multiple_roots',f.root_branches[e+1]>=3,f.root_branches[e+1],'>=3支'),
  gate('no_visible_controller',f.element_visible[control+1]==0 and f.elements[control+1]<=10,
   f.elements[control+1],'克日元不透且<=10'),
  gate('month_unclashed',not f.month_clashed,f.month_clashed,'月支无六冲')})
 local g,v=f.groups,f.visible
 local support=g.peer+g.resource
 local visible_support=v.bijian+v.jiecai+v.pianyin+v.zhengyin
 local month_delta=(f.month.main_element-e)%5
 local function following(k,extra)
  local list={
   gate('no_day_root',f.root_elements[e+1]==0,f.root_elements[e+1],'日元各支无根'),
   gate('no_visible_support',visible_support==0,visible_support,'比劫印不透'),
   gate('micro_support_only',support<=4,support,'比劫印合计<=4/80'),
   gate('outward_month',month_delta>=1 and month_delta<=3,month_delta,'月令食伤/财/官杀')}
  for _,row in ipairs(extra)do list[#list+1]=row end
  return gates(f,k,list)
 end
 local wealth=following('cong_cai',{
  gate('wealth_month',month_delta==2,month_delta,'财当令'),
  gate('wealth_dominance',g.wealth>=44 and g.wealth>=1.5*math.max(g.output,g.authority),g.wealth,'财>=44且显著主导'),
  gate('wealth_visible',v.piancai+v.zhengcai>=2,v.piancai+v.zhengcai,'至少两财透干')})
 local killing=following('cong_sha',{
  gate('authority_month',month_delta==3,month_delta,'官杀当令'),
  gate('killing_dominance',g.authority>=44 and f.gods.qisha>=36 and f.gods.qisha>=3*f.gods.zhengguan,
   f.gods.qisha,'官杀>=44；七杀>=36且>=3倍正官'),
  gate('killing_visible',v.qisha>=2,v.qisha,'至少两七杀透干'),
  gate('no_output_control',g.output<=8,g.output,'食伤制杀<=8')})
 local output=following('cong_er',{
  gate('output_month',month_delta==1,month_delta,'食伤当令'),
  gate('output_dominance',g.output>=44,g.output,'食伤>=44/80'),
  gate('output_visible',v.shishen+v.shangguan>=2,v.shishen+v.shangguan,'至少两食伤透干'),
  gate('wealth_outlet',g.wealth>=6,g.wealth,'有财流通>=6'),
  gate('no_authority_conflict',g.authority<=4,g.authority,'官杀<=4')})
 local groups=0;for _,weight in ipairs({g.output,g.wealth,g.authority})do if weight>=20 then groups=groups+1 end end
 local momentum=following('cong_shi',{
  gate('multiple_outward_groups',groups>=2,groups,'至少两类食伤财官>=20'),
  gate('no_single_dominance',math.max(g.output,g.wealth,g.authority)<44,math.max(g.output,g.wealth,g.authority),'单类<44'),
  gate('wealth_bridge',g.wealth>=12 and ((g.output>=20 and g.wealth>=20) or (g.wealth>=20 and g.authority>=20)),
   g.wealth,'财连接相邻两类势力')})
 if chemical then f.anchor_element=target;return key,{'日干相合且化神当令','化神透根、原气微弱；按游戏阈值取倾向'} end
 if dominant then f.anchor_element=e;return dominant_keys[e+1],{formation..'成局且当令','同类集中、无显露克制；按专旺倾向归类'} end
 if wealth then f.anchor_element=(e+2)%5;return 'cong_cai',{'日元无根且无透干扶助','财当令、透干并主导；按从财倾向归类'} end
 if killing then f.anchor_element=(e+3)%5;return 'cong_sha',{'日元无根且无透干扶助','七杀当令主导、制杀微弱；按从杀倾向归类'} end
 if output then f.anchor_element=(e+1)%5;return 'cong_er',{'日元无根且无透干扶助','食伤主导并有财流通；按从儿倾向归类'} end
 if momentum then f.anchor_element=(e+2)%5;return 'cong_shi',{'日元无根且无透干扶助','食伤财官多方顺接；按从势倾向归类'} end
end
M.combo_catalog={
 {key='guanyin',name='官印相生'},{key='shayin',name='杀印相生'},
 {key='shishengcai',name='食神生财'},{key='shangshengcai',name='伤官生财'},
 {key='shangpeiyin',name='伤官配印'},{key='shizhi_sha',name='食神制杀'},
 {key='caishengguan',name='财生官'},{key='caizisha',name='财滋七杀'},
 {key='bijieduocai',name='比劫夺财'},{key='xiaoduo_shi',name='枭印夺食'},
 {key='guansha',name='官杀并见'},{key='yinbi',name='印比相扶'}}
local function composite(f,kind,primary)
 f.combo_candidates={}
 if kind=='transform' or kind=='dominant' or kind=='following' then
  f.combo_policy='特殊主格不叠加普通十神复合加成';return nil
 end
 local g,w,v=f.groups,f.gods,f.visible
 local function strong(k)return v[k]>=1 and f.roots[k]>=3 and w[k]>=13 end
 local function first(list)for _,k in ipairs(list)do if strong(k) then return k end end end
 local wealth=first({'zhengcai','piancai'})
 local resource=first({'zhengyin','pianyin'})
 local peer=first({'bijian','jiecai'})
 local support=g.peer+g.resource
 local own_root=f.root_elements[f.day_element_index+1]
 local no_wealth=v.zhengcai+v.piancai==0
 -- Related stars cannot rename an unrelated month-led structure. Month-peer
 -- patterns may borrow a rooted external flow, as documented in the policy.
 local month_bases={
  {zhengguan=true},{qisha=true,zhengyin=true,pianyin=true},
  {shishen=true},{shangguan=true},{shangguan=true},{qisha=true,shishen=true},
  {zhengguan=true,zhengcai=true,piancai=true},{qisha=true},
  {zhengcai=true,piancai=true},{shishen=true},
  {zhengguan=true,qisha=true},{zhengyin=true,pianyin=true}}
 local candidates={
  {strong('zhengguan') and strong('zhengyin') and not strong('qisha') and v.shangguan==0
    and (no_wealth or g.wealth<g.resource),'zhengguan','zhengyin','官印透干有根，避伤官与财坏印'},
  {strong('qisha') and resource and not strong('shishen') and (no_wealth or g.wealth<=g.resource),
    'qisha',resource,'杀印透干有根，避食神与财破印'},
  {strong('shishen') and wealth and support>=16 and not strong('pianyin'),
    'shishen',wealth,'食财透干有根，日元有扶助且无有力枭印'},
  {strong('shangguan') and wealth and support>=16 and v.zhengguan==0 and not strong('zhengyin'),
    'shangguan',wealth,'伤财透干有根，避见官与配印争用'},
  {strong('shangguan') and strong('zhengyin') and support>=20 and no_wealth and v.qisha==0
    and w.zhengyin>=0.5*w.shangguan and w.zhengyin<=2.5*w.shangguan,
    'shangguan','zhengyin','伤印透干有根、力量相应，避财杀争用'},
  {strong('shishen') and strong('qisha') and own_root>=3 and v.pianyin==0 and no_wealth,
    'shishen','qisha','食杀透干有根，日元有根，避枭财干扰'},
  {wealth and strong('zhengguan') and support>=16 and v.shangguan==0 and v.qisha==0,
    wealth,'zhengguan','财官透干有根、日元有扶助，避伤杀'},
  {wealth and strong('qisha') and own_root>=3 and support>=20 and v.shishen==0 and v.zhengguan==0,
    wealth,'qisha','财杀透干有根且日元有承接，避食官'},
  {peer and wealth and g.peer>=24 and g.peer>=1.3*g.wealth and v.zhengguan+v.qisha==0
    and v.shishen+v.shangguan==0,peer,wealth,'比劫有力逾财，无官杀约束或食伤通关'},
  {strong('pianyin') and strong('shishen') and w.pianyin>=0.8*w.shishen and no_wealth,
    'pianyin','shishen','枭食透干有根，枭有制食之力且无财解'},
  {strong('zhengguan') and strong('qisha') and v.zhengyin+v.pianyin+v.shishen==0,
    'zhengguan','qisha','官杀均透且有根，未见明确印化或食制'},
  {resource and peer and support>=40 and no_wealth and v.zhengguan+v.qisha==0 and g.output<=16,
    resource,peer,'印比透干有根并占半数，避财官与过度泄耗'}}
 local function evidence(k)return god_names[k]..'：透'..v[k]..'、根'..f.roots[k]..'、权重'..w[k] end
 for i,c in ipairs(candidates)do
  if c[1] and (kind=='month_peer' or month_bases[i][primary]) then
   local row=M.combo_catalog[i]
   f.combo_candidates[#f.combo_candidates+1]={key=row.key,name=row.name,reason=c[4],
    confidence='结构条件满足',trace={evidence(c[2]),evidence(c[3]),c[4],
     '月令主格：'..M.by_key[primary].name,'仅选一个复合局；固定目录顺序优先'}}
  end
 end
 f.combo_policy='先验月令主格，再查透干>=1、藏根>=3、权重>=13与关系排除；固定目录选首项'
 return f.combo_candidates[1]
end
function M.classify(chart)
 local f,err=M.analyze(chart);if not f then return nil,err end
 local key,reasons=special(f)
 local status='倾向'
 if not key then key,status,reasons=ordinary(f) end
 local row=M.by_key[key]
 if not f.anchor_element then
  f.anchor_element=f.month.selected_stem and element(stem_index[f.month.selected_stem]) or f.month.main_element
 end
 return {version=M.version,key=key,name=row.name,kind=row.family,status=status,reasons=reasons,
  combo=composite(f,row.family,key),features=f,natal_tier=f.natal_tier}
end
-- Decade affinity follows the selected pattern's support/flow relation.
-- It deliberately shares neither old five-template routing nor its targets.
function M.decade_affinity(result,pillar)
 local s,b=parts(pillar);if s==nil then return nil,'大运干支无效' end
 local f,weights=result.features,{0,0,0,0,0}
 weights[element(s)+1]=10
 for _,h in ipairs(hidden[b+1])do weights[element(h[1])+1]=weights[element(h[1])+1]+h[2] end
 local anchor=f.anchor_element or f.month.main_element
 local values={}
 for e=0,4 do
  local delta=(e-anchor)%5
  values[e+1]=({1,0.5,0,-1,1})[delta+1]
 end
 if result.kind=='month_peer' then
  for e=0,4 do values[e+1]=({-0.5,1,1,0.5,-1})[(e-f.day_element_index)%5+1] end
 end
 local qualifier=''
 if result.kind=='following' then
  values[f.day_element_index+1]=-1
  values[(f.day_element_index+4)%5+1]=-1
  qualifier='；印比复扶逆从势'
 elseif result.kind=='transform' and f.day_element_index~=anchor then
  values[f.day_element_index+1]=-1
  local old_resource=(f.day_element_index+4)%5
  if old_resource~=anchor then values[old_resource+1]=-1 end
  qualifier='；原气复强逆化势'
 end
 local score=0;for i=1,5 do score=score+weights[i]*values[i]/20 end
 local clash=(b-f.branch_indices[2])%12==6
 if clash then score=score-0.25 end
 score=math.max(-1,math.min(1,score))
 return score,{anchor_element=elements[anchor+1],weights=weights,element_affinity=values,
  month_clash=clash,reason='按主格支援与流通计分'..qualifier..(clash and '；大运冲月支扣分' or '')}
end
return M
