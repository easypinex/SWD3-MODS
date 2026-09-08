#@category SWD3
# Read-only fixed HD 4.0.5 ACT loader and Print_S native binding.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
for va in [0x140101200,0x1400a29b0,0x1400a28e0,0x1400a24d0,0x140160a60]:
    f=getFunctionContaining(toAddr(va))
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
    else:println('FAILED '+str(r.getErrorMessage()))
dc.dispose()
