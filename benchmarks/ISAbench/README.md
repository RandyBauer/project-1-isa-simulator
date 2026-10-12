# ISAbench: Project 1 benchmarks

Cheikh Lame, Mira Allis, Randy Bauer, Ahmad Rao, Jeremiah Robinson

These programs are written for the ISA in our ISA specification (ISAspec, Oct 5).

## Files

| Benchmark | Program | Memory file | Expected final memory |
| --- | --- | --- | --- |
| Testing benchmark (every instruction) | testAll.asm | testAll.mem | testAll.mem.expected |
| MAXFINDER, integers | maxFinderInt.asm | maxFinderInt.mem | maxFinderInt.mem.expected |
| MAXFINDER, integers, second data set | maxFinderInt.asm | maxFinderIntNeg.mem | maxFinderIntNeg.mem.expected |
| MAXFINDER, floating point | maxFinderFP.asm | maxFinderFP.mem | maxFinderFP.mem.expected |
| MAXFINDER, floating point, second data set | maxFinderFP.asm | maxFinderFPNeg.mem | maxFinderFPNeg.mem.expected |

Each .mem.expected file is the full memory a correct run leaves behind, in the
same format as the input memory file. To check a run:

    isaSim -r maxFinderInt.asm maxFinderInt.mem
    diff maxFinderInt.mem.out maxFinderInt.mem.expected

Our simulator writes .mem.out by the rules under "Memory file format" below,
so no output from diff means the run is correct. The expected files were made by
running each program on a model of the ISA. Every testAll result was also
worked out by hand, and both sets of answers agree.

## Memory file format

- Line 1: a comment naming the benchmark.
- Line 2: `28,8`. Data memory has 28 address bits and is byte addressable, so
  each address holds 8 bits.
- Every later line: `address,contents`, both in hex (7 digits for the address,
  2 for the contents).
- A 32-bit word fills 4 consecutive addresses, most significant byte first
  (big-endian, as the spec says). For example, the word 0x00001CAD at
  address 0x004 is:

      0000004,00
      0000005,00
      0000006,1C
      0000007,AD

- Any address not listed holds 0. The files list every word that has a
  non-zero byte, all four of its bytes, in address order. The expected files
  follow the same rule and repeat line 1 of the input memory file.

## Assembly file format

- One instruction per line. `#` starts a comment. Blank lines are ignored.
- Mnemonics and operand order are the ones in the spec, for example
  `ADD rd, rs, rt`, `ADDI rt, rs, imm`, `LW rt, offset(rs)`,
  `BEQ rs, rt, offset`, `J address`, `JR rs`, `FLT rd, fs, ft`, `FMOV fd, fs`,
  `HALT`.
- Registers are R0-R15 and F0-F15. Numbers are decimal (`-4`) or hex (`0x100`).
- The first instruction is at instruction address 0.
- Labels have been replaced by numbers, as the handout requires:
  - A branch operand is an offset counted from the next instruction, matching
    the spec's RTL `PC <- PC + 1 + SignExt(offset)`.
  - A J or JAL operand is an absolute instruction address.
  - Each comment starts with the instruction's address (`N:`), and
    `[LABEL = address N]` names the target of a branch or jump.

## testAll: the testing benchmark

testAll uses all 36 instructions; 127 instructions execute. Each test stores
one 32-bit word in the result area, which starts at 0x100. Every expected value
is non-zero, so a store that never happens shows up as a missing word.

The operands are chosen so that common simulator mistakes change the answer:
signed vs. unsigned compares, sign- vs. zero-extended immediates, a shift
amount of 36 (only its low 5 bits, 4, may be used), comparing floats by their
raw bits, and dividing by zero.

