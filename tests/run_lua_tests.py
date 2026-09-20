"""Compile/test with the installed game's own Lua 5.1 runtime, no pip dependency."""
import ctypes
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
MOD = Path(os.environ.get('TYG_TEST_MOD_DIR', ROOT / 'mod' / 'TenYearsNineGrid'))
if not (MOD / 'main.lua').is_file():
    raise SystemExit('Missing test target main.lua: ' + str(MOD))
DLL = Path(os.environ.get('BALATRO_LUA_DLL', r'D:\SteamLibrary\steamapps\common\Balatro\lua51.dll'))


def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'


if not DLL.is_file():
    raise SystemExit('Set BALATRO_LUA_DLL to the installed Balatro lua51.dll path.')
dll_dir = os.add_dll_directory(str(DLL.parent))
lua = ctypes.CDLL(str(DLL))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
lua.luaL_loadbuffer.restype = ctypes.c_int
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_pcall.restype = ctypes.c_int
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_close.argtypes = [ctypes.c_void_p]
state = lua.luaL_newstate()
lua.luaL_openlibs(state)


def chunk(code, name, execute=True):
    data = code.encode('utf-8') if isinstance(code, str) else code
    status = lua.luaL_loadbuffer(state, data, len(data), name.encode('utf-8'))
    if status == 0 and execute:
        status = lua.lua_pcall(state, 0, 0, 0)
    if status:
        err = lua.lua_tolstring(state, -1, None)
        raise RuntimeError(err.decode('utf-8', errors='replace') if err else f'Lua error {status}')
    lua.lua_settop(state, 0)


try:
    sources = {}
    for path in sorted(MOD.glob('*.lua')):
        code = path.read_text(encoding='utf-8')
        chunk(code, path.name, execute=False)
        sources[path.name] = code
        print('COMPILE OK:', path.name, flush=True)
    if '--compile-only' not in sys.argv:
        prelude = 'TEST_ROOT=' + quote(MOD.as_posix()) + '; TEST_SOURCES={}\n'
        for name, code in sources.items():
            prelude += 'TEST_SOURCES[' + quote(name) + ']=' + quote(code) + '\n'
        # Lua 5.1's narrow-path fopen cannot portably open Chinese Windows paths.
        prelude += r'''
local native_loadfile=loadfile
function loadfile(path)
  local name=path:match('([^/\\]+)$')
  if TEST_SOURCES[name] then return loadstring(TEST_SOURCES[name], '@'..name) end
  return native_loadfile(path)
end
function dofile(path) local f,e=loadfile(path); assert(f,e); return f() end
'''
        chunk(prelude, 'test-prelude')
        selected = sys.argv[1] if len(sys.argv)>1 else 'test_birth_ui.lua'
        chunk((ROOT / 'tests' / selected).read_bytes(), selected)
finally:
    lua.lua_close(state)
    dll_dir.close()
