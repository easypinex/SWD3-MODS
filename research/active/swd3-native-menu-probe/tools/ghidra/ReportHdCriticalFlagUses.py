#@category SWD3
#
# Read-only inventory of the native battle-character critical flag (offset 0x3f90)
# in the verified Steam HD 4.0.5 executable.  The output is only a lead list:
# it does not assign a semantic meaning to every matching field access.

from ghidra.app.decompiler import DecompInterface

OFFSET_TEXT = '3f90'
function_manager = currentProgram.getFunctionManager()
listing = currentProgram.getListing()
seen = {}

for instruction in listing.getInstructions(True):
    text = str(instruction).lower()
    if OFFSET_TEXT not in text:
        continue
    function = function_manager.getFunctionContaining(instruction.getAddress())
    if function is None:
        continue
    seen[function.getEntryPoint()] = function

println('SWD3 HD critical-flag (offset 0x3f90) use inventory')
println('matching functions=' + str(len(seen)))

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
for entry in sorted(seen.keys()):
    function = seen[entry]
    println('===== ' + function.getName() + ' @ ' + str(entry) + ' =====')
    for instruction in listing.getInstructions(function.getBody(), True):
        if OFFSET_TEXT in str(instruction).lower():
            println(str(instruction.getAddress()) + ': ' + str(instruction))
    result = decompiler.decompileFunction(function, 90, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')

decompiler.dispose()
