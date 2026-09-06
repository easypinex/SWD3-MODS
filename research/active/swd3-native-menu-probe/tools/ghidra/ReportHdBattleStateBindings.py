#@category SWD3
#
# Read-only xref report for named Lua-visible battle state.  It does not infer
# that an unnamed native queue is exposed merely because action selection
# writes it; the report inventories the actual string-keyed binding surfaces
# around BattlePlayers and _BattleEnv.

TARGETS = [
    '_BattleEnv',
    'BattlePlayers',
    'AI_Command',
    'AI_Target',
    'AI_TargetIsEnemySide',
    'AI_SelectItem',
    'NowMenu',
    'GetNowSelectPlayerID',
    'SetNowSelectPlayerID',
    '_PlayerCommands',
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

println('SWD3 HD named battle-state binding xrefs')
for name in TARGETS:
    address = found.get(name)
    if address is None:
        println('TARGET ' + name + ': <no defined string>')
        continue
    println('TARGET ' + name + ' @ ' + str(address))
    refs = reference_manager.getReferencesTo(address)
    count = 0
    for reference in refs:
        source = reference.getFromAddress()
        function = function_manager.getFunctionContaining(source)
        function_text = '<no enclosing function>'
        if function is not None:
            function_text = function.getName() + ' @ ' + str(function.getEntryPoint())
        println('  ' + str(source) + ' in ' + function_text + '; ' + str(getInstructionAt(source)))
        count += 1
    println('  referenceCount=' + str(count))
