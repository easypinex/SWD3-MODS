"""Locate x64 code references to a named Lua binding string in swd3.exe.

Read-only research helper.  It parses PE sections, finds an ASCII string such
as ``Menu\0``, then disassembles .text and prints nearby instructions for every
RIP-relative reference to that exact string address.
"""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

import pefile
from capstone import CS_ARCH_X86, CS_MODE_64, Cs
from capstone.x86_const import X86_OP_MEM, X86_REG_RIP


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("exe", type=Path)
    parser.add_argument("symbol", help="ASCII binding name, for example Menu")
    parser.add_argument("--context", type=int, default=18)
    args = parser.parse_args()

    raw = args.exe.read_bytes()
    needle = args.symbol.encode("ascii") + b"\0"
    string_offsets = [
        offset
        for offset in range(len(raw))
        if raw.startswith(needle, offset)
        and (offset == 0 or raw[offset - 1] == 0)
    ]
    if not string_offsets:
        raise SystemExit(f"No exact string found: {args.symbol!r}")

    pe = pefile.PE(str(args.exe), fast_load=True)
    image_base = pe.OPTIONAL_HEADER.ImageBase
    section_for_offset = {}
    for section in pe.sections:
        start = section.PointerToRawData
        end = start + section.SizeOfRawData
        for offset in string_offsets:
            if start <= offset < end:
                rva = section.VirtualAddress + offset - start
                section_for_offset[offset] = (section.Name.rstrip(b"\0").decode(), image_base + rva)

    print("string addresses:")
    for offset in string_offsets:
        section, va = section_for_offset.get(offset, ("<not mapped>", 0))
        print(f"  raw=0x{offset:x} section={section} va=0x{va:x}")

    text = next((s for s in pe.sections if s.Name.rstrip(b"\0") == b".text"), None)
    if text is None:
        raise SystemExit("No .text section")
    text_raw = raw[text.PointerToRawData : text.PointerToRawData + text.SizeOfRawData]
    text_va = image_base + text.VirtualAddress
    dis = Cs(CS_ARCH_X86, CS_MODE_64)
    dis.detail = True
    instructions = list(dis.disasm(text_raw, text_va))

    wanted = {va for _, va in section_for_offset.values()}
    pointer_sites = []
    for wanted_va in wanted:
        for pointer_size, encoded in ((8, struct.pack("<Q", wanted_va)), (4, struct.pack("<I", wanted_va - image_base))):
            start = 0
            while True:
                offset = raw.find(encoded, start)
                if offset < 0:
                    break
                for section in pe.sections:
                    section_start = section.PointerToRawData
                    section_end = section_start + section.SizeOfRawData
                    if section_start <= offset < section_end:
                        section_name = section.Name.rstrip(b"\0").decode()
                        pointer_va = image_base + section.VirtualAddress + offset - section_start
                        pointer_sites.append((offset, section_name, pointer_va, pointer_size))
                        break
                start = offset + 1

    print(f"absolute-pointer sites={len(pointer_sites)}")
    for offset, section_name, pointer_va, pointer_size in pointer_sites:
        print(f"  raw=0x{offset:x} section={section_name} va=0x{pointer_va:x} width={pointer_size}")

    wanted.update(pointer_va for _, _, pointer_va, _ in pointer_sites)
    matches = []
    for index, instruction in enumerate(instructions):
        for operand in instruction.operands:
            if operand.type == X86_OP_MEM and operand.mem.base == X86_REG_RIP:
                target = instruction.address + instruction.size + operand.mem.disp
                if target in wanted:
                    matches.append(index)

    print(f"references={len(matches)}")
    for index in matches:
        print(f"\n--- reference at 0x{instructions[index].address:x} ---")
        start = max(0, index - args.context)
        end = min(len(instructions), index + args.context + 1)
        for instruction in instructions[start:end]:
            marker = ">" if instruction is instructions[index] else " "
            print(f"{marker} 0x{instruction.address:x}: {instruction.mnemonic:<8} {instruction.op_str}")


if __name__ == "__main__":
    main()
