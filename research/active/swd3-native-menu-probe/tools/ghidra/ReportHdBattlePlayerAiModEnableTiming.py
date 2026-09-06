#@category SWD3
#
# Read-only report for the native loader that reads the Lua global
# BattlePlayerAI_mod and enables Battle_DrawBGI / BattlePlayerAI callbacks.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x140146a50

function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD BattlePlayerAI_mod enable timing report @ ' + hex(TARGET))
functions = {}
for reference in reference_manager.getReferencesTo(toAddr(TARGET)):
    source = reference.getFromAddress()
    function = function_manager.getFunctionContaining(source)
    println('xref ' + str(source) + ' ' + str(reference.getReferenceType())
        + '; instruction=' + str(getInstructionAt(source))
        + '; function=' + str(function))
    if function is not None:
        functions[function.getEntryPoint()] = function

for entry in sorted(functions.keys()):
    function = functions[entry]
    println('===== ' + function.getName() + ' @ ' + str(entry) + ' =====')
    result = decompiler.decompileFunction(function, 360, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    lines = result.getDecompiledFunction().getC().splitlines()
    for index, line in enumerate(lines):
        if 'FUN_140146a50' not in line:
            continue
        start = max(0, index - 30)
        end = min(len(lines), index + 35)
        println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
        for current in range(start, end):
            println(str(current + 1) + ': ' + lines[current])

decompiler.dispose()
