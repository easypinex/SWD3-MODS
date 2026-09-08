#@category SWD3
# Read-only fixed HD 4.0.5 lazy frame initializer callers.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
targets=set()
for va in [0x1401595b0,0x140159850,0x140159740,0x140159650]:
    for ref in getReferencesTo(toAddr(va)):
        println('REF '+str(ref))
        f=getFunctionContaining(ref.getFromAddress())
        if f:targets.add(f)
for f in targets:
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
    else:println('FAILED '+str(r.getErrorMessage()))
dc.dispose()
