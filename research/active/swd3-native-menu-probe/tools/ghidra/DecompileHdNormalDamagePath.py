#@category SWD3
#
# Read-only decompilation of the native normal-attack execution helpers.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('normal_attack_resolution', 0x14004de80),
    ('normal_attack_preparation', 0x1400712c0),
    ('critical_hit_resolution', 0x140071970),
    ('damage_value_cap_path', 0x14004b660),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD normal attack / critical damage decompilation report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 90, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