| Address | Tests | Expected |
| --- | --- | --- |
| 0x100 | LW with offset -4, then SW | 0xCAFEF00D |
| 0x104 | ADD: -20 + 6 | 0xFFFFFFF2 |
| 0x108 | SUB: 6 - (-20) | 0x0000001A |
| 0x10C | AND: 0xF0F0F0F0, 0x3C3C3C3C | 0x30303030 |
| 0x110 | OR | 0xFCFCFCFC |
| 0x114 | XOR | 0xCCCCCCCC |
| 0x118 | SLT: -20 < 6 (signed) | 0x00000001 |
| 0x11C | SLTU: 6 < 0xFFFFFFEC (unsigned) | 0x00000001 |
| 0x120 | SLL: 0xF0F0F0F0 by 36 (uses 4) | 0x0F0F0F00 |
| 0x124 | SRL | 0x0F0F0F0F |
| 0x128 | SRA | 0xFF0F0F0F |
| 0x12C | ADDI: -20 + (-1000), sign-extended | 0xFFFFFC04 |
| 0x130 | ANDI: 0xFFFFFFEC AND 0xFF00, zero-extended | 0x0000FF00 |
| 0x134 | ORI: 0 OR 0x8001, zero-extended | 0x00008001 |
| 0x138 | XORI: 0xFFFFFFEC XOR 0xFFFF | 0xFFFF0013 |
| 0x13C | LUI 0xBEEF | 0xBEEF0000 |
| 0x140 | LUI + ORI build 0x7FFFFFFF; ADDI 1 wraps | 0x80000000 |
| 0x144 | Writing R0 is ignored | 0x00000001 |
| 0x148 - 0x174 | BEQ, BNE, BLT, BGE, BLTU, BGEU, each taken (1) then not taken (2) | 1, 2, 1, 2, ... |
| 0x178 | Backward branch (negative offset): 3 + 2 + 1 | 0x00000006 |
| 0x17C | J skips one instruction | 0x00000001 |
| 0x180 | JAL return address saved in R15 | 0x00000068 |
| 0x184 | JAL reached the subroutine, which returns with JR R15 | 0x0000005B |
| 0x188 | FADD: 6.5 + -2.0 = 4.5 | 0x40900000 |
| 0x18C | FSUB: 6.5 - -2.0 = 8.5 | 0x41080000 |
| 0x190 | FMUL: 6.5 * -2.0 = -13.0 | 0xC1500000 |
| 0x194 | FDIV: 6.5 / -2.0 = -3.25 | 0xC0500000 |
| 0x198 | FLT: -3.25 < -2.0 | 0x00000001 |
| 0x19C | FMOV, then FSW | 0x40D00000 |
| 0x1A0 | FEQ: 6.5 = 6.5 | 0x00000001 |
| 0x1A4 | FDIV 6.5 / 0.0 = +infinity, program keeps running | 0x7F800000 |

## MAXFINDER (integer and floating point)

Both programs read N and the array from memory, so they work for any array a
memory file supplies. Memory layout:

| Address | Contents |
| --- | --- |
| 0x000 | N, the number of elements (an integer) |
| 0x004 | MAX, the result, written by the program |
| 0x008 | A[0], A[1], ..., A[N-1], one 32-bit word each |

If N <= 0 there is no maximum, so the program stores nothing and halts. The
integer version compares with BGE (signed). The floating-point version
compares with FLT and copies the new largest value with FMOV.

| Memory file | Array | Expected MAX | Instructions executed |
| --- | --- | --- | --- |
| maxFinderInt.mem | 17, -45, 302, -2147483648, 89, 7341, -1, 7341, 1, 2047, -30000, 512 | 7341 (0x00001CAD) | 59 |
| maxFinderIntNeg.mem | -500, -98765, -3000, -2147483648, -77, -12 | -12 (0xFFFFFFF4) | 35 |
| maxFinderFP.mem | 3.25, -12.5, 0.75, 101.125, -0.0625, 64.0, 101.0, -1000.5, 7.875, 100.9375 | 101.125 (0x42CA4000) | 58 |
| maxFinderFPNeg.mem | -0.25, -3.5, -1024.0, -0.3125, -7.0 | -0.25 (0xBE800000) | 31 |

What each data set catches:

- maxFinderInt: the largest value appears twice and is neither first nor
  last. An unsigned compare would pick -1 (0xFFFFFFFF).
- maxFinderIntNeg: every value is negative and the largest is the last
  element, so the loop must reach the end and must start from A[0], not 0.
- maxFinderFP: several values sit close to the largest (101.0, 100.9375).
- maxFinderFPNeg: every value is negative and the largest is the first
  element. Comparing the raw bit patterns as integers would pick -1024.0.
