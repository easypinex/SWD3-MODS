#@category SWD3
#
# Read-only data-flow report for the window between native action selection and
# the action executor.  It answers whether any Lua dispatcher in that window
# can observe the queued action-6 capture command before its native gate.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('player command flow', 0x140044ab0,
     ['BattlePlayerAI_after', 'FUN_140072060', 'case 6:', ' = 6;']),
    ('turn loop', 0x140042d40,
     ['FUN_140040820', 'BattlePlayerAI_after', 'FUN_140072060']),
    ('post-selection helper', 0x140072060,
     ['FUN_14014ccf0', 'AI_Command', 'AI_Target']),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD action-6 pre-dispatch report')
for label, va, markers in TARGETS:
    function = getFunctionAt(toAddr(va))
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 360, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    lines = result.getDecompiledFunction().getC().splitlines()
    printed = set()
    for index, line in enumerate(lines):
        if not any(marker in line for marker in markers):
            continue
        start = max(0, index - 32)
        end = min(len(lines), index + 28)
        key = (start, end)
        if key in printed:
            continue
        printed.add(key)
        println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
        for current in range(start, end):
            println(str(current + 1) + ': ' + lines[current])
decompiler.dispose()
