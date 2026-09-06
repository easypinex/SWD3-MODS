#@category SWD3
#
# Read-only call-site report for the known normal-attack damage application path.
# It looks for a Lua event-dispatch call after HP application and before the
# native action state returns.  Addresses apply only to the verified HD 4.0.5
# executable copy.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('damage_amount_apply', 0x1400851b0),
    ('normal_damage_calculate_and_apply', 0x1400786b0),
    ('normal_attack_resolution', 0x14004de80),
]

function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

println('SWD3 HD damage completion / Lua event call-site report')
for label, va in TARGETS:
    target = toAddr(va)
    print('\n===== target ' + label + ' @ ' + str(target) + ' =====\n')
    callers = {}
    for reference in reference_manager.getReferencesTo(target):
        source = reference.getFromAddress()
        caller = function_manager.getFunctionContaining(source)
        println(str(reference.getReferenceType()) + ' from ' + str(source) +
                '; caller=' + str(caller) + '; instruction=' + str(getInstructionAt(source)))
        if caller is not None:
            callers[caller.getEntryPoint()] = caller
    for entry in sorted(callers.keys()):
        caller = callers[entry]
        println('--- caller decompile ' + caller.getName() + ' @ ' + str(entry) + ' ---')
        result = decompiler.decompileFunction(caller, 180, monitor)
        if result.decompileCompleted() and result.getDecompiledFunction() is not None:
            println(result.getDecompiledFunction().getC())
        else:
            println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')

decompiler.dispose()
