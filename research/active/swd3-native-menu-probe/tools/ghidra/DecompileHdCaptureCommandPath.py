#@category SWD3
#
# Read-only decompilation of HD battle update, action execution, and BSC bridge candidates.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('battle_update_loop', 0x14003f640),
    ('battle_action_executor', 0x140040820),
    ('battle_player_command_flow', 0x140044ab0),
    ('bsc_obsolt_lua_bridge_candidate', 0x14006c590),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD capture command-path decompilation report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 90, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    println(result.getDecompiledFunction().getC())
decompiler.dispose()
