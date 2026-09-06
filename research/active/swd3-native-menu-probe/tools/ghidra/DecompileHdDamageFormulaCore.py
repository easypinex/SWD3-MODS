#@category SWD3
#
# Read-only decompilation of the native damage-value functions reached by normal attacks.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('damage_formula_with_effect_state', 0x140089570),
    ('damage_formula_basic_path', 0x14008a370),
    ('damage_formula_support', 0x14008a280),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD damage formula core decompilation report')
for target_name, target_va in TARGETS:
    function = getFunctionAt(toAddr(target_va))
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 120, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
