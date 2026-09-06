#@category SWD3
#
# Read-only Ghidra post-analysis report for the Steam HD 4.0.5 executable.
# Addresses are validated image-base VAs of NUL-terminated binding/event strings.
# The report queries Ghidra's reference database after auto-analysis; it never
# modifies the executable or the program database.

TARGETS = [
    ('OnEvent', 0x14017e268),
    ('InputKeyDown', 0x14017a398),
    ('InputKeyUp', 0x14017a3a8),
    ('InputClick', 0x14017a3b8),
    ('Battle_InputKeyDown', 0x140172b88),
    ('Battle_InputClick', 0x140172ba0),
    ('Battle_CmdSelectOK', 0x140172788),
    ('BattlePlayerAI', 0x1401727b0),
    ('BattlePlayerAI_after', 0x1401727f8),
    ('NowMenu', 0x1401725b8),
    ('CanOBSOLT', 0x140172670),
    ('CanObsolt', 0x140178938),
    ('Obsolt', 0x1401738ac)
]

reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()

println('SWD3 HD battle/Lua reference report')
println('program=' + currentProgram.getName() + '; imageBase=' + str(currentProgram.getImageBase()))

for target_name, target_va in TARGETS:
    target_address = toAddr(target_va)
    data = getDataAt(target_address)
    data_value = '<no-defined-data>'
    if data is not None:
        try:
            data_value = str(data.getValue())
        except:
            data_value = '<unreadable-data>'

    println('TARGET ' + target_name + ' @ ' + str(target_address) + '; data=' + data_value)
    refs = reference_manager.getReferencesTo(target_address)
    count = 0
    while refs.hasNext():
        ref = refs.next()
        count += 1
        source = ref.getFromAddress()
        function = function_manager.getFunctionContaining(source)
        function_name = '<no-defined-function>'
        if function is not None:
            function_name = function.getName() + ' @ ' + str(function.getEntryPoint())
        instruction = getInstructionAt(source)
        instruction_text = '<no-instruction>'
        if instruction is not None:
            instruction_text = str(instruction)
        println('  REF ' + str(ref.getReferenceType()) + ' from ' + str(source)
            + ' in ' + function_name + '; ' + instruction_text)
    println('  referenceCount=' + str(count))
