# testAll -- uses every instruction in the ISA (all 36) at least once.
#
# Labels have been replaced by numbers. Each comment starts with the
# instruction's address ("N:"), and [LABEL = address N] names the target
# of a branch or jump. A branch operand is an offset counted from the next
# instruction; a J or JAL operand is an absolute instruction address.
#
# Each test leaves one 32-bit word in the result area, which starts at byte
# address 0x100. The store that writes each word shows its expected value
# after "=>". testAll.mem.expected holds the whole expected final memory.
#
# Input data (testAll.mem), 32-bit big-endian words:
#   0x000  0xFFFFFFEC  (-20)          0x010  0x40D00000  (6.5)
#   0x004  0x00000006  (6)            0x014  0xC0000000  (-2.0)
#   0x008  0xF0F0F0F0                 0x0FC  0xCAFEF00D
#   0x00C  0x3C3C3C3C
#
# Every expected result is non-zero, so a store that never happens shows up
# as a missing word. Branch tests store 1 if the branch was taken and 2 if it
# fell through. Operands are picked so that a common simulator bug (signed
# vs. unsigned, sign- vs. zero-extension, shift masking) changes the result.
#
# Registers: R1-R4 hold the operands above, R6 and R9 hold results,
# R13 = 0x100 (result area), R15 = return address saved by JAL.

# ---- load the operands ----
    LW    R1, 0(R0)           #   0: R1 = -20
    LW    R2, 4(R0)           #   1: R2 = 6
    LW    R3, 8(R0)           #   2: R3 = 0xF0F0F0F0
    LW    R4, 12(R0)          #   3: R4 = 0x3C3C3C3C
    ADDI  R13, R0, 0x100      #   4: R13 = base of the result area

# ---- LW with a negative offset, SW ----
    LW    R5, -4(R13)         #   5: R5 = M[0x0FC]; the offset -4 is sign-extended
    SW    R5, 0x00(R13)       #   6: [0x100] LW, SW, negative offset   => 0xCAFEF00D

# ---- ALU-R ----
    ADD   R6, R1, R2          #   7: -20 + 6 = -14
    SW    R6, 0x04(R13)       #   8: [0x104] ADD                        => 0xFFFFFFF2
    SUB   R6, R2, R1          #   9: 6 - (-20) = 26
    SW    R6, 0x08(R13)       #  10: [0x108] SUB                        => 0x0000001A
    AND   R6, R3, R4          #  11: 0xF0F0F0F0 AND 0x3C3C3C3C
    SW    R6, 0x0C(R13)       #  12: [0x10C] AND                        => 0x30303030
    OR    R6, R3, R4          #  13: 0xF0F0F0F0 OR 0x3C3C3C3C
    SW    R6, 0x10(R13)       #  14: [0x110] OR                         => 0xFCFCFCFC
    XOR   R6, R3, R4          #  15: 0xF0F0F0F0 XOR 0x3C3C3C3C
    SW    R6, 0x14(R13)       #  16: [0x114] XOR                        => 0xCCCCCCCC
    SLT   R6, R1, R2          #  17: -20 < 6 signed: 1 (unsigned would give 0)
    SW    R6, 0x18(R13)       #  18: [0x118] SLT                        => 0x00000001
    SLTU  R6, R2, R1          #  19: 6 < 0xFFFFFFEC unsigned: 1 (signed would give 0)
    SW    R6, 0x1C(R13)       #  20: [0x11C] SLTU                       => 0x00000001
    ADDI  R7, R0, 36          #  21: shift amount 36: only its low 5 bits (4) are used
    SLL   R6, R3, R7          #  22: 0xF0F0F0F0 << 4
    SW    R6, 0x20(R13)       #  23: [0x120] SLL                        => 0x0F0F0F00
    SRL   R6, R3, R7          #  24: 0xF0F0F0F0 >> 4, zeros shifted in
    SW    R6, 0x24(R13)       #  25: [0x124] SRL                        => 0x0F0F0F0F
    SRA   R6, R3, R7          #  26: 0xF0F0F0F0 >> 4, sign bit shifted in
    SW    R6, 0x28(R13)       #  27: [0x128] SRA                        => 0xFF0F0F0F

