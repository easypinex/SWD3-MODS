#@category SWD3
#
# Read-only timing report for Battle_DrawBGI(active_index).  This determines
# whether the event is emitted from the command/UI update before the manual
# action-6 target confirmation state, rather than inferring timing from the
# Lua name alone.  No program annotations or bytes are changed.

from ghidra.app.decompiler import DecompInterface

DRAW_FUNCTION = 0x1400402a0
MENU_TRANSITION = 0x1400574a0
CALLER_CANDIDATES = [0x14003f640, 0x1400589b0, 0x140055590, 0x14003e500]

reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()

println('SWD3 HD Battle_DrawBGI timing report')
println('===== callers of draw dispatcher @ ' + hex(DRAW_FUNCTION) + ' =====')
refs = reference_manager.getReferencesTo(toAddr(DRAW_FUNCTION))
for reference in refs:
    source = reference.getFromAddress()
    function = function_manager.getFunctionContaining(source)
    text = '<no enclosing function>'
    if function is not None:
        text = function.getName() + ' @ ' + str(function.getEntryPoint())
    println('  ' + str(source) + ' in ' + text + '; ' + str(getInstructionAt(source)))

println('===== callers of action-6 menu transition @ ' + hex(MENU_TRANSITION) + ' =====')
refs = reference_manager.getReferencesTo(toAddr(MENU_TRANSITION))
menu_callers = []
for reference in refs:
    source = reference.getFromAddress()
    function = function_manager.getFunctionContaining(source)
    text = '<no enclosing function>'
    if function is not None:
        text = function.getName() + ' @ ' + str(function.getEntryPoint())
        menu_callers.append(function.getEntryPoint().getOffset())
    println('  ' + str(source) + ' in ' + text + '; ' + str(getInstructionAt(source)))

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

function = getFunctionAt(toAddr(DRAW_FUNCTION))
println('===== Battle_DrawBGI dispatcher @ ' + hex(DRAW_FUNCTION) + ' =====')
if function is not None:
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        for index, line in enumerate(lines):
            if 'Battle_DrawBGI' not in line:
                continue
            start = max(0, index - 20)
            end = min(len(lines), index + 30)
            println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
            for current in range(start, end):
                println(str(current + 1) + ': ' + lines[current])
    else:
        println('<decompilation failed>')
else:
    println('<no function defined>')

for va in CALLER_CANDIDATES:
    function = getFunctionAt(toAddr(va))
    println('===== caller candidate @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        for index, line in enumerate(lines):
            if 'FUN_1400402a0' not in line and 'FUN_140055590' not in line and 'FUN_1400574a0' not in line:
                continue
            start = max(0, index - 25)
            end = min(len(lines), index + 28)
            println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
            for current in range(start, end):
                println(str(current + 1) + ': ' + lines[current])
    else:
        println('<decompilation failed>')

for va in sorted(set(menu_callers)):
    function = getFunctionAt(toAddr(va))
    println('===== menu-transition caller @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 360, monitor)
    if result.decompileCompleted() and result.getDecompiledFunction() is not None:
        lines = result.getDecompiledFunction().getC().splitlines()
        for index, line in enumerate(lines):
            if 'FUN_1400574a0' not in line:
                continue
            start = max(0, index - 28)
            end = min(len(lines), index + 18)
            println('--- lines ' + str(start + 1) + '-' + str(end) + ' ---')
            for current in range(start, end):
                println(str(current + 1) + ': ' + lines[current])
    else:
        println('<decompilation failed>')
decompiler.dispose()
