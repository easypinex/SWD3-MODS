#!/usr/bin/env python3
"""Read-only PE import and loader-string inventory; no third-party modules."""

from __future__ import print_function
import struct
import sys

TARGET_APIS = {
    b'LoadLibraryA', b'LoadLibraryW', b'LoadLibraryExA', b'LoadLibraryExW',
    b'GetProcAddress', b'LdrLoadDll', b'LdrGetProcedureAddress'
}
TARGET_STRINGS = TARGET_APIS | {
    b'.dll', b'plugin', b'plugins', b'modlist.txt', b'SteamMods.txt',
    b'LoadSSMOD', b'Load ssmod', b'workshop'
}

def u16(data, offset):
    return struct.unpack_from('<H', data, offset)[0]

def u32(data, offset):
    return struct.unpack_from('<I', data, offset)[0]

def cstring(data, offset):
    end = data.find(b'\0', offset)
    if end < 0:
        raise ValueError('unterminated string')
    return data[offset:end]

def rva_to_offset(rva, sections):
    for virtual_address, virtual_size, raw_offset, raw_size in sections:
        span = max(virtual_size, raw_size)
        if virtual_address <= rva < virtual_address + span:
            return raw_offset + (rva - virtual_address)
    raise ValueError('RVA 0x%x is outside file-backed sections' % rva)

def imports(data):
    if data[:2] != b'MZ':
        raise ValueError('not an MZ executable')
    pe_offset = u32(data, 0x3c)
    if data[pe_offset:pe_offset + 4] != b'PE\0\0':
        raise ValueError('missing PE signature')
    coff = pe_offset + 4
    section_count = u16(data, coff + 2)
    optional_size = u16(data, coff + 16)
    optional = coff + 20
    magic = u16(data, optional)
    if magic != 0x20B:
        raise ValueError('expected PE32+ (got 0x%x)' % magic)
    data_directory = optional + 112
    import_rva = u32(data, data_directory + 8)
    section_offset = optional + optional_size
    sections = []
    for index in range(section_count):
        offset = section_offset + index * 40
        sections.append((u32(data, offset + 12), u32(data, offset + 8),
                         u32(data, offset + 20), u32(data, offset + 16)))
    if import_rva == 0:
        return []
    result = []
    descriptor = rva_to_offset(import_rva, sections)
    while True:
        original_first_thunk = u32(data, descriptor)
        name_rva = u32(data, descriptor + 12)
        first_thunk = u32(data, descriptor + 16)
        if original_first_thunk == 0 and name_rva == 0 and first_thunk == 0:
            break
        dll_name = cstring(data, rva_to_offset(name_rva, sections))
        thunk_rva = original_first_thunk or first_thunk
        thunk = rva_to_offset(thunk_rva, sections)
        while True:
            value = struct.unpack_from('<Q', data, thunk)[0]
            if value == 0:
                break
            if value & (1 << 63):
                symbol = b'#ordinal_%d' % (value & 0xffff)
            else:
                symbol = cstring(data, rva_to_offset(value, sections) + 2)
            result.append((dll_name, symbol))
            thunk += 8
        descriptor += 20
    return result

def present_strings(data, target):
    hits = []
    for token in sorted(target):
        ascii_count = data.count(token)
        utf16_count = data.count(b''.join(bytes((value, 0)) for value in token))
        if ascii_count or utf16_count:
            hits.append((token.decode('ascii'), ascii_count, utf16_count))
    return hits

def main(path):
    with open(path, 'rb') as source:
        data = source.read()
    all_imports = imports(data)
    dynamic = [(dll.decode('ascii', 'replace'), name.decode('ascii', 'replace'))
               for dll, name in all_imports if name in TARGET_APIS]
    print('PE import and loader-string inventory (read-only)')
    print('input=' + path)
    print('total_imports=%d' % len(all_imports))
    print('dynamic-loader imports=%d' % len(dynamic))
    for dll, name in dynamic:
        print('%s!%s' % (dll, name))
    print('targeted ASCII / UTF-16LE string hits:')
    for token, ascii_count, utf16_count in present_strings(data, TARGET_STRINGS):
        print('%s; ASCII=%d; UTF16LE=%d' % (token, ascii_count, utf16_count))

if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('usage: Get-PeImports.py <x64-pe>')
    main(sys.argv[1])
