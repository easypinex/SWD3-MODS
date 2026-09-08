#@category SWD3
# Read-only HD 4.0.5 report. Arguments: exact strings, or hex function addresses.
from ghidra.app.decompiler import DecompInterface
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
targets = {}
args = list(getScriptArgs())
for name in args:
    if name.startswith('0x'):
        f = getFunctionAt(toAddr(long(name, 16)))
        if f: targets[str(f.getEntryPoint())] = f
        else:
            println('INSTRUCTIONS ' + name)
            ins = getInstructionAt(toAddr(long(name, 16)))
            for _ in range(65):
                if ins is None: break
                println(str(ins.getAddress()) + ' ' + str(ins))
                if ins.getMnemonicString() == 'RET': break
                ins = ins.getNext()
data = currentProgram.getListing().getDefinedData(True)
while data.hasNext():
    item = data.next()
    value = item.getValue()
    if value is None or unicode(value) not in args: continue
    println('STRING ' + str(value) + ' @ ' + str(item.getAddress()))
    for ref in getReferencesTo(item.getAddress()):
        f = getFunctionContaining(ref.getFromAddress())
        println('REF ' + str(ref.getFromAddress()) + ' in ' + str(f))
        if f: targets[str(f.getEntryPoint())] = f
println('PARTY STATE REPORT')
for address, f in sorted(targets.items()):
    println('FUNCTION ' + address)
    result = decompiler.decompileFunction(f, 120, monitor)
    if result.decompileCompleted(): println(result.getDecompiledFunction().getC())
    else: println('FAILED ' + str(result.getErrorMessage()))
decompiler.dispose()
