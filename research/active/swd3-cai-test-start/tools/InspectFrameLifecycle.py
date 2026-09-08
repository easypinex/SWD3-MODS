#@category SWD3
# Read-only fixed HD 4.0.5 frame loading / dialogue lifecycle report.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface();dc.openProgram(currentProgram)
targets=set()
for va in [0x140100260,0x140159a90]:
    f=getFunctionAt(toAddr(va));targets.add(f)
for ref in getReferencesTo(toAddr(0x140159a90)):
    println('INITREF '+str(ref))
    f=getFunctionContaining(ref.getFromAddress())
    if f:targets.add(f)
for d in currentProgram.getListing().getDefinedData(True):
    if unicode(d.getValue()) in ['Print_S','Print','Menu']:
        println('STRING '+str(d.getAddress())+' '+unicode(d.getValue()))
        for ref in getReferencesTo(d.getAddress()):
            println('REF '+str(ref))
            f=getFunctionContaining(ref.getFromAddress())
            if f:targets.add(f)
for f in targets:
    println('FUNCTION '+str(f.getEntryPoint())+' '+str(f))
    r=dc.decompileFunction(f,120,monitor)
    if r.decompileCompleted():println(r.getDecompiledFunction().getC())
    else:println('FAILED '+str(r.getErrorMessage()))
dc.dispose()
