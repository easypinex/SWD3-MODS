#@category SWD3
#
# Read-only decompilation of native callers for the remaining battle UI/input
# event candidates.  Used to determine whether their arguments represent an
# action code or only UI/render/input state.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('battle_draw_bgi_dispatcher', 0x1400402a0),
    ('battle_input_dispatcher', 0x140053ae0),
    ('battle_input_and_command_ui', 0x1400574a0),
    ('battle_input_ui_helper', 0x140054580),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD battle UI/input event caller report')
for label, va in TARGETS:
    function = getFunctionAt(toAddr(va))
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 240, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
