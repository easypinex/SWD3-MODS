#@category SWD3
# Read-only global basic-frame object references and dialogue queue insertion.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
targets=set([getFunctionAt(toAddr(0x140156860))])
for va in [0x1402bf3a8,0x1402bf3cc]:
    for ref in getReferencesTo(toAddr(va)):
        println('REF '+str(ref))
        f=getFunctionContaining(ref.getFromAddress())
        if f:targets.add(f)
for f in targets:
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
dc.dispose()
