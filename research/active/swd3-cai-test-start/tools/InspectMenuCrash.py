#@category SWD3
# Read-only containing function, immediate callers and fault instruction.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
addr=toAddr(0x14015a18e)
fault=getFunctionContaining(addr)
targets=set([fault])
for ref in getReferencesTo(fault.getEntryPoint()):
    f=getFunctionContaining(ref.getFromAddress())
    if f:targets.add(f)
println('FAULT '+str(addr)+' function '+str(fault))
ins=getInstructionAt(addr)
for i in range(8):
    if ins:ins=ins.getPrevious()
for i in range(17):
    if ins:println(str(ins.getAddress())+' '+str(ins));ins=ins.getNext()
for f in targets:
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
    else:println('FAILED '+str(r.getErrorMessage()))
dc.dispose()
