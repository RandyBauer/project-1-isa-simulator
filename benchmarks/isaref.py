#!/usr/bin/env python3
"""Reference model of the team's Project 1 ISA (the spec submitted Oct 5).

Used to build and check the ISAbench benchmarks. It is a checking tool, not
the Oct 19 simulator: it runs a program straight through, with no step mode.
Every instruction is first encoded to its 32-bit word and then executed by
decoding that word, so a clean run also proves every instruction is encodable.

    python isaref.py <program.asm> <memory.mem> [<output.mem>]
    python isaref.py --resolve <labeled.s> <program.asm>
"""

import math
import re
import struct
import sys
from collections import Counter, namedtuple

ADDR_BITS = 28              # data memory is 2^28 bytes
CELL_BITS = 8               # byte addressable: 8 bits stored at each address
MEM_SIZE = 1 << ADDR_BITS
MASK32 = 0xFFFFFFFF

# mnemonic -> (opcode, sub-opcode, operand pattern)
#   rrr: rd, rs, rt       fff: fd, fs, ft      rff: rd, fs, ft     ff: fd, fs
#   rri: rt, rs, simm16   rru: rt, rs, uimm16  ru:  rt, uimm16
#   rm:  rt, off(rs)      fm:  ft, off(rs)     rrb: rs, rt, offset
#   a:   address          r:   rs              -:   no operands
ISA = {
    'ADD':  (0x0, 0x0, 'rrr'), 'SUB':  (0x0, 0x1, 'rrr'), 'AND':  (0x0, 0x2, 'rrr'),
    'OR':   (0x0, 0x3, 'rrr'), 'XOR':  (0x0, 0x4, 'rrr'), 'SLT':  (0x0, 0x5, 'rrr'),
    'SLTU': (0x0, 0x6, 'rrr'), 'SLL':  (0x0, 0x7, 'rrr'), 'SRL':  (0x0, 0x8, 'rrr'),
    'SRA':  (0x0, 0x9, 'rrr'),
    'ADDI': (0x1, 0x0, 'rri'), 'ANDI': (0x1, 0x1, 'rru'), 'ORI':  (0x1, 0x2, 'rru'),
    'XORI': (0x1, 0x3, 'rru'),
    'LW':   (0x2, 0x0, 'rm'),  'SW':   (0x3, 0x0, 'rm'),
    'BEQ':  (0x4, 0x0, 'rrb'), 'BNE':  (0x4, 0x1, 'rrb'), 'BLT':  (0x4, 0x2, 'rrb'),
    'BGE':  (0x4, 0x3, 'rrb'), 'BLTU': (0x4, 0x4, 'rrb'), 'BGEU': (0x4, 0x5, 'rrb'),
    'J':    (0x5, None, 'a'),  'JAL':  (0x6, None, 'a'),  'JR':   (0x7, 0x0, 'r'),
    'FLW':  (0x8, 0x0, 'fm'),  'FSW':  (0x9, 0x0, 'fm'),
    'FADD': (0xA, 0x0, 'fff'), 'FSUB': (0xA, 0x1, 'fff'), 'FMUL': (0xA, 0x2, 'fff'),
    'FDIV': (0xA, 0x3, 'fff'), 'FLT':  (0xA, 0x4, 'rff'), 'FEQ':  (0xA, 0x5, 'rff'),
    'FMOV': (0xA, 0x6, 'ff'),
    'LUI':  (0xC, 0x0, 'ru'),
    'HALT': (0xF, None, '-'),
}
OPERAND_COUNT = {'rrr': 3, 'fff': 3, 'rff': 3, 'ff': 2, 'rri': 3, 'rru': 3, 'ru': 2,
                 'rm': 2, 'fm': 2, 'rrb': 3, 'a': 1, 'r': 1, '-': 0}
BY_CODE = {(op, sub): name for name, (op, sub, _) in ISA.items()}
R_FORMAT_OPCODES = {0x0, 0x7, 0xA}      # sub-opcode in bits 15-12
NO_SUB_OPCODES = {0x5, 0x6, 0xF}        # J, JAL, HALT

Instr = namedtuple('Instr', 'addr name word text comment line')


class AsmError(Exception):
    pass


class SimError(Exception):
    pass


# ---------------------------------------------------------------- encoding

def number(tok):
    try:
        return int(tok, 0)
    except ValueError:
        raise AsmError(f'expected a number, got {tok!r}') from None


def reg(tok, kind):
    m = re.fullmatch(r'([RrFf])(\d{1,2})', tok.strip())
    if not m or m.group(1).upper() != kind or int(m.group(2)) > 15:
        raise AsmError(f'expected register {kind}0-{kind}15, got {tok!r}')
    return int(m.group(2))


