#@category SWD3
# HD4.0.5 existing isolated Ghidra project only, -readOnly -noanalysis.
from ghidra.app.decompiler import DecompInterface
api=DecompInterface();api.openProgram(currentProgram)
targets=set(['1400725c0','1400524e0','140056b30','1400e0020'])
for ref in getReferencesTo(toAddr('1400725c0')):
    fn=getFunctionContaining(ref.getFromAddress())
    if fn:
        targets.add(str(fn.getEntryPoint()))
        println('GATE_CALLER '+str(fn.getEntryPoint())+' REF '+str(ref.getFromAddress()))
it=currentProgram.getListing().getDefinedData(True)
while it.hasNext():
    data=it.next()
    if not data.hasStringValue(): continue
    value=unicode(data.getValue())
    if any(key in value for key in ['Keeper','SUMMON','Summon','SetPlayerAI','USEITEM']):
        println('STRING '+str(data.getAddress())+' '+value)
        for ref in getReferencesTo(data.getAddress()):
            fn=getFunctionContaining(ref.getFromAddress())
            if fn: println('STRING_REF '+str(fn.getEntryPoint())+' '+str(ref.getFromAddress()))
for address in sorted(targets):
    fn=getFunctionAt(toAddr(address))
    if fn:
        result=api.decompileFunction(fn,60,monitor)
        println('FUNCTION '+address)
        if result.decompileCompleted(): println(result.getDecompiledFunction().getC())
        else: println('FAILED '+address)
api.dispose()
