"""Small read-only test bridge to Balatro's real Lua 5.1 DLL.

Sources enter through loadbuffer because Lua's narrow Windows fopen does not
reliably accept the Chinese project path. Nothing launches or controls Balatro.
"""
import ctypes
import os
from pathlib import Path


def quote(value):
    return '"' + value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r') + '"'


class LuaCalendar:
    def __init__(self, mod):
        dll = Path(os.environ.get('BALATRO_LUA_DLL', r'D:\SteamLibrary\steamapps\common\Balatro\lua51.dll'))
        self.dll_dir = os.add_dll_directory(str(dll.parent))
        self.lua = ctypes.CDLL(str(dll))
        ptr = ctypes.c_void_p
        for name, args, result in (
            ('luaL_newstate', [], ptr), ('luaL_openlibs', [ptr], None),
            ('luaL_loadbuffer', [ptr, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p], ctypes.c_int),
            ('lua_pcall', [ptr, ctypes.c_int, ctypes.c_int, ctypes.c_int], ctypes.c_int),
            ('lua_type', [ptr, ctypes.c_int], ctypes.c_int),
            ('lua_tolstring', [ptr, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)], ctypes.c_char_p),
            ('lua_tonumber', [ptr, ctypes.c_int], ctypes.c_double),
            ('lua_toboolean', [ptr, ctypes.c_int], ctypes.c_int),
            ('lua_gettop', [ptr], ctypes.c_int), ('lua_settop', [ptr, ctypes.c_int], None),
            ('lua_pushnil', [ptr], None), ('lua_next', [ptr, ctypes.c_int], ctypes.c_int),
            ('lua_close', [ptr], None),
        ):
            fn = getattr(self.lua, name)
            fn.argtypes, fn.restype = args, result
        self.state = self.lua.luaL_newstate()
        self.lua.luaL_openlibs(self.state)
        self.execute('DATA=assert(loadstring(' + quote((mod / 'calendar_data.lua').read_text(encoding='utf-8')) + '))();'
                     'C=assert(loadstring(' + quote((mod / 'calendar.lua').read_text(encoding='utf-8')) + '))()(DATA)')

    def value(self, index):
        lua, state = self.lua, self.state
        kind = lua.lua_type(state, index)
        if kind == 0:
            return None
        if kind == 1:
            return bool(lua.lua_toboolean(state, index))
        if kind == 3:
            value = lua.lua_tonumber(state, index)
            return int(value) if value.is_integer() else value
        if kind == 4:
            return lua.lua_tolstring(state, index, None).decode('utf-8')
        if kind == 5:
            absolute = index if index > 0 else lua.lua_gettop(state) + index + 1
            values = {}
            lua.lua_pushnil(state)
            while lua.lua_next(state, absolute):
                values[self.value(-2)] = self.value(-1)
                lua.lua_settop(state, -2)
            if values and set(values) == set(range(1, len(values) + 1)):
                return [values[i] for i in range(1, len(values) + 1)]
            return values
        raise AssertionError(f'Unexpected Lua type {kind}')

    def execute(self, code, results=0):
        data = code.encode('utf-8')
        status = self.lua.luaL_loadbuffer(self.state, data, len(data), b'calendar-test')
        if not status:
            status = self.lua.lua_pcall(self.state, 0, results, 0)
        if status:
            message = self.lua.lua_tolstring(self.state, -1, None)
            self.lua.lua_settop(self.state, 0)
            raise AssertionError(message.decode('utf-8', errors='replace'))
        values = [self.value(i) for i in range(1, results + 1)]
        self.lua.lua_settop(self.state, 0)
        return values

    def calculate(self, date, time, gender):
        profile, error = self.execute('return C.calculate({date=' + quote(date) + ',time=' + quote(time)
                                      + ',gender=' + str(gender) + '})', 2)
        assert profile is not None, error
        return profile

    def close(self):
        self.lua.lua_close(self.state)
        self.dll_dir.close()
