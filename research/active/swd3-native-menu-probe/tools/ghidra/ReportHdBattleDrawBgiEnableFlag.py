#@category SWD3
#
# Read-only report for the native enable byte guarding Battle_DrawBGI dispatch
# in Steam HD 4.0.5.  It inventories all direct xrefs and decompiles the
# enclosing functions around references to distinguish reads from writers.

from ghidra.app.decompiler import DecompInterface

TARGET = 0x1401a76e0

function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD Battle_DrawBGI enable-flag report @ ' + hex(TARGET))
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
    result = decompiler.decompileFunction(function, 300, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    lines = result.getDecompiledFunction().getC().splitlines()
    found = False
    for index, line in enumerate(lines):
        if 'DAT_1401a76e0' not in line:
            continue
        found = True
        start = max(0, index - 12)
        end = min(len(lines), index + 14)
        println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
        for current in range(start, end):
            println(str(current + 1) + ': ' + lines[current])
    if not found:
        println('<reference exists but decompiler did not retain global symbol>')

decompiler.dispose()
