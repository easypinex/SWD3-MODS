#@category SWD3
#
# Read-only, compact ordering report.  It inventories direct callers in the
# normal-damage path and prints only calls to HP application (0x1400851b0), the
# known Lua event dispatcher (0x14014ccf0), and normal damage helpers.

from ghidra.program.model.address import AddressSet

HP_APPLY = toAddr(0x1400851b0)
LUA_DISPATCH = toAddr(0x14014ccf0)
NORMAL_DAMAGE = toAddr(0x1400786b0)
NORMAL_RESOLVE = toAddr(0x14004de80)

function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()
listing = currentProgram.getListing()

def callers_of(address):
    result = {}
    for reference in reference_manager.getReferencesTo(address):
        function = function_manager.getFunctionContaining(reference.getFromAddress())
        if function is not None:
            result[function.getEntryPoint()] = function
    return result

roots = {}
for address in [HP_APPLY, NORMAL_DAMAGE, NORMAL_RESOLVE]:
    for entry, function in callers_of(address).items():
        roots[entry] = function

# Include one additional caller generation, because the native command state
# can invoke a resolution helper that invokes HP application internally.
for function in list(roots.values()):
    for entry, parent in callers_of(function.getEntryPoint()).items():
        roots[entry] = parent

println('SWD3 HD post-damage Lua-dispatch ordering inventory')
println('roots=' + str(len(roots)) + '; HP=' + str(HP_APPLY) + '; dispatcher=' + str(LUA_DISPATCH))
for entry in sorted(roots.keys()):
    function = roots[entry]
    interesting = []
    for instruction in listing.getInstructions(function.getBody(), True):
        flows = instruction.getFlows()
        for flow in flows:
            if flow == HP_APPLY:
                interesting.append((instruction.getAddress(), 'HP_APPLY', str(instruction)))
            elif flow == LUA_DISPATCH:
                interesting.append((instruction.getAddress(), 'LUA_DISPATCH', str(instruction)))
            elif flow == NORMAL_DAMAGE:
                interesting.append((instruction.getAddress(), 'NORMAL_DAMAGE', str(instruction)))
            elif flow == NORMAL_RESOLVE:
                interesting.append((instruction.getAddress(), 'NORMAL_RESOLVE', str(instruction)))
    if interesting:
        println('===== ' + function.getName() + ' @ ' + str(entry) + ' =====')
        for address, label, instruction_text in interesting:
            println(str(address) + ' ' + label + ' ' + instruction_text)
