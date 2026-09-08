#@category SWD3
# Read-only fixed HD 4.0.5 UI initialization caller report.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
targets=set()
for ref in getReferencesTo(toAddr(0x1401507a0)):
    println('REF '+str(ref))
    f=getFunctionContaining(ref.getFromAddress())
    if f:targets.add(f)
for f in targets:
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
    else:println('FAILED '+str(r.getErrorMessage()))
dc.dispose()
