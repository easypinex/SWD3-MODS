#@category SWD3
# Read-only string references and containing functions for new-game/item training.
from ghidra.app.decompiler import DecompInterface
dc=DecompInterface()
dc.openProgram(currentProgram)
seen=set()
for label,va in [('NewGameChar',0x140172718),('Familiar',0x1401739d0),('Value',0x14017488c)]:
    println('TARGET '+label+' '+hex(va))
    for ref in getReferencesTo(toAddr(va)):
        f=getFunctionContaining(ref.getFromAddress())
        println('REF '+str(ref.getFromAddress())+' '+str(f))
        if f and str(f.getEntryPoint()) not in seen:
            seen.add(str(f.getEntryPoint()))
            result=dc.decompileFunction(f,120,monitor)
            if result.decompileCompleted(): println(result.getDecompiledFunction().getC())
            else: println('FAILED '+str(result.getErrorMessage()))
dc.dispose()
