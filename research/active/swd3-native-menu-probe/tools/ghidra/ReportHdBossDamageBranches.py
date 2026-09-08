#@category SWD3
# Read-only; fixed addresses require the SHA-256 below. No game/process writes.
from ghidra.app.decompiler import DecompInterface

EXPECTED = '63f1d83d8c3a756d17640d9022e19f8928741b091f0e47abbdb22c0ccf6c9523'
if str(currentProgram.getExecutableSHA256()).lower() != EXPECTED:
    raise RuntimeError('Executable SHA-256 mismatch')
println('SWD3 HD boss damage branches; SHA256=' + EXPECTED)
listing = currentProgram.getListing()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
targets = set([0x140085890, 0x140086600, 0x1400e0020])
# Candidate inventory only: immediate bit test at field +8; not every match is ItemType.
for ins in listing.getInstructions(True):
    text = str(ins).lower()
    if ins.getMnemonicString().upper() not in ['TEST', 'AND']:
        continue
    if '+ 0x8]' not in text and '+0x8]' not in text:
        continue
    if not text.endswith('0x20'):
        continue
    fn = getFunctionContaining(ins.getAddress())
    println('BIT20_CANDIDATE ' + str(ins.getAddress()) + ' ' + str(ins) + ' FUNCTION ' + str(fn))
    if fn is not None:
        va = fn.getEntryPoint().getOffset()
        if 0x140030000 <= va < 0x140090000:
            targets.add(va)
for va in sorted(targets):
    fn = getFunctionAt(toAddr(va))
    println('FUNCTION ' + hex(va))
    if fn is None:
        println('<no function>')
        continue
    result = decompiler.decompileFunction(fn, 180, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompile failed: ' + str(result.getErrorMessage()) + '>')
println('END BOSS DAMAGE REPORT')
decompiler.dispose()
