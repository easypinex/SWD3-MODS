#@category SWD3
#
# Read-only inventory of instructions using the signed or unsigned value 9999.

from ghidra.program.model.scalar import Scalar

function_manager = currentProgram.getFunctionManager()
listing = currentProgram.getListing()
instructions = listing.getInstructions(True)
matches = []

while instructions.hasNext() and not monitor.isCancelled():
    instruction = instructions.next()
    found = False
    for operand_index in range(instruction.getNumOperands()):
        for operand in instruction.getOpObjects(operand_index):
            if isinstance(operand, Scalar):
                value = operand.getSignedValue()
                unsigned = operand.getUnsignedValue()
                if value == 9999 or value == -9999 or unsigned == 9999:
                    found = True
                    break
        if found:
            break
    if found:
        matches.append(instruction)

println('SWD3 HD instructions with 9999 / -9999 immediate values: ' + str(len(matches)))
for instruction in matches:
    address = instruction.getAddress()
    function = function_manager.getFunctionContaining(address)
    println(str(address) + ' in ' + str(function) + '; ' + str(instruction))
