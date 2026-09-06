#@category SWD3
#
# Read-only import-to-caller report.  It is deliberately separate from the
# loader-string report so DLL-loader imports are not confused with MOD paths.

from ghidra.app.decompiler import DecompInterface

TARGETS = set(['LoadLibraryA', 'LoadLibraryW', 'LoadLibraryExA', 'LoadLibraryExW', 'GetProcAddress'])
external_manager = currentProgram.getExternalManager()
reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

def excerpt(function):
    result = decompiler.decompileFunction(function, 180, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        return '<decompilation unavailable>'
    return '\n'.join(result.getDecompiledFunction().getC().splitlines()[:180])

found = set()
print('Native module API xrefs (read-only)')
for library in external_manager.getExternalLibraryNames():
    for location in external_manager.getExternalLocations(library):
        label = location.getLabel()
        if label not in TARGETS:
            continue
        found.add(label)
        address = location.getExternalSpaceAddress()
        print('\n=== ' + library + '!' + label + '; external=' + str(address) + ' ===')
        callers = {}
        for reference in reference_manager.getReferencesTo(address):
            caller = function_manager.getFunctionContaining(reference.getFromAddress())
            print('xref=' + str(reference.getFromAddress()) + '; type=' + str(reference.getReferenceType()) + '; caller=' + (str(caller.getEntryPoint()) if caller else '<none>'))
            if caller is not None:
                callers[caller.getEntryPoint()] = caller
        print('distinct direct callers=' + str(len(callers)))
        for entry in sorted(callers.keys()):
            print('caller=' + str(entry))
            print(excerpt(callers[entry]))
            print('---')
for target in sorted(TARGETS - found):
    print('\n=== ' + target + ' ===\nnot imported')
decompiler.dispose()
