#@category SWD3
#
# Read-only extraction of source-like context around calls to the known Lua
# dispatcher in native battle control functions.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('battle_command_state_machine', 0x140040820),
    ('battle_turn_loop', 0x140042d40),
    ('battle_loop_helper', 0x1400438b0),
    ('battle_ai_loop', 0x140044ab0),
]
MARKER = 'FUN_14014ccf0'

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD native battle dispatcher contexts')
for label, va in TARGETS:
    function = getFunctionAt(toAddr(va))
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 240, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    lines = result.getDecompiledFunction().getC().splitlines()
    found = False
    for index in range(len(lines)):
        if MARKER not in lines[index]:
            continue
        found = True
        start = max(0, index - 10)
        end = min(len(lines), index + 8)
        println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
        for current in range(start, end):
            println(str(current + 1) + ': ' + lines[current])
    if not found:
        println('<no direct dispatcher call in decompiled body>')
decompiler.dispose()
