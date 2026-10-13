#!/usr/bin/env python3
"""Build and check the ISAbench submission folder.

For each benchmark: replace the labels in src/<name>.s to make
ISAbench/<name>.asm, write the input memory file, run the reference model
(isaref.py) on the written files, write the expected final memory, and check
the result against values computed independently of the model.

    python build.py
"""

import re
import sys
from pathlib import Path

import isaref
from isaref import float_bits, f32, load_word

HERE = Path(__file__).resolve().parent
SRC = HERE / 'src'
OUT = HERE / 'ISAbench'

TEST_ALL_WORDS = {
    0x000: 0xFFFFFFEC,          # -20
    0x004: 0x00000006,          # 6
    0x008: 0xF0F0F0F0,
    0x00C: 0x3C3C3C3C,
    0x010: float_bits(6.5),
    0x014: float_bits(-2.0),
    0x0FC: 0xCAFEF00D,
}

# MAXFINDER data sets. None contains 0, so every array word appears in the
# memory file (a word that is all zeros is left out, since it is 0 anyway).
INT_DATA = [17, -45, 302, -2147483648, 89, 7341, -1, 7341, 1, 2047, -30000, 512]
INT_NEG_DATA = [-500, -98765, -3000, -2147483648, -77, -12]
FP_DATA = [3.25, -12.5, 0.75, 101.125, -0.0625, 64.0, 101.0, -1000.5, 7.875, 100.9375]
FP_NEG_DATA = [-0.25, -3.5, -1024.0, -0.3125, -7.0]

MAX_ADDR = 0x004              # where MAXFINDER writes its result


def array_words(values, to_word):
    """N at 0x000, the result slot at 0x004 (initially 0), the array at 0x008."""
    words = {0x000: len(values)}
    for i, v in enumerate(values):
        words[0x008 + 4 * i] = to_word(v)
    return words


def i32(v):
    return v & 0xFFFFFFFF


# (program, memory file, first line of the memory file, input words, expected MAX word)
RUNS = [
    ('testAll', 'testAll', '# testAll', TEST_ALL_WORDS, None),
    ('maxFinderInt', 'maxFinderInt', '# maxFinderInt',
     array_words(INT_DATA, i32), i32(max(INT_DATA))),
    ('maxFinderInt', 'maxFinderIntNeg', '# maxFinderInt, data set 2',
     array_words(INT_NEG_DATA, i32), i32(max(INT_NEG_DATA))),
    ('maxFinderFP', 'maxFinderFP', '# maxFinderFP',
     array_words(FP_DATA, float_bits), float_bits(max(FP_DATA))),
    ('maxFinderFP', 'maxFinderFPNeg', '# maxFinderFP, data set 2',
     array_words(FP_NEG_DATA, float_bits), float_bits(max(FP_NEG_DATA))),
]

# A store's comment "M[0x104] = 0xFFFFFFF2" gives its address and expected value.
EXPECT = re.compile(r'M\[0x([0-9A-Fa-f]+)\] = 0x([0-9A-Fa-f]{8})')


def check(cond, msg):
    if not cond:
        sys.exit(f'CHECK FAILED: {msg}')


def self_test():
    """The encoding examples printed in the ISA spec."""
    for text, want in [('ADD R3, R1, R2', 0x01230000),
                       ('BLT R2, R3, -4', 0x4232FFFC),
                       ('FLT R5, F3, F4', 0xA3454000)]:
        got = isaref.parse_program(text)[0].word
        check(got == want, f'{text} encodes to 0x{got:08X}, spec says 0x{want:08X}')
    for x in FP_DATA + FP_NEG_DATA + [6.5, -2.0]:
        check(f32(float_bits(x)) == x, f'{x} is not exact in single precision')


def write(path, text):
    with open(path, 'w', newline='\n') as f:      # Unix line endings for onyx
        f.write(text)


def main():
    self_test()
    OUT.mkdir(exist_ok=True)
    for prog_name in dict.fromkeys(r[0] for r in RUNS):
        src = (SRC / f'{prog_name}.s').read_text()
        write(OUT / f'{prog_name}.asm', isaref.resolve_labels(src))

    for prog_name, mem_name, header, words, want_max in RUNS:
        mem = {}
        for addr, value in words.items():
            isaref.store_word(mem, addr, value)
        write(OUT / f'{mem_name}.mem', isaref.mem_text(header, mem))

        # Run the files exactly as they will be submitted.
        prog = isaref.parse_program((OUT / f'{prog_name}.asm').read_text())
        header_in, mem_in = isaref.read_mem(OUT / f'{mem_name}.mem')
        nonzero = lambda m: {a: v for a, v in m.items() if v}
        check(nonzero(mem_in) == nonzero(mem), f'{mem_name}.mem does not read back')
        res = isaref.run(prog, mem_in)
        expected = isaref.mem_text(header_in, res.mem)
        write(OUT / f'{mem_name}.mem.expected', expected)

        # Every store marked "M[addr] = value" wrote that address and left that value.
        for ins in prog:
            m = EXPECT.search(ins.comment)
            if m and ins.name in ('SW', 'FSW'):
                check(ins.addr in res.last_store,
                      f'{prog_name} line {ins.line}: store never executed')
                addr = res.last_store[ins.addr]
                check(addr == int(m.group(1), 16),
                      f'{prog_name} line {ins.line}: stored at 0x{addr:X}, comment says 0x{m.group(1)}')
                got = load_word(res.mem, addr)
                check(got == int(m.group(2), 16),
                      f'{prog_name} line {ins.line}: got 0x{got:08X}, comment says 0x{m.group(2)}')
        if want_max is not None:
            got = load_word(res.mem, MAX_ADDR)
            check(got == want_max, f'{mem_name}: MAX is 0x{got:08X}, expected 0x{want_max:08X}')
        # Memory outside the result area is unchanged.
        changed = {a & ~3 for a in set(mem) | set(res.mem) if mem.get(a, 0) != res.mem.get(a, 0)}
        if prog_name == 'testAll':
            missing = [n for n in isaref.ISA if not res.counts[n]]
            check(not missing, f'testAll never executes {missing}')
            check(all(0x100 <= a < 0x200 for a in changed), 'testAll wrote outside 0x100-0x1FF')
            marked = sum(1 for i in prog if i.name in ('SW', 'FSW') and EXPECT.search(i.comment))
            check(len(changed) == marked, f'testAll changed {len(changed)} words, {marked} are marked')
        else:
            check(changed <= {MAX_ADDR}, f'{mem_name} wrote somewhere other than MAX')

        print(f'{mem_name:<16} {len(prog):>3} instructions in program, '
              f'{res.steps:>4} executed, {len(res.counts):>2} distinct', end='')
        if want_max is not None:
            print(f'   MAX = 0x{load_word(res.mem, MAX_ADDR):08X}', end='')
        print()
    print('All checks passed.')


if __name__ == '__main__':
    main()
