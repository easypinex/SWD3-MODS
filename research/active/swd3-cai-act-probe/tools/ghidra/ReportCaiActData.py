#@category SWD3
# Read-only; addresses relocated from ACTData string in the recorded 4.0.5 hash.
from ghidra.app.decompiler import DecompInterface
println('SWD3 Cai ACTData consumer report')
println('Program SHA256: ' + currentProgram.getExecutableSHA256())
d = DecompInterface()
d.openProgram(currentProgram)
seen = set()
targets = [toAddr(0x1400ea99d)]
for ref in getReferencesTo(toAddr(0x140179ee8)):
    println('ACTData ref ' + str(ref))
    targets.append(ref.getFromAddress())
for site in targets:
    f = getFunctionContaining(site)
    if f is None:
        println('No containing function at ' + str(site))
        continue
    if str(f.getEntryPoint()) in seen: continue
    seen.add(str(f.getEntryPoint()))
    println('=== ACTData consumer ' + str(f.getEntryPoint()) + ' ===')
    r=d.decompileFunction(f,120,monitor)
    if r.decompileCompleted(): println(r.getDecompiledFunction().getC())
    else: println('DECOMPILE FAILED: ' + str(r.getErrorMessage()))
    for ref in getReferencesTo(f.getEntryPoint()):
        println('CALLER ' + str(ref.getFromAddress()) + ' in ' + str(getFunctionContaining(ref.getFromAddress())))
d.dispose()
