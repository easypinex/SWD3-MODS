#@category SWD3
#
# Read-only proof report for whether the native action-selection queue has an
# existing Lua surface.  It lists every direct reference to the queue globals
# and every registration-site reference to them.  It intentionally does not
# write labels, data types, comments, or changes into the Ghidra project.

from ghidra.program.model.address import AddressSet

QUEUE_GLOBALS = [
    ('queued action array', 0x1401aa918),
    ('queued action count/state', 0x1401aa8f4),
]

LUA_REGISTRATIONS = [
    ('_BattleEnv registration', 0x14004f270),
    ('battle-player userdata registration', 0x1400e0020),
]

reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()
listing = currentProgram.getListing()

registration_bodies = []
for label, va in LUA_REGISTRATIONS:
    function = getFunctionAt(toAddr(va))
    if function is None:
        println('WARNING: missing ' + label)
        continue
    registration_bodies.append((label, function.getBody()))

println('SWD3 HD queued-action Lua exposure report')
println('The tested native queue is DAT_1401aa918; all direct xrefs follow.')
for label, va in QUEUE_GLOBALS:
    address = toAddr(va)
    println('===== ' + label + ' @ ' + str(address) + ' =====')
    refs = reference_manager.getReferencesTo(address)
    count = 0
    registration_hits = 0
    for reference in refs:
        source = reference.getFromAddress()
        function = function_manager.getFunctionContaining(source)
        function_text = '<no enclosing function>'
        if function is not None:
            function_text = function.getName() + ' @ ' + str(function.getEntryPoint())
        registration_text = ''
        for registration_label, body in registration_bodies:
            if body.contains(source):
                registration_text = '; IN ' + registration_label
                registration_hits += 1
        println('  ' + str(source) + ' in ' + function_text + registration_text + '; ' + str(listing.getInstructionAt(source)))
        count += 1
    println('  directReferenceCount=' + str(count))
    println('  directReferencesInsideLuaRegistration=' + str(registration_hits))

println('===== registered BattlePlayers scalar offsets =====')
println('AI_Command=0x39dc; AI_SelectItem=0x39e4; AI_PMenu=0x39e0; AI_Target=0x39ec; AI_TargetIsEnemySide=0x39f4; AI_SelectAttackEffect=0x39e8; Action_qq=0x3568')
println('These are per-actor userdata offsets; DAT_1401aa918 is a separate global array.')
