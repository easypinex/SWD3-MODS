#@category SWD3
#
# Read-only report of the state-machine split containing BattlePlayerAI_after
# and the player action executor.  It deliberately prints a narrow window so
# reviewers can see whether these calls are linear or mutually exclusive.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x140044ab0
START_LINE = 810
END_LINE = 915

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
function = getFunctionAt(toAddr(TARGET))
println('SWD3 HD BattlePlayer action state split @ ' + hex(TARGET))
if function is None:
    println('<no function defined>')
else:
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        start = max(0, START_LINE - 1)
        end = min(len(lines), END_LINE)
        for index in range(start, end):
            println(str(index + 1) + ': ' + lines[index])
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
