"""Exercise gift lifecycle using installed native Lua callback implementations.

Loads Card.open/use_consumeable/can_use_consumeable, use_card, skip_booster,
end_consumeable, draw_from_hand_to_deck and Steamodded update_pack unchanged.
Graphics, persistence I/O and event timing are headless adapters. It does not
launch or control the game, read saved games, or claim rendered UI coverage.
"""
import argparse
import os
from pathlib import Path

from calendar_lua_bridge import LuaCalendar, quote


def between(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


BOOTSTRAP = r'''
registry={};events={};saves={};contexts={};hand_returns=0;planet_adds=0
G={FUNCS={},GAME={},P_CENTERS={},P_CARDS={empty={}},CARD_W=1,CARD_H=1,
 SETTINGS={paused=false,GAMESPEED=1},ROOM={T={x=0,y=0,w=20,h=20},jiggle=0},
 C={WHITE={1,1,1,1}},CONTROLLER={locks={},interrupt={}},
 STATES={SHOP=1,BLIND_SELECT=2,SELECTING_HAND=3,PLAY_TAROT=4,
 TAROT_PACK=5,PLANET_PACK=6,SPECTRAL_PACK=7,STANDARD_PACK=8,BUFFOON_PACK=9,
 SMODS_BOOSTER_OPENED=10,HAND_PLAYED=11,DRAW_TO_HAND=12}}
function G.CONTROLLER:recall_cardarea_focus()end
function G.CONTROLLER:snap_to()end
G.E_MANAGER={add_event=function(self,e)events[#events+1]=e end}
function Event(e)return e end
function flush()
 local count=0
 while #events>0 do
  count=count+1;assert(count<1000,'event queue must settle')
  local e=table.remove(events,1)
  if e.func and not e.func()then events[#events+1]=e end
 end
 G.GAME.STOP_USE=0
end
function copy_table(t)
 if type(t)~='table'then return t end
 local r={};for k,v in pairs(t)do r[k]=copy_table(v)end;return r
end
function area()
 local a={cards={},highlighted={},config={card_limit=8},T={x=0,y=0,w=8,h=1},VT={y=0}}
 function a:emplace(c)self.cards[#self.cards+1]=c;c.area=self end
 function a:remove_card(c)
  for i=#self.cards,1,-1 do if self.cards[i]==c then table.remove(self.cards,i)end end
  if c.area==self then c.area=nil end
 end
 function a:remove_from_highlighted(c)
  for i=#self.highlighted,1,-1 do if self.highlighted[i]==c then table.remove(self.highlighted,i)end end
 end
 return a
end
Card={};Card.__index=Card
setmetatable(Card,{__call=function(_,x,y,w,h,front,center,args)
 local c=setmetatable({config={center=center,center_key=center.key},
  ability={set=center.set,name=center.name or center.key,extra=3,choose=1,
   consumeable=center.set=='Tarot'and{}or nil},
  T={x=x or 0,y=y or 0,w=w or 1,h=h or 1},states={hover={can=true}},children={},cost=0},Card)
 return c
end})
function Card:remove()if self.area then self.area:remove_card(self)end;self.removed=true end
function Card:explode()self:remove()end
function Card:start_materialize()end
function Card:start_dissolve()self:remove()end
function Card:remove_from_deck()self.removed_from_deck=true end
function Card:add_to_deck()self.added_to_deck=true end
function Card:selectable_from_pack()return false end
function Card:is(class)return class==Card end
function draw_card(from,to,p,d,s,c)
 c=c or from.cards[#from.cards]
 if c then
  if from==G.hand and to==G.deck then hand_returns=hand_returns+1 end
  from:remove_card(c);to:emplace(c)
 end
end
function stop_use()G.GAME.STOP_USE=1 end
function delay()end
function play_sound()end
function set_consumeable_usage()end
function discover_card()end
function ease_background_colour_blind()end
function save_run()
 if G.STATE==G.STATES.SMODS_BOOSTER_OPENED then return end
 saves[#saves+1]={state=G.STATE,run=copy_table(G.GAME.tyg_run),
  hand=#G.hand.cards,deck=#G.deck.cards,tickets=#G.consumeables.cards,jokers=#G.jokers.cards}
end
function UIBox(args)
 return {alignment={offset={x=0,y=0}},remove=function(self)self.removed=true end}
end
function pseudoseed(x)return x end
function pseudorandom_element(pool)return pool[1]end
function get_current_pool()return {'j_test_a','j_test_b','j_test_c'}end
SMODS={Centers={},Booster={},current_mod={}}
function SMODS.calculate_context(c)contexts[#contexts+1]=c;return{}end
function SMODS.create_card(args)return Card(0,0,1,1,nil,G.P_CENTERS[args.key])end
function SMODS.add_card(args)
 planet_adds=planet_adds+1
 local c=Card(0,0,1,1,nil,{key=args.key,set='Planet'});args.area:emplace(c);return c
end
function SMODS.Consumable(v)
 v.key='c_tyg_'..v.key;v.name=v.key;registry[v.key]=v;G.P_CENTERS[v.key]=v
end
function SMODS.Atlas()end
setmetatable(SMODS.Booster,{__call=function(_,v)
 v.key='p_tyg_'..v.key;v.set='Booster';v.name=v.key
 v.ease_background_colour=function()end
 registry[v.key]=v;G.P_CENTERS[v.key]=v;SMODS.Centers[v.key]=v
end})
function SMODS.Booster.create_UIBox()G.pack_cards=area();return{}end
function reset(origin)
 events={};saves={};contexts={};hand_returns=0;planet_adds=0
 G.STATE=origin;G.STATE_COMPLETE=true;G.booster_pack=nil;G.pack_cards=nil
 G.TAROT_INTERRUPT=nil;SMODS.OPENED_BOOSTER=nil;booster_obj=nil
 G.CONTROLLER.locks={};G.CONTROLLER.locked=false
 G.GAME={modifiers={},tags={},round_scores={cards_purchased={amt=0}},
  current_round={used_packs={},hands_left=4,discards_left=3},
  tyg_run={rarity=3,gift_state='unclaimed',planets_pending=2,route={planet_key='c_jupiter'}}}
 G.hand=area();G.deck=area();G.play=area();G.discard=area();G.jokers=area();G.consumeables=area()
 G.jokers.config.card_limit=5;G.consumeables.config.card_limit=2
 if origin==G.STATES.SELECTING_HAND then
  for i=1,8 do G.hand:emplace(Card(0,0,1,1,nil,{key='hand_'..i,set='Default'}))end
  for i=1,10 do G.deck:emplace(Card(0,0,1,1,nil,{key='deck_'..i,set='Default'}))end
  G.hand.highlighted={G.hand.cards[2],G.hand.cards[6]}
 end
 local token=Card(0,0,1,1,nil,registry.c_tyg_gift);G.consumeables:emplace(token)
 return token
end
'''


CHECKS = r'''
for _,origin in ipairs({G.STATES.SELECTING_HAND,G.STATES.BLIND_SELECT,G.STATES.SHOP})do
 for _,choice in ipairs({'select','skip'})do
  local token=reset(origin)
  local old_hand={};for i,c in ipairs(G.hand.cards)do old_hand[i]=c end
  local old_deck={};for i,c in ipairs(G.deck.cards)do old_deck[i]=c end
  assert(token:can_use_consumeable(),'gift must work at eligible stable origin '..origin)
  G.FUNCS.use_card({config={ref_table=token}})
  assert(G.GAME.tyg_run.gift_state=='pending','native use requests one pending gift')
  assert(G.STATE==G.STATES.PLAY_TAROT,'native consumable animation owns state first')
  P.update();assert(not SMODS.OPENED_BOOSTER,'must wait for native state restoration')
  flush();assert(G.STATE==origin,'native consumable restores exact previous state')
  P.update()
  assert(G.STATE==G.STATES.SMODS_BOOSTER_OPENED,'native Card.open enters real booster state')
  assert(G.GAME.PACK_INTERRUPT==origin,'native use_card saves exact interrupt state')
  local opened=SMODS.OPENED_BOOSTER
  assert(opened and G.GAME.tyg_run.gift_state=='opened','gift enters opened once')
  assert(token.removed_from_deck and token.removed,'ticket removed only after open')
  assert(saves[1].run.gift_state=='pending'and saves[1].tickets==1,
   'recoverable save retains ticket before booster opens')
  assert(#saves[1].run.gift_keys==3,'save freezes candidates')
  opened.config.center:update_pack(.016);flush()
  assert(#G.pack_cards.cards==3,'native Card.open creates exact three candidates')
  assert(G.GAME.pack_choices==1,'exactly one native pick')
  P.update();assert(planet_adds==0,'planet rewards wait for close')
  local duplicate=Card(0,0,1,1,nil,registry.c_tyg_gift)
  assert(not duplicate:can_use_consumeable(),'copied ticket cannot claim again')
  if choice=='select'then
   G.FUNCS.use_card({config={ref_table=G.pack_cards.cards[1]}})
  else G.FUNCS.skip_booster({})end
  flush()
  assert(G.STATE==origin and G.GAME.PACK_INTERRUPT==nil,'native close restores origin')
  assert(#G.jokers.cards==(choice=='select'and 1 or 0),'selected Joker granted once; skip grants none')
  assert(#G.hand.cards==#old_hand,'native close must preserve the playing hand')
  assert(#G.deck.cards==#old_deck,'native close must not move playing cards into deck')
  for i,c in ipairs(old_hand)do assert(G.hand.cards[i]==c,'hand identity and order preserved')end
  for i,c in ipairs(old_deck)do assert(G.deck.cards[i]==c,'deck identity and order preserved')end
  if origin==G.STATES.SELECTING_HAND then
   assert(G.hand.highlighted[1]==old_hand[2]and G.hand.highlighted[2]==old_hand[6],
    'existing hand selection remains intact')
  end
  assert(G.GAME.current_round.hands_left==4 and G.GAME.current_round.discards_left==3,
   'gift does not spend play or discard counters')
  P.update();assert(G.GAME.tyg_run.gift_state=='complete','close completes claim')
  assert(planet_adds==2,'two planets delivered after close')
  P.update();assert(planet_adds==2,'no repeated planet delivery')
  assert(not duplicate:can_use_consumeable(),'completed gift cannot be reclaimed')
 end
end

-- Recover the stable pending snapshot without generating a different offer.
local token=reset(G.STATES.SELECTING_HAND)
G.FUNCS.use_card({config={ref_table=token}});flush();P.update()
local pending=copy_table(saves[1])
reset(pending.state);G.GAME.tyg_run=copy_table(pending.run)
local random=pseudorandom_element
pseudorandom_element=function()error('pending save must not reroll gift')end
P.update();pseudorandom_element=random
assert(G.STATE==G.STATES.SMODS_BOOSTER_OPENED,'saved pending resumes its gift')
for i,key in ipairs(pending.run.gift_keys)do
 assert(SMODS.OPENED_BOOSTER.ability.tyg_candidates[i]==key,'reload preserves candidate order')
end
SMODS.OPENED_BOOSTER.config.center:update_pack(.016);flush()
G.FUNCS.skip_booster({});flush();P.update()
assert(#G.hand.cards==8 and G.GAME.tyg_run.gift_state=='complete',
 'resumed gift closes safely and reaches complete')
assert(planet_adds==2,'resumed gift grants queued planets once')

-- Calling the unchanged native close must still return hands for ordinary packs.
reset(G.STATES.SELECTING_HAND)
G.STATE=G.STATES.SMODS_BOOSTER_OPENED;G.GAME.PACK_INTERRUPT=G.STATES.SELECTING_HAND
SMODS.OPENED_BOOSTER=Card(0,0,1,1,nil,{key='p_other_mod',set='Booster'})
SMODS.OPENED_BOOSTER.ability.tyg_preserve_hand=true
G.booster_pack=UIBox({});G.pack_cards=area()
G.FUNCS.end_consumeable();flush()
assert(#G.hand.cards==0 and #G.deck.cards==18 and hand_returns==8,
 'ordinary boosters preserve their native hand-return behavior')

-- A stale opened booster, missing preserve flag or different origin must not
-- intercept a genuine future return-to-deck request.
for _,boundary in ipairs({'stale','no_flag','other_origin'})do
 reset(G.STATES.SELECTING_HAND)
 G.STATE=G.STATES.SMODS_BOOSTER_OPENED;G.GAME.PACK_INTERRUPT=G.STATES.SELECTING_HAND
 SMODS.OPENED_BOOSTER=Card(0,0,1,1,nil,registry.p_tyg_gift_rare)
 SMODS.OPENED_BOOSTER.ability.tyg_preserve_hand=true
 if boundary=='stale'then G.STATE=G.STATES.SELECTING_HAND end
 if boundary=='no_flag'then SMODS.OPENED_BOOSTER.ability.tyg_preserve_hand=nil end
 if boundary=='other_origin'then G.GAME.PACK_INTERRUPT=G.STATES.SHOP end
 G.FUNCS.draw_from_hand_to_deck()
 assert(#G.hand.cards==0 and hand_returns==8,'hand guard must not leak: '..boundary)
end

-- The actual vanilla Emperor rules continue to accept/reject inventory normally.
reset(G.STATES.SELECTING_HAND)
local emperor=Card(0,0,1,1,nil,{key='c_emperor',set='Tarot',name='The Emperor'})
assert(emperor:can_use_consumeable(),'ordinary Emperor works with free consumable slot')
G.consumeables.config.card_limit=1
assert(not emperor:can_use_consumeable(),'Emperor outside inventory still needs space')
G.consumeables:emplace(emperor)
assert(emperor:can_use_consumeable(),'held Emperor can use its own occupied slot')
G.GAME.STOP_USE=1
assert(not emperor:can_use_consumeable(),'native animation lock still blocks Emperor')
print('PASS native gift lifecycle: 3 origins x select/skip, hand/deck identity, save/reload, rewards, guard boundaries, other booster, Emperor')
print('LIMIT: graphics, event timing and disk persistence are adapters; no live game was operated.')
'''


def check(mod, dump, smods):
    card = (dump / 'card.lua').read_text(encoding='utf-8')
    callbacks = (dump / 'functions' / 'button_callbacks.lua').read_text(encoding='utf-8')
    state = (dump / 'functions' / 'state_events.lua').read_text(encoding='utf-8')
    objects = (smods / 'src' / 'game_object.lua').read_text(encoding='utf-8')
    runtime = LuaCalendar(mod)
    try:
        runtime.execute(BOOTSTRAP)
        for start, end in [
            ('function Card:use_consumeable(area, copier)', 'function Card:can_use_consumeable('),
            ('function Card:can_use_consumeable(', 'function Card:sell_card()'),
            ('function Card:open()', 'function Card:redeem()'),
        ]:
            runtime.execute(between(card, start, end))
        runtime.execute(between(callbacks, 'G.FUNCS.use_card = function(', 'G.FUNCS.sell_card = function('))
        runtime.execute(between(callbacks, 'G.FUNCS.skip_booster = function(', 'G.FUNCS.blind_choice_handler = function('))
        runtime.execute(between(state, 'G.FUNCS.draw_from_hand_to_deck = function(',
                                'G.FUNCS.draw_from_hand_to_discard = function('))
        update_pack = between(objects, '        update_pack = function(self, dt)',
                              '        ease_background_colour = function(self)')
        runtime.execute('SMODS.Booster.' + update_pack.strip().removesuffix(','))
        runtime.execute('R=assert(loadstring(' + quote((mod / 'rules.lua').read_text(encoding='utf-8')) + '))()')
        runtime.execute('''
for _,key in ipairs({'j_test_a','j_test_b','j_test_c'})do
 G.P_CENTERS[key]={key=key,set='Joker',rarity=3}
end
''')
        runtime.execute('P=assert(loadstring(' + quote((mod / 'packs.lua').read_text(encoding='utf-8'))
                        + '))()(SMODS.current_mod,R)')
        runtime.execute(CHECKS)
    finally:
        runtime.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    mods = Path(os.environ.get('APPDATA', '')) / 'Balatro' / 'Mods'
    parser.add_argument('--mod', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'mod' / 'TenYearsNineGrid')
    parser.add_argument('--dump', type=Path, default=mods / 'lovely' / 'dump')
    parser.add_argument('--smods', type=Path, default=mods / 'smods')
    args = parser.parse_args()
    check(args.mod, args.dump, args.smods)
