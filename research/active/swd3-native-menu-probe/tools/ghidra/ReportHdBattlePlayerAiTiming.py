#@category SWD3
#
# Read-only comparison of BattlePlayerAI and BattlePlayerAI_after inside the
# native player-command flow.  It extracts their immediate surrounding code,
# including queue writes, to establish whether either callback occurs after a
# manual action has already been queued or just before execution.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x140044ab0
MARKERS = ['"BattlePlayerAI"', '"BattlePlayerAI_after"', 'DAT_1401aa918',
           'FUN_140040820', 'case 6:']

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
function = getFunctionAt(toAddr(TARGET))
println('SWD3 HD BattlePlayerAI timing report @ ' + hex(TARGET))
if function is None:
    println('<no function defined>')
else:
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        printed = set()
        for index, line in enumerate(lines):
            if not any(marker in line for marker in MARKERS):
                continue
            start = max(0, index - 28)
            end = min(len(lines), index + 32)
            key = (start, end)
            if key in printed:
                continue
            printed.add(key)
            println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
            for current in range(start, end):
                println(str(current + 1) + ': ' + lines[current])
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
