# ISAbench: Project 1 benchmarks

Cheikh Lame, Mira Allis, Randy Bauer, Ahmad Rao, Jeremiah Robinson

## Files

| Benchmark | Program | Memory file | Expected final memory |
| --- | --- | --- | --- |
| Testing benchmark | testAll.asm | testAll.mem | testAll.mem.expected |
| MAXFINDER, integer | maxFinderInt.asm | maxFinderInt.mem | maxFinderInt.mem.expected |
| MAXFINDER, integer, data set 2 | maxFinderInt.asm | maxFinderIntNeg.mem | maxFinderIntNeg.mem.expected |
| MAXFINDER, floating point | maxFinderFP.asm | maxFinderFP.mem | maxFinderFP.mem.expected |
| MAXFINDER, floating point, data set 2 | maxFinderFP.asm | maxFinderFPNeg.mem | maxFinderFPNeg.mem.expected |

A correct run produces a .mem.out identical to the .mem.expected file:

    isaSim -r maxFinderInt.asm maxFinderInt.mem
    diff maxFinderInt.mem.out maxFinderInt.mem.expected

## Memory file format

- Line 1: comment with the benchmark name.
- Line 2: `28,8` (28 address bits, 8 bits per address).
- Other lines: `address,contents` in hex. Address is 7 digits, contents 2 digits.
- A 32-bit word occupies 4 addresses, most significant byte first. The word
  0x00001CAD at address 0x004:

      0000004,00
      0000005,00
      0000006,1C
      0000007,AD

- Unlisted addresses hold 0. Every word with a non-zero byte is listed in full,
  in address order.

## Assembly file format

- One instruction per line. `#` starts a comment.
- Mnemonics and operand order follow the ISA specification.
- Registers: R0-R15, F0-F15. Numbers: decimal or `0x` hex.
- The first instruction is at address 0.
- Branch operands are offsets from the next instruction
  (`PC <- PC + 1 + SignExt(offset)`).
- J and JAL operands are instruction addresses.
- `N:` in a comment is the instruction address. `[LABEL = address N]` is the
  branch or jump target.

## testAll

Uses all 36 instructions. Executes 127 instructions. Results are stored at
0x100-0x1A4.

| Address | Test | Expected |
| --- | --- | --- |
| 0x100 | LW (offset -4), SW | 0xCAFEF00D |
| 0x104 | ADD: -20 + 6 | 0xFFFFFFF2 |
| 0x108 | SUB: 6 - (-20) | 0x0000001A |
| 0x10C | AND: 0xF0F0F0F0, 0x3C3C3C3C | 0x30303030 |
| 0x110 | OR | 0xFCFCFCFC |
| 0x114 | XOR | 0xCCCCCCCC |
| 0x118 | SLT: -20 < 6 | 0x00000001 |
| 0x11C | SLTU: 6 < 0xFFFFFFEC | 0x00000001 |
| 0x120 | SLL: 0xF0F0F0F0 by 36 (low 5 bits = 4) | 0x0F0F0F00 |
| 0x124 | SRL | 0x0F0F0F0F |
| 0x128 | SRA | 0xFF0F0F0F |
| 0x12C | ADDI: -20 + (-1000) | 0xFFFFFC04 |
| 0x130 | ANDI: 0xFFFFFFEC AND 0xFF00 | 0x0000FF00 |
| 0x134 | ORI: 0 OR 0x8001 | 0x00008001 |
| 0x138 | XORI: 0xFFFFFFEC XOR 0xFFFF | 0xFFFF0013 |
| 0x13C | LUI 0xBEEF | 0xBEEF0000 |
| 0x148-0x174 | BEQ, BNE, BLT, BGE, BLTU, BGEU: taken (1), not taken (2) | 1, 2, 1, 2, ... |
| 0x140 | ADDI overflow: 0x7FFFFFFF + 1 | 0x80000000 |
| 0x144 | Write to R0 | 0x00000001 |
| 0x178 | Backward branch: 3 + 2 + 1 | 0x00000006 |
| 0x17C | J | 0x00000001 |
| 0x180 | JAL return address (R15) | 0x00000068 |
| 0x184 | JAL target, JR R15 return | 0x0000005B |
| 0x188 | FADD: 6.5 + -2.0 | 0x40900000 |
| 0x18C | FSUB: 6.5 - -2.0 | 0x41080000 |
| 0x190 | FMUL: 6.5 * -2.0 | 0xC1500000 |
| 0x194 | FDIV: 6.5 / -2.0 | 0xC0500000 |
| 0x198 | FLT: -3.25 < -2.0 | 0x00000001 |
| 0x19C | FMOV, FSW | 0x40D00000 |
| 0x1A0 | FEQ: 6.5 = 6.5 | 0x00000001 |
| 0x1A4 | FDIV: 6.5 / 0.0 | 0x7F800000 |

## MAXFINDER

| Address | Contents |
| --- | --- |
| 0x000 | N |
| 0x004 | MAX (written by the program) |
| 0x008 | A[0] ... A[N-1] |

If N <= 0, nothing is stored. The integer version compares with BGE. The
floating-point version compares with FLT and copies with FMOV.

| Memory file | Array | Expected MAX | Instructions executed |
| --- | --- | --- | --- |
| maxFinderInt.mem | 17, -45, 302, -2147483648, 89, 7341, -1, 7341, 1, 2047, -30000, 512 | 7341 (0x00001CAD) | 59 |
| maxFinderIntNeg.mem | -500, -98765, -3000, -2147483648, -77, -12 | -12 (0xFFFFFFF4) | 35 |
| maxFinderFP.mem | 3.25, -12.5, 0.75, 101.125, -0.0625, 64.0, 101.0, -1000.5, 7.875, 100.9375 | 101.125 (0x42CA4000) | 58 |
| maxFinderFPNeg.mem | -0.25, -3.5, -1024.0, -0.3125, -7.0 | -0.25 (0xBE800000) | 31 |
