#@category SWD3
#
# Read-only compact call/data-flow summary for the normal Lua event dispatcher
# and the alternate BattleEnv callback helper.  This keeps research output
# reviewable without treating a string name as proof of a public hook.

import re
from ghidra.app.decompiler import DecompInterface

TARGETS = [
    ('OnEvent dispatcher', 0x14014ccf0),
    ('BattleEnv wrapper', 0x14014dc20),
    ('BattleEnv inner helper', 0x14014dd30),
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
for label, va in TARGETS:
    function = getFunctionAt(toAddr(va))
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    if function is None:
        println('<no function defined>')
        continue
    result = decompiler.decompileFunction(function, 300, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        println('<decompilation failed: ' + str(result.getErrorMessage()) + '>')
        continue
    code = result.getDecompiledFunction().getC()
    calls = sorted(set(re.findall(r'\b(?:FUN|lua)_[0-9A-Za-z_]+(?=\()', code)))
    println('calls=' + ', '.join(calls))
    if va == 0x14014dd30:
        lines = code.splitlines()
        for index, line in enumerate(lines):
            if 'FUN_140008070' in line:
                start = max(0, index - 3)
                end = min(len(lines), index + 10)
                println('--- name-resolution context lines ' + str(start + 1) + '-' + str(end) + ' ---')
                for context_line in lines[start:end]:
                    println(context_line)
    for line in code.splitlines():
        if ('param_2' in line or 'param_3' in line or 'param_4' in line or 'param_5' in line or
                '+ 0x50' in line or '+ 0x60' in line or 'lua_' in line or 'FUN_14014' in line):
            println(line)
decompiler.dispose()
