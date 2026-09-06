#@category SWD3
#
# Read-only Steam HD 4.0.5 report.  Locates the Lua-visible names associated
# with NPC item flags, lists their direct native references, then decompiles
# each containing registration function.  It does not attach to or modify the
# running game.

from ghidra.app.decompiler import DecompInterface

TARGETS = ['NPCData', 'ItemType', 'IT_06']
listing = currentProgram.getListing()
references = currentProgram.getReferenceManager()
functions = currentProgram.getFunctionManager()
addresses = {}

iterator = listing.getDefinedData(True)
while iterator.hasNext():
    data = iterator.next()
    try:
        value = str(data.getValue())
    except:
        continue
    if value in TARGETS:
        addresses.setdefault(value, []).append(data.getAddress())

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD NPCData flag binding report')
for target in TARGETS:
    matches = addresses.get(target, [])
    println('===== ' + target + ' definitions=' + str(len(matches)) + ' =====')
    for address in matches:
        println('definition @ ' + str(address))
        seen = set()
        for ref in references.getReferencesTo(address):
            function = functions.getFunctionContaining(ref.getFromAddress())
            if function is None:
                println('  ref ' + str(ref.getFromAddress()) + ': no containing function')
                continue
            entry = function.getEntryPoint()
            if entry in seen:
                continue
            seen.add(entry)
            println('  function ' + function.getName() + ' @ ' + str(entry))
            result = decompiler.decompileFunction(function, 180, monitor)
            if result.decompileCompleted() and result.getDecompiledFunction() is not None:
                println(result.getDecompiledFunction().getC())
            else:
                println('  <decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
