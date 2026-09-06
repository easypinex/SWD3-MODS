#@category SWD3
#
# Read-only decompilation of the native helpers called by battle action code 6.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('capture_eligibility_gate', 0x1400752b0),
    ('capture_success_state_setup', 0x14006fed0),
    ('capture_success_followup', 0x140072e30),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD native capture eligibility decompilation report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 90, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    println(result.getDecompiledFunction().getC())
decompiler.dispose()
