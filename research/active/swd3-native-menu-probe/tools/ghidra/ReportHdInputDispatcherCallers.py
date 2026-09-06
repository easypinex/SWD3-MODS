#@category SWD3
#
# Read-only call-site inventory for the HD global and battle input dispatchers.

TARGETS = [
    ('lua_event_dispatcher', 0x14014ccf0),
    ('global_input_dispatch_a', 0x1401248c0),
    ('global_input_dispatch_b', 0x140124a80),
    ('battle_input_dispatch', 0x140053ae0),
    ('battle_command_dispatch', 0x1400574a0),
]

function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()

println('SWD3 HD input dispatcher caller inventory')
for target_name, target_va in TARGETS:
    target = toAddr(target_va)
    println('===== ' + target_name + ' @ ' + hex(target_va) + ' =====')
    references = reference_manager.getReferencesTo(target)
    count = 0
    for reference in references:
        from_addr = reference.getFromAddress()
        caller = function_manager.getFunctionContaining(from_addr)
        caller_name = caller.getName() if caller is not None else '<no enclosing function>'
        caller_entry = str(caller.getEntryPoint()) if caller is not None else '<none>'
        println('  ' + str(from_addr) + ' in ' + caller_name + ' @ ' + caller_entry +
                '; type=' + str(reference.getReferenceType()))
        count += 1
    println('  total=' + str(count))
