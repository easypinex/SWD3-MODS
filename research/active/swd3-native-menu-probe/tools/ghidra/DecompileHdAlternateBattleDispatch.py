#@category SWD3
#
# Read-only investigation of the second native battle callback helper seen in
# the command UI.  It is deliberately separate from the normal OnEvent
# dispatcher (FUN_14014ccf0): this report identifies its caller strings and
# decompiles the helper so names such as BattleEnv_MemberSkillType are not
# mistaken for undocumented public Lua events.

import re
from ghidra.app.decompiler import DecompInterface

HELPER = toAddr(0x14014dc20)
INNER_HELPER = toAddr(0x14014dd30)
function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()

helper = function_manager.getFunctionAt(HELPER)
callers = {}
for reference in reference_manager.getReferencesTo(HELPER):
    function = function_manager.getFunctionContaining(reference.getFromAddress())
    if function is not None:
        callers[function.getEntryPoint()] = function

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD alternate battle dispatcher report')
println('helper=' + str(HELPER) + '; direct caller functions=' + str(len(callers)))
println('===== helper =====')
if helper is None:
    println('<no function defined>')
else:
    result = decompiler.decompileFunction(helper, 240, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')

pattern = re.compile(r'FUN_14014dc20\([^\n]*?"([^"]+)"')
println('===== callers =====')
for entry in sorted(callers.keys()):
    function = callers[entry]
    result = decompiler.decompileFunction(function, 240, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println(str(entry) + ': <decompilation failed>')
        continue
    code = result.getDecompiledFunction().getC()
    names = pattern.findall(code)
    println(str(entry) + ' ' + str(function) + '; literal names=' + ', '.join(names))
    println(code)

inner = function_manager.getFunctionAt(INNER_HELPER)
println('===== inner helper @ ' + str(INNER_HELPER) + ' =====')
if inner is None:
    println('<no function defined>')
else:
    result = decompiler.decompileFunction(inner, 240, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')

decompiler.dispose()
