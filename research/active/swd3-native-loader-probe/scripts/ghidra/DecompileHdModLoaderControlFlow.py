#@category SWD3
#
# Read-only bounded decompilation of the native loader call chain identified
# by ReportHdModLoader.py.  Addresses are valid only for its recorded SHA-256.

from ghidra.app.decompiler import DecompInterface

TARGETS = [
    0x1400efec0, # SteamMods.txt discovery
    0x1400f5e00, # MOD requirement evaluation
    0x1400f78c0, # manifest parse / ext-vs-ssmod dispatch
    0x1400f97d0, # .ssmod load / decompression path
    0x1400fad20, # modlist disabled-state handling
    0x1400fbbc0, # modlist file read
    0x1400fcdb0, # archive build/reader boundary
]

decompiler = DecompInterface()
decompiler.openProgram(currentProgram)
manager = currentProgram.getFunctionManager()
for address in TARGETS:
    function = manager.getFunctionAt(toAddr(address))
    print('\n=== ' + hex(address) + ' ===')
    if function is None:
        print('<function unavailable>')
        continue
    result = decompiler.decompileFunction(function, 240, monitor)
    if not result.decompileCompleted() or result.getDecompiledFunction() is None:
        print('<decompilation unavailable>')
        continue
    print(result.getDecompiledFunction().getC())
decompiler.dispose()
