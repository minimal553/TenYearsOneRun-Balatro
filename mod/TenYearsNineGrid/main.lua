local mod=SMODS.current_mod
assert(SMODS.load_file('resume.lua'))()()
local R=assert(SMODS.load_file('rules.lua'))()
local M=assert(SMODS.load_file('chart_patterns.lua'))()
local match=assert(SMODS.load_file('pattern_matcher.lua'))()(R,M)
local C=assert(SMODS.load_file('cycles.lua'))()(mod,R,M)
local P=assert(SMODS.load_file('presets.lua'))()(R,M,C)
mod.tyg_rules=R;mod.tyg_cycles=C;mod.tyg_patterns=M;mod.tyg_presets=P
assert(SMODS.load_file('assets.lua'))()
assert(SMODS.load_file('natal_jokers.lua'))()(mod,C)
mod.tyg_pattern_cards=assert(SMODS.load_file('pattern_jokers.lua'))()(mod,M)
assert(SMODS.load_file('fortunes.lua'))()(mod,C)
local Calendar=assert(SMODS.load_file('calendar.lua'))()(assert(SMODS.load_file('calendar_data.lua'))())
local I=assert(SMODS.load_file('birth_ui.lua'))()(mod,R,function(input)
 local raw,err=Calendar.calculate(input)
 if not raw then return nil,err end
 return match(raw)
end,C,P)
mod.tyg_birth=I;I.install_hooks();C.install_hooks()
-- Kept for continuing pre-0.4 saves; never granted by a new run.
local Packs=assert(SMODS.load_file('packs.lua'))()(mod,R)
SMODS.Back{
 key='mingju',atlas='deck',pos={x=0,y=0},unlocked=true,discovered=true,config={},
 loc_txt={name='十年一局·命局牌组',text={
  '开局选择{C:attention}九宫预设{}或{C:attention}输入生日{}',
  '预设固定两档；生日匹配{C:attention}专属小丑{}与大运',
  '目标为原版的{C:attention}1至2倍{}，每步获得一张{C:green}运签{}',
  '{C:attention}8{}阶段通关；每底注获运签，无尽沿用第8阶段',
  '{C:inactive}#1#{}','{C:inactive}#2#{}'}},
 loc_vars=function()
  local r=C.active()
  if r then
   local phase=C.phase(r,G.GAME.round_resets.ante)
   if r.mode=='preset'then return{vars={'九宫预设｜固定档挑战｜目标×'..phase.target_multiplier,
    '本命'..R.tier_names[r.natal_tier]..' · 运'..R.tier_names[phase.luck_tier]..'｜'..phase.reward_name..'签：'..phase.reward_text}}end
   return{vars={r.pattern_name..'｜第'..phase.decade..'运 '..phase.gan_zhi..'｜目标×'..phase.target_multiplier,
    phase.reward_name..'签：'..phase.reward_text..'；待发 '..(#r.pending_items+#r.pending_effects)}}
  end
  if G.GAME and G.GAME.tyg_run then return{vars={'正在继续0.3旧局：保留原局规则','新规则在下次新局生效'}}end
  return{vars={'九宫预设或输入生日，预览确认后开局','档次仅为游戏适配，不代表现实命运'}}
 end,
 apply=function(self,back)
  local p=assert(I.consume_profile(),'命局牌组需要先确认九宫预设或生日匹配')
  G.GAME.tyg_cycle=C.prepare_run(p);G.GAME.tyg_run=nil;G.GAME.win_ante=8
  back.effect.config.ante_scaling=1;back.effect.config.consumables={}
 end
}
local previous_update=Game.update
function Game:update(dt)
 I.install_hooks();C.install_hooks()
 previous_update(self,dt)
 I.update();C.update();Packs.update()
end
local function line(text,scale)
 return{n=G.UIT.R,config={align='cm',padding=.14},nodes={{n=G.UIT.T,config={text=text,scale=scale or .3,colour=G.C.UI.TEXT_LIGHT}}}}
end
mod.config_tab=function()
 return{n=G.UIT.ROOT,config={align='cm',minw=8,minh=4,padding=.25,r=.1,colour=G.C.BLACK},nodes={
  line('九宫预设／输入生日 · 双入口 · 九档运签',.4),
  line('新局选择命局牌组，再选择九宫预设或输入生日。'),
  line('九宫预设：本命上中下×运上中下，8阶段固定两档。'),
  line('预设统一常规命局小丑、无组合，推荐高牌／冥王星。'),
  line('生日入口：公历与北京时间，匹配26种格局起手。'),
  line('时间730、0730、7:30均可。匹配后从第一步大运开始。'),
  line('每升一底注发放运签；预设固定门槛，生日随大运变化。'),
  line('运签不是塔罗：它写什么，就生成什么。空位不足时排队。'),
  line('旧存档保留原牌与规则；双入口只在新局生效。'),
  line('游戏适配度模型，不是现实人生预测。',.26)
 }}
end
sendInfoMessage('Nine fixed presets and birthday chart matching registered (0.6.0)','TenYearsNineGrid')
