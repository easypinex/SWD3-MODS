#@category SWD3
#
# Read-only reference and decompilation report for the HD critical-hit callback.

from ghidra.app.decompiler import DecompInterface

TARGET = toAddr(0x1401739f0)  # "BattleCriticalHitRate" in the verified HD 4.0.5 copy.
reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD BattleCriticalHitRate path report')
println('target=' + str(TARGET) + '; data=' + str(getDataAt(TARGET)))
seen = []
for reference in reference_manager.getReferencesTo(TARGET):
    source = reference.getFromAddress()
    function = function_manager.getFunctionContaining(source)
    println(str(reference.getReferenceType()) + ' from ' + str(source) + '; function=' + str(function) +
            '; instruction=' + str(getInstructionAt(source)))
    if function is not None and function.getEntryPoint() not in seen:
        seen.append(function.getEntryPoint())

for entry in seen:
    function = function_manager.getFunctionAt(entry)
    println('===== caller ' + function.getName() + ' @ ' + str(entry) + ' =====')
    result = decompiler.decompileFunction(function, 90, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')

decompiler.dispose()
