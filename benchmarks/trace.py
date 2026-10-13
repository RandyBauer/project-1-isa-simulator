#!/usr/bin/env python3
"""Watch a benchmark run one instruction at a time.

    python trace.py <program.asm> <memory.mem>

Prints one line per executed instruction: the step number, the instruction's
address (PC), the instruction, and what it changed -- a register, a memory
word, or where the PC goes next. A learning aid; it writes no files.
"""

import sys

import isaref
from isaref import f32, load_word, signed

BRANCHES = {'BEQ', 'BNE', 'BLT', 'BGE', 'BLTU', 'BGEU'}


def show_int(v):
    s = signed(v)
    return f'{s}' if -1000 < s < 1000 else f'{s} (0x{v:08X})'


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    with open(argv[1]) as f:
        prog = isaref.parse_program(f.read())
    _, mem = isaref.read_mem(argv[2])
    prev = {'R': [0] * 16, 'F': [0] * 16, 'mem': dict(mem), 'step': 0}

    print(f'{"step":>4}  {"PC":>3}  {"instruction":<24} what it did')
    print(f'{"----":>4}  {"---":>3}  {"-" * 24} {"-" * 40}')

    def on_step(ins, npc, R, F, m):
        prev['step'] += 1
        did = []
        for i in range(16):
            if R[i] != prev['R'][i]:
                did.append(f'R{i} = {show_int(R[i])}')
            if F[i] != prev['F'][i]:
                did.append(f'F{i} = {f32(F[i]):g}')
        for w in sorted({a & ~3 for a in m if m[a] != prev['mem'].get(a, 0)}):
            v = load_word(m, w)
            did.append(f'memory word at 0x{w:03X} = {show_int(v)}')
        if ins.name in BRANCHES:
            did.append(f'condition true: jump to {npc}' if npc != ins.addr + 1
                       else 'condition false: go on to the next line')
        elif ins.name in ('J', 'JAL', 'JR'):
            did.append(f'jump to {npc}')
        elif ins.name == 'HALT':
            did.append('stop')
        print(f'{prev["step"]:>4}  {ins.addr:>3}  {ins.text:<24} {"; ".join(did)}')
        prev['R'], prev['F'], prev['mem'] = list(R), list(F), dict(m)

    isaref.run(prog, mem, on_step=on_step)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
