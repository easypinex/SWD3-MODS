#@category SWD3
# Ghidra/Jython, read-only query of existing HD4.0.5 workspace project.
from ghidra.app.decompiler import DecompInterface
api = DecompInterface()
api.openProgram(currentProgram)
for address in ['1400725c0']:
    fn = getFunctionAt(toAddr(address))
    if fn is None:
        println('MISSING '+address)
        continue
    result = api.decompileFunction(fn,60,monitor)
    println('FUNCTION '+address)
    if result.decompileCompleted(): println(result.getDecompiledFunction().getC())
api.dispose()
