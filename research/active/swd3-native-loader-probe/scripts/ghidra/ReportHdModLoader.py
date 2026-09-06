#@category SWD3
#
# Read-only loader report for the verified Steam HD executable.  It neither
# creates functions nor labels, changes types, patches bytes, or saves the
# program.  For each loader-related ASCII string it reports its data address,
# every reference, the containing function, direct callers, and a bounded
# decompiler excerpt.

from ghidra.app.decompiler import DecompInterface

KEYWORDS = [
    'SteamMods.txt', 'modlist.txt', 'Load mod [%s]', 'Load ssmod', 'LoadSSMOD',
    'MODName', 'MODAuthor', 'MODinfo', 'MODpicture', 'MODsystemMOD',
    'MODbundleSave', 'MODDate', 'MODVersion', 'MODGameVersion',
    'MODrequirement', 'MODelimination', '-- [%s%s] disable in MOD requirement.',
    '-- [%s%s] disable in modlist.', 'file is not SSMOD!! %s',
    'game version too old!! need v%d.%d (%s)', 'ext', 'ssmod'
]
MODULE_APIS = ['LoadLibraryA', 'LoadLibraryW', 'LoadLibraryExA', 'LoadLibraryExW', 'GetProcAddress']

listing = currentProgram.getListing()
reference_manager = currentProgram.getReferenceManager()
function_manager = currentProgram.getFunctionManager()
decompiler = DecompInterface()
decompiler.openProgram(currentProgram)

def ascii_value(data):
    value = data.getValue()
    if value is None:
        return None
    try:
        return str(value)
    except:
        return None

def callers_for(function):
    callers = set()
    for reference in reference_manager.getReferencesTo(function.getEntryPoint()):
        caller = function_manager.getFunctionContaining(reference.getFromAddress())
        if caller is not None:
            callers.add(str(caller.getEntryPoint()))
    return sorted(callers)

def excerpt_for(function):
    result = decompiler.decompileFunction(function, 90, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        return '<decompilation unavailable>'
    code = result.getDecompiledFunction().getC()
    lines = code.splitlines()
    return '\n'.join(lines[:65])

def function_references(function):
    result = []
    for reference in reference_manager.getReferencesTo(function.getEntryPoint()):
        caller = function_manager.getFunctionContaining(reference.getFromAddress())
        if caller is not None:
            result.append((caller.getEntryPoint(), caller, reference))
    return result

print('SWD3 HD native MOD loader report (read-only)')
print('program=' + currentProgram.getName())

keyword_data = {}
for data in listing.getDefinedData(True):
    value = ascii_value(data)
    if value is None:
        continue
    normalized = value.lower()
    for keyword in KEYWORDS:
        if normalized == keyword.lower():
            keyword_data.setdefault(keyword, []).append(data)

loader_functions = {}
for keyword in KEYWORDS:
    matches = keyword_data.get(keyword, [])
    print('\n=== exact string: ' + keyword + '; defined-data matches=' + str(len(matches)) + ' ===')
    for data in matches:
        print('data=' + str(data.getAddress()) + '; value=' + ascii_value(data))
        for reference in reference_manager.getReferencesTo(data.getAddress()):
            function = function_manager.getFunctionContaining(reference.getFromAddress())
            location = str(reference.getFromAddress())
            if function is None:
                print('  xref=' + location + '; function=<none>; type=' + str(reference.getReferenceType()))
                continue
            loader_functions[function.getEntryPoint()] = function
            print('  xref=' + location + '; function=' + str(function.getEntryPoint()) + '; type=' + str(reference.getReferenceType()))

print('\n=== deduplicated MOD-loader functions=' + str(len(loader_functions)) + ' ===')
for entry in sorted(loader_functions.keys()):
    function = loader_functions[entry]
    print('function=' + str(entry) + '; callers=' + ', '.join(callers_for(function)))
    print(excerpt_for(function))
    print('---')

print('\nNative module API xrefs are reported separately by ReportHdModuleApiXrefs.py.')
decompiler.dispose()
