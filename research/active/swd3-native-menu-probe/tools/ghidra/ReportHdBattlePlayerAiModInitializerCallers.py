#@category SWD3
# Read-only caller inventory for the BattlePlayerAI_mod configuration initializer.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x1401507a0
fm = currentProgram.getFunctionManager()
rm = currentProgram.getReferenceManager()
dc = DecompInterface()
dc.openProgram(currentProgram)
println('SWD3 HD BattlePlayerAI_mod initializer callers @ ' + hex(TARGET))
seen = {}
for ref in rm.getReferencesTo(toAddr(TARGET)):
    source = ref.getFromAddress()
    function = fm.getFunctionContaining(source)
    println('xref ' + str(source) + ' ' + str(ref.getReferenceType()) + '; instruction=' + str(getInstructionAt(source)) + '; function=' + str(function))
    if function is not None:
        seen[function.getEntryPoint()] = function
for entry in sorted(seen.keys()):
    function = seen[entry]
    println('===== ' + function.getName() + ' @ ' + str(entry) + ' =====')
    result = dc.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed>')
dc.dispose()
