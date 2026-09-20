"""Read-only contract probe against the installed game's real input helpers.

Uses the actual Lua 5.1 DLL, create_text_input definition and native text/cursor
functions from Lovely's dump. Only UI construction/recalculation is stubbed;
this does not render, launch, control or play Balatro. No files are written.
Run with ``python -B tests/test_native_input_contract.py`` from v0.3-dev.
"""
import argparse
import os
from pathlib import Path

from calendar_lua_bridge import LuaCalendar, quote


def between(source, start, end):
    begin = source.index(start)
    return source[begin:source.index(end, begin)]


def check(mod, dump):
    callbacks = (dump / 'functions' / 'button_callbacks.lua').read_text(encoding='utf-8')
    definitions = (dump / 'functions' / 'UI_definitions.lua').read_text(encoding='utf-8')
    runtime = LuaCalendar(mod)
    try:
        runtime.execute('''
G={FUNCS={},GAME={selected_back={name='b_tyg_mingju'}},CONTROLLER={},
 SETTINGS={paused=false},P_CENTERS={b_tyg_mingju={name='b_tyg_mingju'}},
 C={BLUE={0,0,1,1},GREEN={},WHITE={1,1,1,1},UI={TEXT_LIGHT={}}},
 UIT={R=1,C=2,T=3,O=4,B=5}}
SMODS={}
function copy_table(x)
 if not x then return nil end
 local result={};for k,v in pairs(x)do result[k]=v end;return result
end
function darken(x)return x end
function lighten(x)return x end
function ease_colour(x)return x end
function SWAP(t,a,b)t[a],t[b]=t[b],t[a]end
function create_option_cycle(x)return x end
function create_UIBox_generic_options(x)return x end
function UIBox_button(x)return x end
function DynaText(x)return x end
G.FUNCS.start_run=function()end
G.FUNCS.exit_overlay_menu=function()G.OVERLAY_MENU=nil end
G.FUNCS.overlay_menu=function(x)G.OVERLAY_MENU=x end
''')
        runtime.execute(between(definitions, 'function create_text_input(args)',
                                'function create_keyboard_input(args)'))
        runtime.execute(between(callbacks, 'G.FUNCS.select_text_input = function(e)',
                                '--Handles all key inputs for the hooked text input.'))
        runtime.execute(between(callbacks, 'G.FUNCS.text_input_key = function(args)',
                                '--Determines if there are any graphical changes in the queue'))
        runtime.execute('R=assert(loadstring(' + quote((mod / 'rules.lua').read_text(encoding='utf-8'))
                        + '))(); makeBirth=assert(loadstring('
                        + quote((mod / 'birth_ui.lua').read_text(encoding='utf-8')) + '))()')
        runtime.execute('Cycles=assert(loadstring(' + quote((mod / 'cycles.lua').read_text(encoding='utf-8')) + '))()({},R)')
        runtime.execute('''
local native=create_text_input
inputs={}
function create_text_input(args)
 local definition=native(args)
 local box={}
 local function build(node,parent)
  local element={config=node.config or{},parent=parent,UIBox=box,children={}}
  for i,child in ipairs(node.nodes or{})do element.children[i]=build(child,element)end
  return element
 end
 local root=build(definition,nil)
 function box:recalculate()
  local function visit(element)
   if element.config.ref_table and element.config.ref_value then
    element.config.text=tostring(element.config.ref_table[element.config.ref_value])
   end
   for _,child in ipairs(element.children)do visit(child)end
  end
  visit(root)
 end
 box:recalculate()
 inputs[args.id]={root=root,args=args}
 return definition
end
expected_time='00:00'
I=makeBirth({},R,function(input)
 assert(input.date=='2000-02-29'and input.time==expected_time and input.gender==1,
  'wizard must receive exact values typed through native helpers')
 return R.demo_profile()
end,Cycles)
I.install_hooks()
G.FUNCS.start_run(nil,{})
G.FUNCS.tyg_choose_birth()
local function focus(id)G.FUNCS.select_text_input(inputs[id].root.children[1])end
local function type_text(s)
 for i=1,#s do G.FUNCS.text_input_key{key=s:sub(i,i)}end
end
focus('tyg_birth_date');type_text('20000229')
assert(inputs.tyg_birth_date.args.ref_table.date=='20000229','native digit sequence')
G.FUNCS.text_input_key{key='left'}
G.FUNCS.text_input_key{key='backspace'}
G.FUNCS.text_input_key{key='2'}
assert(inputs.tyg_birth_date.args.ref_table.date=='20000229','native cursor editing')
G.FUNCS.text_input_key{key='return'}
assert(not G.CONTROLLER.text_input_hook,'native Enter releases input')
focus('tyg_birth_time');type_text('0000')
assert(inputs.tyg_birth_time.args.ref_table.time=='0000','native midnight zeros')
G.FUNCS.text_input_key{key='a'}
assert(inputs.tyg_birth_time.args.ref_table.time=='0000','non-digit rejected')
G.FUNCS.tyg_birth_gender{to_key=2};G.FUNCS.tyg_birth_match()
assert(I.current_profile(),'native typed values accepted for matching')
for _,spelling in ipairs({'730','0730','7:30','07:30'})do
 G.FUNCS.tyg_birth_cancel();G.FUNCS.start_run(nil,{})
 G.FUNCS.tyg_choose_birth()
 focus('tyg_birth_date');type_text('20000229')
 focus('tyg_birth_time');type_text(spelling)
 expected_time='07:30'
 G.FUNCS.tyg_birth_gender{to_key=2};G.FUNCS.tyg_birth_match()
 assert(I.current_profile(),'native time normalization '..spelling)
end
print('PASS real native input helpers: date, midnight zeros, cursor edit, Enter, letter rejection, match')
''')
    finally:
        runtime.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mod', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'mod' / 'TenYearsNineGrid')
    parser.add_argument('--dump', type=Path,
                        default=Path(os.environ.get('APPDATA', '')) / 'Balatro' / 'Mods' / 'lovely' / 'dump')
    args = parser.parse_args()
    check(args.mod, args.dump)
