#@category SWD3
# Read-only new-character callers, named equipment initialization and save getters.
from ghidra.app.decompiler import DecompInterface
import re
dc=DecompInterface();dc.openProgram(currentProgram)
targets=set([0x140149d60,0x14014dd00,0x14009dd70])
for r in getReferencesTo(toAddr(0x14009dd70)):
    f=getFunctionContaining(r.getFromAddress())
    if f: targets.add(f.getEntryPoint().getOffset())
for d in currentProgram.getListing().getDefinedData(True):
    if d.hasStringValue() and unicode(d.getValue()) in ['NewGameEqu','NewGameSkill']:
        for r in getReferencesTo(d.getAddress()):
            f=getFunctionContaining(r.getFromAddress())
            if f: targets.add(f.getEntryPoint().getOffset())
def replace(m):
    d=getDataAt(toAddr(int(m.group(1),16)))
    if d and d.hasStringValue(): return '"'+str(d.getValue())+'"'
    return m.group(0)
for va in sorted(targets):
    f=getFunctionAt(toAddr(va));println('TARGET '+hex(va))
    result=dc.decompileFunction(f,120,monitor)
    if result.decompileCompleted(): println(re.sub(r'&DAT_([0-9a-f]+)',replace,result.getDecompiledFunction().getC()))
    else: println('FAILED '+str(result.getErrorMessage()))
dc.dispose()
