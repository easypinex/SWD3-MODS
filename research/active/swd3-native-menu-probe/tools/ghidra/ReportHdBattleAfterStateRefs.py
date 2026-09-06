#@category SWD3
#
# Read-only inventory for the state that selects the BattlePlayerAI_after
# branch.  It records every direct xref and its enclosing function so the
# research log does not mistake one local pseudocode branch for a full turn
# ordering guarantee.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x1401ab44c

def containing_function(address):
    return getFunctionContaining(address)

refs = list(currentProgram.getReferenceManager().getReferencesTo(toAddr(TARGET)))
println('SWD3 HD BattlePlayerAI_after state xrefs @ ' + hex(TARGET) + ': ' + str(len(refs)))
seen = set()
for ref in refs:
    source = ref.getFromAddress()
    function = containing_function(source)
    function_name = function.getName() if function is not None else '<no-function>'
    kind = str(ref.getReferenceType())
    println('xref ' + str(source) + ' ' + kind + ' in ' + function_name)
    if function is not None:
        seen.add(function.getEntryPoint())

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
for entry in sorted(seen):
    function = getFunctionAt(entry)
    if function is None:
        continue
    println('--- ' + function.getName() + ' @ ' + str(entry) + ' ---')
    result = decompiler.decompileFunction(function, 240, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed>')
        continue
    lines = result.getDecompiledFunction().getC().splitlines()
    for index, line in enumerate(lines):
        if 'DAT_1401ab44c' not in line:
            continue
        start = max(0, index - 8)
        end = min(len(lines), index + 12)
        println('lines ' + str(start + 1) + '-' + str(end))
        for current in range(start, end):
            println(str(current + 1) + ': ' + lines[current])
decompiler.dispose()
