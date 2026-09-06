#@category SWD3
#
# Read-only instruction-level report for callbacks that looked absent in Lua
# probes.  Ghidra did not assign one dispatch tail to a function, so this
# intentionally follows the literal string xrefs and prints the surrounding
# native instructions plus references to the condition byte.

TARGETS = [
    ('Battle_CancelClick string xref', 0x1400b09ae),
    ('Battle_CmdSelectOK UI xref', 0x140057d6a),
    ('Battle_CmdSelectOK AI xref', 0x140044d14),
    ('Battle_InputDClick xref', 0x140053c64),
]
CONDITION = toAddr(0x1401fa92d)
reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()

def print_window(address, before_count, after_count):
    instruction = getInstructionAt(address)
    if instruction is None:
        println('  <no instruction>')
        return
    cursor = getInstructionBefore(address)
    before = []
    for _ in range(before_count):
        if cursor is None:
            break
        before.append(cursor)
        cursor = getInstructionBefore(cursor.getAddress())
    for item in reversed(before):
        println('  ' + str(item))
    cursor = instruction
    for _ in range(after_count):
        if cursor is None:
            break
        println('  ' + str(cursor))
        cursor = getInstructionAfter(cursor.getAddress())

println('SWD3 HD battle input event condition report')
for label, va in TARGETS:
    println('===== ' + label + ' @ ' + hex(va) + ' =====')
    print_window(toAddr(va), 12, 18)

println('===== condition byte ' + str(CONDITION) + ' references =====')
refs = reference_manager.getReferencesTo(CONDITION)
count = 0
for reference in refs:
    source = reference.getFromAddress()
    function = function_manager.getFunctionContaining(source)
    function_text = '<no enclosing function>'
    if function is not None:
        function_text = function.getName() + ' @ ' + str(function.getEntryPoint())
    println('  ' + str(source) + ' in ' + function_text + '; ' + str(getInstructionAt(source)))
    count += 1
println('  total=' + str(count))
