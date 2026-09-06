#@category SWD3
#
# Read-only decompilation of the two native functions that call the Lua event
# dispatcher with non-literal event-name arguments in Steam HD 4.0.5.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('dynamic_dispatcher_a', 0x140053ae0),
    ('damage_path_dynamic_dispatcher', 0x140085890),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD dynamic Lua-dispatch caller decompilation')
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