def simm16(tok):
    v = number(tok)
    if not -0x8000 <= v <= 0x7FFF:
        raise AsmError(f'{v} does not fit a signed 16-bit field')
    return v & 0xFFFF


def uimm16(tok):
    v = number(tok)
    if not 0 <= v <= 0xFFFF:
        raise AsmError(f'{v} does not fit an unsigned 16-bit field')
    return v


def mem_operand(tok):
    """Split 'offset(Rn)' into its offset and base-register tokens."""
    m = re.fullmatch(r'\s*([^()]*)\(\s*(\w+)\s*\)\s*', tok)
    if not m:
        raise AsmError(f'expected offset(Rn), got {tok!r}')
    return (m.group(1).strip() or '0'), m.group(2)


def r_word(op, rs, rt, rd, sub):
    return op << 28 | rs << 24 | rt << 20 | rd << 16 | sub << 12


def i_word(op, rs, rt, sub, imm16):
    return op << 28 | rs << 24 | rt << 20 | sub << 16 | imm16


def encode(name, ops):
    if name not in ISA:
        raise AsmError(f'unknown instruction {name}')
    op, sub, pat = ISA[name]
    if len(ops) != OPERAND_COUNT[pat]:
        raise AsmError(f'{name} takes {OPERAND_COUNT[pat]} operands, got {len(ops)}')
    if pat == 'rrr':
        return r_word(op, reg(ops[1], 'R'), reg(ops[2], 'R'), reg(ops[0], 'R'), sub)
    if pat == 'fff':
        return r_word(op, reg(ops[1], 'F'), reg(ops[2], 'F'), reg(ops[0], 'F'), sub)
    if pat == 'rff':
        return r_word(op, reg(ops[1], 'F'), reg(ops[2], 'F'), reg(ops[0], 'R'), sub)
    if pat == 'ff':
        return r_word(op, reg(ops[1], 'F'), 0, reg(ops[0], 'F'), sub)
    if pat == 'rri':
        return i_word(op, reg(ops[1], 'R'), reg(ops[0], 'R'), sub, simm16(ops[2]))
    if pat == 'rru':
        return i_word(op, reg(ops[1], 'R'), reg(ops[0], 'R'), sub, uimm16(ops[2]))
    if pat == 'ru':
        return i_word(op, 0, reg(ops[0], 'R'), sub, uimm16(ops[1]))
    if pat in ('rm', 'fm'):
        off, base = mem_operand(ops[1])
        dest = reg(ops[0], 'R' if pat == 'rm' else 'F')
        return i_word(op, reg(base, 'R'), dest, sub, simm16(off))
    if pat == 'rrb':
        return i_word(op, reg(ops[0], 'R'), reg(ops[1], 'R'), sub, simm16(ops[2]))
    if pat == 'a':
        addr = number(ops[0])
        if not 0 <= addr < (1 << 28):
            raise AsmError(f'jump address {addr} does not fit 28 bits')
        return op << 28 | addr
    if pat == 'r':
        return r_word(op, reg(ops[0], 'R'), 0, 0, sub)
    return op << 28                                   # HALT


def decode_name(word):
    op = word >> 28
    if op in NO_SUB_OPCODES:
        sub = None
    elif op in R_FORMAT_OPCODES:
        sub = (word >> 12) & 0xF
    else:
        sub = (word >> 16) & 0xF
    return BY_CODE.get((op, sub))


def split_instruction(code):
    m = re.match(r'(\S+)\s*(.*)$', code)
    name, rest = m.group(1).upper(), m.group(2).strip()
    return name, ([o.strip() for o in rest.split(',')] if rest else [])


def parse_program(text):
    """Parse an assembly file (no labels) into encoded instructions."""
    prog = []
    for line_no, raw in enumerate(text.splitlines(), 1):
        code, _, comment = raw.partition('#')
        code = code.strip()
        if not code:
            continue
        name, ops = split_instruction(code)
        try:
            word = encode(name, ops)
        except AsmError as e:
            raise AsmError(f'line {line_no}: {e}') from None
        prog.append(Instr(len(prog), name, word, code, comment.strip(), line_no))
    return prog


# ---------------------------------------------------------------- labels

LABEL_DEF = re.compile(r'\s*([A-Za-z_]\w*):(.*)$')
IDENT = re.compile(r'[A-Za-z_]\w*$')
REGISTER = re.compile(r'[RrFf]\d{1,2}$')


