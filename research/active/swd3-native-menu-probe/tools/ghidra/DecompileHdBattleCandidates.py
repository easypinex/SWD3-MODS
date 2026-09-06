#@category SWD3
#
# Read-only decompilation report for functions found by
# ReportHdBattleLuaReferences.py in Steam HD 4.0.5.  This script never writes
# labels, comments, data, or executable bytes.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('lua_event_dispatcher', 0x14014ccf0),
    ('battle_input_keydown_dispatch', 0x140053ae0),
    ('battle_input_click_dispatch', 0x1400574a0),
    ('battle_input_click_native_path', 0x140054580),
    ('battle_player_command_and_ai', 0x140044ab0),
    ('battle_env_lua_bindings', 0x14004f270),
    ('capture_can_obsolt_binding', 0x1400e0020),
    ('capture_obsolt_binding', 0x1400c3840),
    ('capture_obsolt_call_site', 0x14006c620)
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD candidate decompilation report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 60, monitor)
    if not result.decompileCompleted():
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    decompiled = result.getDecompiledFunction()
    if decompiled is None:
        println('<no decompiled function>')
        continue
    println(decompiled.getC())

decompiler.dispose()
