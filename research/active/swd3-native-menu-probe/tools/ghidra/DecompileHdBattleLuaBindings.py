#@category SWD3
#
# Read-only decompilation of the registration routines for _BattleEnv and
# BattlePlayers properties.  Used to enumerate Lua-visible fields without
# touching the game process.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('battle environment registration', 0x14004f270),
    ('battle-player userdata registration', 0x1400e0020),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
println('SWD3 HD battle Lua binding registration report')
for label, va in TARGETS:
    function = getFunctionAt(toAddr(va))
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        println(result.getDecompiledFunction().getC())
    else:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
decompiler.dispose()
