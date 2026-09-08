#@category SWD3
# Read-only HD4.0.5 analysis of known public bridges.
from ghidra.app.decompiler import DecompInterface
EXPECTED = '63f1d83d8c3a756d17640d9022e19f8928741b091f0e47abbdb22c0ccf6c9523'
if str(currentProgram.getExecutableSHA256()).lower() != EXPECTED:
    raise RuntimeError('Executable SHA-256 mismatch')
api=DecompInterface()
api.openProgram(currentProgram)
println('SWD3 reward menu refresh report SHA256=' + EXPECTED)
for va in [0x1400de620,0x1400ad7a0,0x1400de8f0,0x1400d9060]:
    fn=getFunctionAt(toAddr(va))
    if fn is None: raise RuntimeError('Missing function ' + hex(va))
    result=api.decompileFunction(fn,60,monitor)
    if not result.decompileCompleted(): raise RuntimeError(str(result.getErrorMessage()))
    println('FUNCTION ' + hex(va))
    println(result.getDecompiledFunction().getC())
println('END REWARD MENU REPORT')
api.dispose()
