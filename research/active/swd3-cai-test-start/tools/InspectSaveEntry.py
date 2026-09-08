#@category SWD3
# Read-only native SaveMenu entry, HD 4.0.5.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
for va in [0x1400a6ea0,0x140092990,0x1400a2270]:
    f=getFunctionContaining(toAddr(va))
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
dc.dispose()
