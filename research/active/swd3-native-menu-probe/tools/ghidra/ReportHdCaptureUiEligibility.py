#@category SWD3
#
# Read-only report for the manual-capture UI question: does the UI call a live
# eligibility helper while confirming action 6, or rely only on an earlier
# cache?  It inventories callers of the action-6 gate and extracts the exact
# action-6 target-confirmation window from the menu state machine.  It never
# changes functions, labels, types, comments, bytes, or the program database.

from ghidra.app.decompiler import DecompInterface

GATE = 0x1400752b0
TARGETS = [
    ('battle_env CanOBSOLT getter', 0x140051600),
    ('NPCROLE CanObsolt method', 0x14007a060),
]
MENU_TRANSITION = 0x1400574a0

reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()

println('SWD3 HD capture UI eligibility first-pass report')
println('===== callers of native action-6 gate @ ' + hex(GATE) + ' =====')
refs = reference_manager.getReferencesTo(toAddr(GATE))
count = 0
for reference in refs:
    source = reference.getFromAddress()
    function = function_manager.getFunctionContaining(source)
    text = '<no enclosing function>'
    if function is not None:
        text = function.getName() + ' @ ' + str(function.getEntryPoint())
    println('  ' + str(source) + ' in ' + text + '; ' + str(getInstructionAt(source)))
    count += 1
println('  callerReferenceCount=' + str(count))

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
for label, va in TARGETS:
    function = getFunctionAt(toAddr(va))
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')

function = getFunctionAt(toAddr(MENU_TRANSITION))
println('===== action-6 target confirmation in menu transition @ ' + hex(MENU_TRANSITION) + ' =====')
if function is None:
    println('<no function defined>')
else:
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        for index, line in enumerate(lines):
            if 'FUN_14007a060' not in line:
                continue
            start = max(0, index - 10)
            end = min(len(lines), index + 25)
            println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
            for current in range(start, end):
                println(str(current + 1) + ': ' + lines[current])
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
