#@category SWD3
# Read-only HD4.0.5 keeper initialization callers and capacity checks.
from ghidra.app.decompiler import DecompInterface
api=DecompInterface();api.openProgram(currentProgram)
listing=currentProgram.getListing(); funcs={}
it=listing.getDefinedData(True)
while it.hasNext():
    d=it.next()
    try: value=unicode(d.getValue())
    except: continue
    if value != 'Battle_KeeperInit': continue
    for ref in currentProgram.getReferenceManager().getReferencesTo(d.getAddress()):
        f=getFunctionContaining(ref.getFromAddress())
        if f: funcs[str(f.getEntryPoint())]=f
for key,f in funcs.items():
    for ref in currentProgram.getReferenceManager().getReferencesTo(f.getEntryPoint()):
        caller=getFunctionContaining(ref.getFromAddress())
        if caller: println('CALLER '+str(caller.getEntryPoint()))
    result=api.decompileFunction(f,60,monitor)
    println('FUNCTION '+key)
    if result.decompileCompleted(): println(result.getDecompiledFunction().getC())
api.dispose()
