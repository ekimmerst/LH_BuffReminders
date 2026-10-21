"""Run the Lua regression tests with the locally installed MiKTeX Lua library."""
import ctypes
import os
from pathlib import Path

bin_dir = Path(os.environ['LOCALAPPDATA']) / 'Programs/MiKTeX/miktex/bin/x64'
with os.add_dll_directory(str(bin_dir)):
    lib = ctypes.CDLL(str(bin_dir / 'MiKTeX260500-lua53.dll'))
lib.luaL_newstate.restype = ctypes.c_void_p
lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
lib.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_ssize_t, ctypes.c_void_p]
lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lib.lua_tolstring.restype = ctypes.c_char_p
lib.lua_close.argtypes = [ctypes.c_void_p]
os.chdir(Path(__file__).resolve().parent.parent)
state = lib.luaL_newstate()
try:
    lib.luaL_openlibs(state)
    status = lib.luaL_loadfilex(state, b'MiniReminders/_test.lua', None)
    if status == 0:
        status = lib.lua_pcallk(state, 0, -1, 0, 0, None)
    if status:
        raise RuntimeError(lib.lua_tolstring(state, -1, None).decode())
finally:
    lib.lua_close(state)
