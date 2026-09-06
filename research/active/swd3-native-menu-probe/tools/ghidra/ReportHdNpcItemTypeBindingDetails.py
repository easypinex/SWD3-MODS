#@category SWD3
#
# Read-only focused decompilation of the HD NPCData ItemType Lua registration.
# It is kept narrow because broad string reports obscure the getter/setter
# registration amongst unrelated bindings.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x1400e0020

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
function = getFunctionAt(toAddr(TARGET))
println('SWD3 HD NPCData.ItemType binding details @ ' + hex(TARGET))
if function is None:
    println('<no function defined>')
else:
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        for index, line in enumerate(lines):
            if 'ItemType' not in line:
                continue
            start = max(0, index - 16)
            end = min(len(lines), index + 26)
            println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
            for current in range(start, end):
                println(str(current + 1) + ': ' + lines[current])
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
