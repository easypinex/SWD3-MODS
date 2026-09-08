#@category SWD3
# Read-only frame global references and menu caller chain, fixed HD 4.0.5 image.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
targets=set()
for va in [0x1402bed60,0x140105800]:
    a=toAddr(va)
    f=getFunctionContaining(a)
    if f:targets.add(f)
    for ref in getReferencesTo(a):
        println('REF '+str(a)+' '+str(ref))
        f=getFunctionContaining(ref.getFromAddress())
        if f and ref.getReferenceType().isWrite():targets.add(f)
for d in currentProgram.getListing().getDefinedData(True):
    if 'MenuFrame_Basic_ACT' in unicode(d.getValue()):
        println('STRING '+str(d.getAddress()))
        for ref in getReferencesTo(d.getAddress()):
            println('STRINGREF '+str(ref))
            f=getFunctionContaining(ref.getFromAddress())
            if f:targets.add(f)
ins=getInstructionAt(toAddr(0x140159f30))
for i in range(40):
    println(str(ins.getAddress())+' '+str(ins));ins=ins.getNext()
for f in targets:
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
    else:println('FAILED '+str(r.getErrorMessage()))
dc.dispose()
