#@category SWD3
# Read-only Ghidra/Jython. Follow AI dispatch and four-digit number rendering.
from ghidra.app.decompiler import DecompInterface
EXPECTED = '63f1d83d8c3a756d17640d9022e19f8928741b091f0e47abbdb22c0ccf6c9523'
if str(currentProgram.getExecutableSHA256()).lower() != EXPECTED:
    raise RuntimeError('Executable SHA-256 mismatch')
println('SWD3 HD healing display report SHA256=' + EXPECTED)
api = DecompInterface()
api.openProgram(currentProgram)
targets = set([0x1400438b0, 0x1400797a0, 0x140079ca0, 0x14003be20])
for ins in currentProgram.getListing().getInstructions(True):
    text = str(ins).lower()
    if '0x3606' not in text:
        continue
    fn = getFunctionContaining(ins.getAddress())
    println('DIGIT_REF ' + str(ins.getAddress()) + ' ' + str(ins) + ' FUNCTION ' + str(fn))
    if fn is not None:
        targets.add(fn.getEntryPoint().getOffset())
for va in sorted(targets):
    fn = getFunctionAt(toAddr(va))
    println('FUNCTION ' + hex(va))
    if fn is None:
        raise RuntimeError('Missing function')
    result = api.decompileFunction(fn, 60, monitor)
    if not result.decompileCompleted():
        raise RuntimeError(str(result.getErrorMessage()))
    println(result.getDecompiledFunction().getC())
println('END HEALING DISPLAY REPORT')
api.dispose()