# ---- ALU-I and LUI ----
    ADDI  R6, R1, -1000       #  28: -20 + (-1000) = -1020; immediate is sign-extended
    SW    R6, 0x2C(R13)       #  29: [0x12C] ADDI                       => 0xFFFFFC04
    ANDI  R6, R1, 0xFF00      #  30: 0xFFFFFFEC AND 0x0000FF00; zero-extended
    SW    R6, 0x30(R13)       #  31: [0x130] ANDI                       => 0x0000FF00
    ORI   R6, R0, 0x8001      #  32: 0 OR 0x00008001 (not 0xFFFF8001)
    SW    R6, 0x34(R13)       #  33: [0x134] ORI                        => 0x00008001
    XORI  R6, R1, 0xFFFF      #  34: 0xFFFFFFEC XOR 0x0000FFFF
    SW    R6, 0x38(R13)       #  35: [0x138] XORI                       => 0xFFFF0013
    LUI   R6, 0xBEEF          #  36: upper half 0xBEEF, lower half 0
    SW    R6, 0x3C(R13)       #  37: [0x13C] LUI                        => 0xBEEF0000

# ---- overflow wraps; R0 cannot be written ----
    LUI   R8, 0x7FFF          #  38: R8 = 0x7FFF0000
    ORI   R8, R8, 0xFFFF      #  39: R8 = 0x7FFFFFFF, the largest positive integer
    ADDI  R6, R8, 1           #  40: wraps to the most negative integer; no trap
    SW    R6, 0x40(R13)       #  41: [0x140] ADDI overflow wraps        => 0x80000000
    ADDI  R0, R0, 77          #  42: write to R0: ignored
    ADDI  R6, R0, 1           #  43: 1 only if R0 is still 0
    SW    R6, 0x44(R13)       #  44: [0x144] R0 stays 0                 => 0x00000001

# ---- branches: each taken once and not taken once ----
# Pattern: R9 = 1; branch over "R9 = 2"; store R9.
    ADDI  R9, R0, 1           #  45: 1 = taken
    BEQ   R2, R2, 1           #  46: 6 = 6: taken
    ADDI  R9, R0, 2           #  47: 2 = fell through
    SW    R9, 0x48(R13)       #  48: [0x148] BEQ taken                  => 0x00000001
    ADDI  R9, R0, 1           #  49:
    BEQ   R1, R2, 1           #  50: -20 = 6 is false: falls through
    ADDI  R9, R0, 2           #  51:
    SW    R9, 0x4C(R13)       #  52: [0x14C] BEQ not taken              => 0x00000002
    ADDI  R9, R0, 1           #  53:
    BNE   R1, R2, 1           #  54: -20 /= 6: taken
    ADDI  R9, R0, 2           #  55:
    SW    R9, 0x50(R13)       #  56: [0x150] BNE taken                  => 0x00000001
    ADDI  R9, R0, 1           #  57:
    BNE   R2, R2, 1           #  58: 6 /= 6 is false: falls through
    ADDI  R9, R0, 2           #  59:
    SW    R9, 0x54(R13)       #  60: [0x154] BNE not taken              => 0x00000002
    ADDI  R9, R0, 1           #  61:
    BLT   R1, R2, 1           #  62: -20 < 6 signed: taken
    ADDI  R9, R0, 2           #  63:
    SW    R9, 0x58(R13)       #  64: [0x158] BLT taken                  => 0x00000001
    ADDI  R9, R0, 1           #  65:
    BLT   R2, R2, 1           #  66: 6 < 6 is false: falls through
    ADDI  R9, R0, 2           #  67:
    SW    R9, 0x5C(R13)       #  68: [0x15C] BLT not taken              => 0x00000002
    ADDI  R9, R0, 1           #  69:
    BGE   R2, R2, 1           #  70: 6 >= 6: taken
    ADDI  R9, R0, 2           #  71:
    SW    R9, 0x60(R13)       #  72: [0x160] BGE taken                  => 0x00000001
    ADDI  R9, R0, 1           #  73:
    BGE   R1, R2, 1           #  74: -20 >= 6 signed is false: falls through
    ADDI  R9, R0, 2           #  75:
    SW    R9, 0x64(R13)       #  76: [0x164] BGE not taken              => 0x00000002
    ADDI  R9, R0, 1           #  77:
    BLTU  R2, R1, 1           #  78: 6 < 0xFFFFFFEC unsigned: taken
    ADDI  R9, R0, 2           #  79:
    SW    R9, 0x68(R13)       #  80: [0x168] BLTU taken                 => 0x00000001
    ADDI  R9, R0, 1           #  81:
    BLTU  R2, R2, 1           #  82: 6 < 6 is false: falls through
    ADDI  R9, R0, 2           #  83:
    SW    R9, 0x6C(R13)       #  84: [0x16C] BLTU not taken             => 0x00000002
    ADDI  R9, R0, 1           #  85:
    BGEU  R1, R2, 1           #  86: 0xFFFFFFEC >= 6 unsigned: taken
    ADDI  R9, R0, 2           #  87:
    SW    R9, 0x70(R13)       #  88: [0x170] BGEU taken                 => 0x00000001
    ADDI  R9, R0, 1           #  89:
    BGEU  R2, R1, 1           #  90: 6 >= 0xFFFFFFEC unsigned is false: falls through
    ADDI  R9, R0, 2           #  91:
    SW    R9, 0x74(R13)       #  92: [0x174] BGEU not taken             => 0x00000002

