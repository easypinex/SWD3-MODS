#@category SWD3
# Read-only companion to ReportHdBossDamageBranches.py.
from ghidra.app.decompiler import DecompInterface
EXPECTED = '63f1d83d8c3a756d17640d9022e19f8928741b091f0e47abbdb22c0ccf6c9523'
if str(currentProgram.getExecutableSHA256()).lower() != EXPECTED:
    raise RuntimeError('Executable SHA-256 mismatch')
println('SWD3 HD boss damage field evidence; SHA256=' + EXPECTED)
for va in [0x140173da0,0x140173da4,0x140173da8,0x140173dac,0x140173dbc,0x14017875c]:
    raw = []
    for offset in range(64):
        byte = currentProgram.getMemory().getByte(toAddr(va + offset)) & 255
        if byte == 0:
            break
        raw.append(chr(byte))
    println('ASCII ' + hex(va) + ' ' + ''.join(raw))
listing = currentProgram.getListing()
for start, end in [(0x1400859f0,0x140085a50),(0x140089b30,0x140089cb0)]:
    println('INSTRUCTIONS ' + hex(start))
    ins = listing.getInstructionAt(toAddr(start))
    if ins is None:
        ins = listing.getInstructionAfter(toAddr(start))
    while ins is not None and ins.getAddress().getOffset() <= end:
        println(str(ins.getAddress()) + ' ' + str(ins))
        ins = ins.getNext()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
for va in [0x140167e10,0x14007a8e0]:
    fn = getFunctionAt(toAddr(va))
    println('FUNCTION ' + hex(va))
    result = decompiler.decompileFunction(fn, 120, monitor)
    if result.decompileCompleted():
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompile failed>')
decompiler.dispose()
println('END FIELD EVIDENCE')
