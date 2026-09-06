#@category SWD3
#
# Read-only evidence for whether the LoadLibraryExA caller is the standard Lua
# package.loadlib implementation and how it is registered into the Lua state.

from ghidra.app.decompiler import DecompInterface

TARGET = toAddr(0x140028a40)
references = currentProgram.getReferenceManager().getReferencesTo(TARGET)
functions = currentProgram.getFunctionManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

print('Lua package.loadlib exposure report (read-only)')
print('LoadLibraryExA caller=' + str(TARGET))
for reference in references:
    source = reference.getFromAddress()
    containing = functions.getFunctionContaining(source)
    print('xref=' + str(source) + '; type=' + str(reference.getReferenceType()) + '; containing=' + (str(containing.getEntryPoint()) if containing else '<none>'))
    if containing is None:
        continue
    result = decompiler.decompileFunction(containing, 240, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        print(result.getDecompiledFunction().getC())
    else:
        print('<decompilation unavailable>')
    print('---')
decompiler.dispose()