def resolve_labels(src_text):
    """Turn a labeled source into an assembly file with concrete numbers.

    A branch operand becomes an offset from the instruction after the branch;
    any other label operand becomes the label's absolute instruction address.
    Label definitions are kept as comments, and every instruction's comment
    starts with its address.
    """
    rows, labels, addr = [], {}, 0
    for raw in src_text.splitlines():
        code, _, comment = raw.partition('#')
        m = LABEL_DEF.match(code)
        if m:
            if m.group(1) in labels:
                raise AsmError(f'label {m.group(1)} defined twice')
            labels[m.group(1)] = addr
            rows.append(('label', m.group(1), comment.strip()))
            code = m.group(2)
        code = code.strip()
        if code:
            name, ops = split_instruction(code)
            rows.append(('instr', addr, name, ops, comment.strip()))
            addr += 1
        elif not m:
            rows.append(('text', raw.rstrip()))

    out = []
    for row in rows:
        if row[0] == 'text':
            out.append(row[1])
        elif row[0] == 'label':
            _, name, comment = row
            out.append(f'# {name} = address {labels[name]}  {comment}'.rstrip())
        else:
            _, a, name, ops, comment = row
            notes = []
            for i, tok in enumerate(ops):
                if IDENT.match(tok) and not REGISTER.match(tok):
                    if tok not in labels:
                        raise AsmError(f'unknown label {tok}')
                    target = labels[tok]
                    is_offset = ISA.get(name, (0, 0, ''))[2] == 'rrb' and i == 2
                    ops[i] = str(target - (a + 1)) if is_offset else str(target)
                    notes.append(f'{tok} = address {target}')
            text = f'{name:<6}{", ".join(ops)}'
            note = f'[{"; ".join(notes)}]' if notes else ''
            tail = '  '.join(s for s in (comment, note) if s)
            out.append(f'    {text:<26}# {a:>3}: {tail}'.rstrip())
    end = out.index('') if '' in out else 0  # end of the header comment block
    out[end:end] = RESOLVED_NOTE
    return '\n'.join(out) + '\n'


RESOLVED_NOTE = [
    '#',
    '# "N:" is the instruction address. Branch operands are offsets from the',
    '# next instruction. J and JAL operands are instruction addresses.',
]


# ---------------------------------------------------------------- floats

def f32(bits):
    return struct.unpack('>f', bits.to_bytes(4, 'big'))[0]


def float_bits(x):
    """Round a Python float to IEEE-754 single precision and return its bits."""
    try:
        return int.from_bytes(struct.pack('>f', x), 'big')
    except OverflowError:
        return 0x7F800000 if x > 0 else 0xFF800000


def fdiv(a, b):
    if b == 0.0:                       # IEEE-754: x/0 is +-inf, 0/0 is NaN
        if a == 0.0 or math.isnan(a):
            return math.nan
        return math.copysign(math.inf, a) * math.copysign(1.0, b)
    return a / b


# ---------------------------------------------------------------- memory

def load_word(mem, a):
    return int.from_bytes(bytes(mem.get(a + i, 0) for i in range(4)), 'big')


def store_word(mem, a, value):
    for i, byte in enumerate(value.to_bytes(4, 'big')):
        mem[a + i] = byte


def read_mem(path):
    with open(path) as f:
        lines = f.read().splitlines()
    header = lines[0]
    addr_bits, cell_bits = (int(x) for x in lines[1].split(','))
    if (addr_bits, cell_bits) != (ADDR_BITS, CELL_BITS):
        raise SimError(f'{path}: expected "{ADDR_BITS},{CELL_BITS}" on line 2')
    mem = {}
    for line in lines[2:]:
        if line.strip():
            addr, value = line.split(',')
            mem[int(addr, 16)] = int(value, 16)
    return header, mem


def mem_text(header, mem):
    """Every word holding a non-zero byte, as four byte lines in address order."""
    words = sorted({a & ~3 for a, v in mem.items() if v})
    lines = [header, f'{ADDR_BITS},{CELL_BITS}']
    for w in words:
        lines += [f'{a:07X},{mem.get(a, 0):02X}' for a in range(w, w + 4)]
    return '\n'.join(lines) + '\n'


# ---------------------------------------------------------------- execution

Result = namedtuple('Result', 'mem counts steps last_store R F')


def signed(x):
    return x - (1 << 32) if x & 0x80000000 else x


