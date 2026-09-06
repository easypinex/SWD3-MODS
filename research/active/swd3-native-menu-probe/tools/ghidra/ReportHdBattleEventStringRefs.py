#@category SWD3
#
# Read-only cross-check for battle event names defined by the shipped Lua
# archive.  For each exact native string, report every xref and its enclosing
# function.  This distinguishes a table declaration in Lua from a native
# dispatcher call without relying on console observations.

TARGETS = [
    'Battle_Enter',
    'Battle_DrawBGI',
    'Battle_InputKeyDown',
    'Battle_InputClick',
    'Battle_InputDClick',
    'Battle_CmdSelectOK',
    'Battle_EnemyInit',
    'Battle_PlayerInit',
    'Battle_NPCInit',
    'Battle_KeeperInit',
    'Battle_Dead',
    'Battle_StopSkill',
    'Battle_Freeze',
    'Battle_SetActive',
    'Battle_RestoreItem',
    'Battle_CancelClick',
    'CheckLearnSpecialSkill',
    'CheckStatSpecialSkill',
    'BattleCriticalHitRate',
    'BattleEnemyEscapeRate',
    'BattleGain',
    'BattleEnemyAI',
    'BattlePlayerAI',
    'BattlePlayerAI_after',
    'BattleNPCAI',
]

listing = currentProgram.getListing()
reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()

found = {}
iterator = listing.getDefinedData(True)
while iterator.hasNext():
    data = iterator.next()
    try:
        value = str(data.getValue())
    except:
        continue
    if value in TARGETS:
        found[value] = data.getAddress()

println('SWD3 HD battle event string xref report')
for target in TARGETS:
    address = found.get(target)
    if address is None:
        println('TARGET ' + target + ': <no defined ASCII string>')
        continue
    println('TARGET ' + target + ' @ ' + str(address))
    references = reference_manager.getReferencesTo(address)
    count = 0
    for reference in references:
        source = reference.getFromAddress()
        function = function_manager.getFunctionContaining(source)
        function_text = '<no enclosing function>'
        if function is not None:
            function_text = function.getName() + ' @ ' + str(function.getEntryPoint())
        instruction = getInstructionAt(source)
        println('  REF ' + str(reference.getReferenceType()) + ' from ' + str(source) +
                ' in ' + function_text + '; ' + str(instruction))
        if target == 'Battle_CancelClick':
            println('  instruction window:')
            cursor = getInstructionBefore(source)
            back = []
            for _ in range(8):
                if cursor is None:
                    break
                back.append(cursor)
                cursor = getInstructionBefore(cursor.getAddress())
            for previous in reversed(back):
                println('    ' + str(previous))
            cursor = instruction
            for _ in range(16):
                if cursor is None:
                    break
                println('    ' + str(cursor))
                cursor = getInstructionAfter(cursor.getAddress())
        count += 1
    println('  referenceCount=' + str(count))
