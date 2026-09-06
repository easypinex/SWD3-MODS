#@category SWD3
#
# Read-only inventory for the battle action payload selector at offset 0x4bc.
# Normal attacks select 0x28; critical normal attacks select 0x29.

from ghidra.app.decompiler import DecompInterface

TOKEN = '4bc'
function_manager = currentProgram.getFunctionManager()
listing = currentProgram.getListing()
seen = {}
for instruction in listing.getInstructions(True):
    text = str(instruction).lower()
    if TOKEN not in text:
        continue
    function = function_manager.getFunctionContaining(instruction.getAddress())
    if function is not None:
        seen[function.getEntryPoint()] = function

println('SWD3 HD action-payload selector (offset 0x4bc) inventory')
println('matching functions=' + str(len(seen)))
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
for entry in sorted(seen.keys()):
    function = seen[entry]
    println('===== ' + function.getName() + ' @ ' + str(entry) + ' =====')
    for instruction in listing.getInstructions(function.getBody(), True):
        if TOKEN in str(instruction).lower():
            println(str(instruction.getAddress()) + ': ' + str(instruction))
    result = decompiler.decompileFunction(function, 120, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
