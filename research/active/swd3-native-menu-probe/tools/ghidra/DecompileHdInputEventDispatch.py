#@category SWD3
#
# Read-only focused decompilation of the HD generic and battle event dispatchers.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('lua_event_dispatcher', 0x14014ccf0),
    ('global_input_event_dispatch_a', 0x1401248c0),
    ('global_input_event_dispatch_b', 0x140124a80),
    ('battle_input_keydown_dispatch', 0x140053ae0),
    ('battle_input_click_dispatch', 0x1400574a0)
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD input event dispatch decompilation report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 60, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    println(result.getDecompiledFunction().getC())
decompiler.dispose()