# ---- backward branch (negative offset): sum = 3 + 2 + 1 ----
    ADDI  R10, R0, 3          #  93: counter = 3
    ADDI  R11, R0, 0          #  94: sum = 0
# COUNTDOWN:  (address 95)
    ADD   R11, R11, R10       #  95: sum = sum + counter
    ADDI  R10, R10, -1        #  96: counter = counter - 1
    BNE   R10, R0, -3         #  97: repeat while counter /= 0  [COUNTDOWN = address 95]
    SW    R11, 0x78(R13)      #  98: [0x178] backward branch            => 0x00000006

# ---- J ----
    ADDI  R9, R0, 1           #  99: 1 = J jumped
    J     102                 # 100:   [J_DONE = address 102]
    ADDI  R9, R0, 2           # 101: skipped when J works
# J_DONE:  (address 102)
    SW    R9, 0x7C(R13)       # 102: [0x17C] J                          => 0x00000001

# ---- JAL and JR: call SUB, which returns with JR R15 ----
    JAL   125                 # 103: R15 = address of the next instruction  [SUB = address 125]
    SW    R15, 0x80(R13)      # 104: [0x180] JAL return address (104)   => 0x00000068

# ---- floating point: FLW, FADD, FSUB, FMUL, FDIV, FSW ----
    FLW   F1, 0x10(R0)        # 105: F1 = 6.5
    FLW   F2, 0x14(R0)        # 106: F2 = -2.0
    FADD  F3, F1, F2          # 107: 6.5 + -2.0 = 4.5
    FSW   F3, 0x88(R13)       # 108: [0x188] FADD                       => 0x40900000
    FSUB  F4, F1, F2          # 109: 6.5 - -2.0 = 8.5
    FSW   F4, 0x8C(R13)       # 110: [0x18C] FSUB                       => 0x41080000
    FMUL  F5, F1, F2          # 111: 6.5 * -2.0 = -13.0
    FSW   F5, 0x90(R13)       # 112: [0x190] FMUL                       => 0xC1500000
    FDIV  F6, F1, F2          # 113: 6.5 / -2.0 = -3.25
    FSW   F6, 0x94(R13)       # 114: [0x194] FDIV                       => 0xC0500000

# ---- FLT, FMOV, FEQ ----
    FLT   R6, F6, F2          # 115: -3.25 < -2.0: 1 (comparing raw bits gives 0)
    SW    R6, 0x98(R13)       # 116: [0x198] FLT                        => 0x00000001
    FMOV  F7, F1              # 117: F7 = 6.5
    FSW   F7, 0x9C(R13)       # 118: [0x19C] FMOV                       => 0x40D00000
    FEQ   R6, F7, F1          # 119: 6.5 = 6.5: 1
    SW    R6, 0xA0(R13)       # 120: [0x1A0] FEQ                        => 0x00000001

# ---- dividing by zero gives infinity and does not stop the program ----
    FSUB  F8, F1, F1          # 121: F8 = 0.0
    FDIV  F9, F1, F8          # 122: 6.5 / 0.0 = +infinity
    FSW   F9, 0xA4(R13)       # 123: [0x1A4] FDIV by zero               => 0x7F800000

    HALT                      # 124: end of the test

# ---- subroutine for the JAL / JR test ----
# SUB:  (address 125)
    ADDI  R14, R0, 0x5B       # 125: marker: SUB was reached
    SW    R14, 0x84(R13)      # 126: [0x184] JAL reached SUB            => 0x0000005B
    JR    R15                 # 127: return to the instruction after the JAL
