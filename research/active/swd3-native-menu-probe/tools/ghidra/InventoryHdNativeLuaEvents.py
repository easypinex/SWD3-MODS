#@category SWD3
#
# Read-only inventory of literal event names passed to the HD native Lua event
# dispatcher.  This intentionally does not depend on the original Lua
# OnEvent tables: it starts from every direct xref to the dispatcher in the
# verified Steam HD 4.0.5 executable and extracts literal strings from the
# corresponding decompilation.

import re
from ghidra.app.decompiler import DecompInterface

DISPATCHER = toAddr(0x14014ccf0)
function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()

callers = {}
for reference in reference_manager.getReferencesTo(DISPATCHER):
    function = function_manager.getFunctionContaining(reference.getFromAddress())
    if function is not None:
        callers[function.getEntryPoint()] = function

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
events = {}
unknown_dispatches = []
pattern = re.compile(r'FUN_14014ccf0\([^\n]*?"([^"]+)"')

println('SWD3 HD native Lua event inventory')
println('dispatcher=' + str(DISPATCHER) + '; direct caller functions=' + str(len(callers)))
for entry in sorted(callers.keys()):
    function = callers[entry]
    result = decompiler.decompileFunction(function, 180, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        unknown_dispatches.append(str(function) + ' (decompile failed)')
        continue
    code = result.getDecompiledFunction().getC()
    matches = pattern.findall(code)
    if not matches and 'FUN_14014ccf0' in code:
        unknown_dispatches.append(str(function) + ' @ ' + str(entry) + ' (non-literal dispatcher arguments)')
    for event_name in matches:
        bucket = events.get(event_name)
        if bucket is None:
            bucket = []
            events[event_name] = bucket
        if str(entry) not in bucket:
            bucket.append(str(entry))

println('\nLiteral event names=' + str(len(events)))
for event_name in sorted(events.keys()):
    println(event_name + ' ; callers=' + ', '.join(events[event_name]))

println('\nNon-literal or unavailable dispatcher callers=' + str(len(unknown_dispatches)))
for entry in unknown_dispatches:
    println(entry)

decompiler.dispose()