def run(prog, mem, max_steps=1_000_000, on_step=None):
    """Execute until HALT. If given, on_step(instr, next_pc, R, F, mem) is
    called after every instruction (next_pc is None for HALT)."""
    R, F = [0] * 16, [0] * 16          # F holds raw 32-bit IEEE-754 patterns
    mem = dict(mem)
    counts, last_store = Counter(), {}
    pc = steps = 0

    def data_addr(base, offset):
        a = (R[base] + offset) & MASK32
        if a % 4:
            raise SimError(f'PC {pc}: address 0x{a:X} is not a multiple of 4')
        if a > MEM_SIZE - 4:
            raise SimError(f'PC {pc}: address 0x{a:X} is outside data memory')
        return a

    while True:
        if not 0 <= pc < len(prog):
            raise SimError(f'PC {pc} is outside the program')
        if steps >= max_steps:
            raise SimError(f'no HALT after {max_steps} instructions')
        w = prog[pc].word
        name = decode_name(w)
        if name is None:
            raise SimError(f'PC {pc}: 0x{w:08X} is not a valid instruction')
        rs, rt, rd = (w >> 24) & 0xF, (w >> 20) & 0xF, (w >> 16) & 0xF
        imm = w & 0xFFFF
        simm = imm - 0x10000 if imm & 0x8000 else imm
        a, b = R[rs], R[rt]
        counts[name] += 1
        steps += 1
        npc = pc + 1

        if name == 'ADD':    R[rd] = (a + b) & MASK32
        elif name == 'SUB':  R[rd] = (a - b) & MASK32
        elif name == 'AND':  R[rd] = a & b
        elif name == 'OR':   R[rd] = a | b
        elif name == 'XOR':  R[rd] = a ^ b
        elif name == 'SLT':  R[rd] = int(signed(a) < signed(b))
        elif name == 'SLTU': R[rd] = int(a < b)
        elif name == 'SLL':  R[rd] = (a << (b & 31)) & MASK32
        elif name == 'SRL':  R[rd] = a >> (b & 31)
        elif name == 'SRA':  R[rd] = (signed(a) >> (b & 31)) & MASK32
        elif name == 'ADDI': R[rt] = (a + simm) & MASK32
        elif name == 'ANDI': R[rt] = a & imm
        elif name == 'ORI':  R[rt] = a | imm
        elif name == 'XORI': R[rt] = a ^ imm
        elif name == 'LUI':  R[rt] = imm << 16
        elif name == 'LW':   R[rt] = load_word(mem, data_addr(rs, simm))
        elif name == 'FLW':  F[rt] = load_word(mem, data_addr(rs, simm))
        elif name in ('SW', 'FSW'):
            addr = data_addr(rs, simm)
            store_word(mem, addr, R[rt] if name == 'SW' else F[rt])
            last_store[pc] = addr
        elif name in ('BEQ', 'BNE', 'BLT', 'BGE', 'BLTU', 'BGEU'):
            taken = {'BEQ': a == b, 'BNE': a != b,
                     'BLT': signed(a) < signed(b), 'BGE': signed(a) >= signed(b),
                     'BLTU': a < b, 'BGEU': a >= b}[name]
            if taken:
                npc = pc + 1 + simm
        elif name == 'J':    npc = w & 0x0FFFFFFF
        elif name == 'JAL':  R[15], npc = pc + 1, w & 0x0FFFFFFF
        elif name == 'JR':   npc = a
        elif name in ('FADD', 'FSUB', 'FMUL', 'FDIV'):
            x, y = f32(F[rs]), f32(F[rt])
            z = {'FADD': lambda: x + y, 'FSUB': lambda: x - y,
                 'FMUL': lambda: x * y, 'FDIV': lambda: fdiv(x, y)}[name]()
            F[rd] = float_bits(z)
        elif name == 'FLT':  R[rd] = int(f32(F[rs]) < f32(F[rt]))
        elif name == 'FEQ':  R[rd] = int(f32(F[rs]) == f32(F[rt]))
        elif name == 'FMOV': F[rd] = F[rs]
        elif name == 'HALT':
            if on_step:
                on_step(prog[pc], None, R, F, mem)
            break
        R[0] = 0                           # writes to R0 are ignored
        if on_step:
            on_step(prog[pc], npc, R, F, mem)
        pc = npc
    return Result(mem, counts, steps, last_store, R, F)


# ---------------------------------------------------------------- command line

def main(argv):
    if len(argv) == 4 and argv[1] == '--resolve':
        with open(argv[2]) as f:
            text = resolve_labels(f.read())
        with open(argv[3], 'w', newline='\n') as f:
            f.write(text)
        return 0
    if len(argv) not in (3, 4):
        print(__doc__)
        return 2
    with open(argv[1]) as f:
        prog = parse_program(f.read())
    header, mem = read_mem(argv[2])
    res = run(prog, mem)
    out = argv[3] if len(argv) == 4 else argv[2] + '.out'
    with open(out, 'w', newline='\n') as f:
        f.write(mem_text(header, res.mem))
    for name in ISA:
        if res.counts[name]:
            print(f'{name:<6}{res.counts[name]}')
    print(f'total {res.steps}  ->  {out}')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
