#@category SWD3
#
# Read-only instruction and reference report for the BSC.Obsolt binding target.

TARGET = toAddr(0x14006c590)
listing = currentProgram.getListing()
function_manager = currentProgram.getFunctionManager()
reference_manager = currentProgram.getReferenceManager()

println('SWD3 HD BSC.Obsolt binding target report')
println('target=' + str(TARGET))
containing = function_manager.getFunctionContaining(TARGET)
println('containingFunction=' + (str(containing) if containing is not None else '<none>'))
println('symbol=' + str(getSymbolAt(TARGET)))

println('===== instructions =====')
instruction = getInstructionAt(TARGET)
for index in range(48):
    if instruction is None:
        break
    println(str(instruction.getAddress()) + ': ' + str(instruction))
    instruction = instruction.getNext()

println('===== references to target =====')
references = reference_manager.getReferencesTo(TARGET)
for reference in references:
    source = reference.getFromAddress()
    caller = function_manager.getFunctionContaining(source)
    caller_text = str(caller) if caller is not None else '<none>'
    println(str(reference.getReferenceType()) + ' from ' + str(source) + ' in ' + caller_text +
            '; ' + str(getInstructionAt(source)))
