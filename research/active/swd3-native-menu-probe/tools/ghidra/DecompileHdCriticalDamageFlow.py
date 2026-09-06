#@category SWD3
#
# Read-only decompilation of helpers directly reached after the critical flag is
# chosen during a normal attack in Steam HD 4.0.5.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('critical_action_payload_builder', 0x14008c090),
    ('normal_action_followup', 0x1400786b0),
    ('damage_action_record_builder', 0x14008ba80),
    ('damage_action_special_builder', 0x1400875e0),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD normal critical -> damage flow report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 180, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
