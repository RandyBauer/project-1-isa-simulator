# testAll: executes all 36 instructions.
# Results are 32-bit words stored at 0x100-0x1A4.
# Branch tests store 1 if the branch is taken, 2 if not.
#
# Input (testAll.mem):
#   0x000  0xFFFFFFEC  (-20)        0x010  0x40D00000  (6.5)
#   0x004  0x00000006  (6)          0x014  0xC0000000  (-2.0)
#   0x008  0xF0F0F0F0               0x0FC  0xCAFEF00D
#   0x00C  0x3C3C3C3C

    LW    R1, 0(R0)           # R1 = -20
    LW    R2, 4(R0)           # R2 = 6
    LW    R3, 8(R0)           # R3 = 0xF0F0F0F0
    LW    R4, 12(R0)          # R4 = 0x3C3C3C3C
    ADDI  R13, R0, 0x100      # R13 = 0x100, result base

# LW, SW
    LW    R5, -4(R13)         # R5 = M[0x0FC]
    SW    R5, 0x00(R13)       # M[0x100] = 0xCAFEF00D

# ALU-R
    ADD   R6, R1, R2
    SW    R6, 0x04(R13)       # M[0x104] = 0xFFFFFFF2
    SUB   R6, R2, R1
    SW    R6, 0x08(R13)       # M[0x108] = 0x0000001A
    AND   R6, R3, R4
    SW    R6, 0x0C(R13)       # M[0x10C] = 0x30303030
    OR    R6, R3, R4
    SW    R6, 0x10(R13)       # M[0x110] = 0xFCFCFCFC
    XOR   R6, R3, R4
    SW    R6, 0x14(R13)       # M[0x114] = 0xCCCCCCCC
    SLT   R6, R1, R2
    SW    R6, 0x18(R13)       # M[0x118] = 0x00000001
    SLTU  R6, R2, R1
    SW    R6, 0x1C(R13)       # M[0x11C] = 0x00000001
    ADDI  R7, R0, 36          # R7 = 36; shifts use R7[4:0] = 4
    SLL   R6, R3, R7
    SW    R6, 0x20(R13)       # M[0x120] = 0x0F0F0F00
    SRL   R6, R3, R7
    SW    R6, 0x24(R13)       # M[0x124] = 0x0F0F0F0F
    SRA   R6, R3, R7
    SW    R6, 0x28(R13)       # M[0x128] = 0xFF0F0F0F

# ALU-I, LUI
    ADDI  R6, R1, -1000
    SW    R6, 0x2C(R13)       # M[0x12C] = 0xFFFFFC04
    ANDI  R6, R1, 0xFF00
    SW    R6, 0x30(R13)       # M[0x130] = 0x0000FF00
    ORI   R6, R0, 0x8001
    SW    R6, 0x34(R13)       # M[0x134] = 0x00008001
    XORI  R6, R1, 0xFFFF
    SW    R6, 0x38(R13)       # M[0x138] = 0xFFFF0013
    LUI   R6, 0xBEEF
    SW    R6, 0x3C(R13)       # M[0x13C] = 0xBEEF0000

# Overflow, R0
    LUI   R8, 0x7FFF
    ORI   R8, R8, 0xFFFF      # R8 = 0x7FFFFFFF
    ADDI  R6, R8, 1
    SW    R6, 0x40(R13)       # M[0x140] = 0x80000000
    ADDI  R0, R0, 77          # no effect
    ADDI  R6, R0, 1
    SW    R6, 0x44(R13)       # M[0x144] = 0x00000001

# Branches
    ADDI  R9, R0, 1
    BEQ   R2, R2, 1           # taken
    ADDI  R9, R0, 2
    SW    R9, 0x48(R13)       # M[0x148] = 0x00000001
    ADDI  R9, R0, 1
    BEQ   R1, R2, 1           # not taken
    ADDI  R9, R0, 2
    SW    R9, 0x4C(R13)       # M[0x14C] = 0x00000002
    ADDI  R9, R0, 1
    BNE   R1, R2, 1           # taken
    ADDI  R9, R0, 2
    SW    R9, 0x50(R13)       # M[0x150] = 0x00000001
    ADDI  R9, R0, 1
    BNE   R2, R2, 1           # not taken
    ADDI  R9, R0, 2
    SW    R9, 0x54(R13)       # M[0x154] = 0x00000002
    ADDI  R9, R0, 1
    BLT   R1, R2, 1           # taken
    ADDI  R9, R0, 2
    SW    R9, 0x58(R13)       # M[0x158] = 0x00000001
    ADDI  R9, R0, 1
    BLT   R2, R2, 1           # not taken
    ADDI  R9, R0, 2
    SW    R9, 0x5C(R13)       # M[0x15C] = 0x00000002
    ADDI  R9, R0, 1
    BGE   R2, R2, 1           # taken
    ADDI  R9, R0, 2
    SW    R9, 0x60(R13)       # M[0x160] = 0x00000001
    ADDI  R9, R0, 1
    BGE   R1, R2, 1           # not taken
    ADDI  R9, R0, 2
    SW    R9, 0x64(R13)       # M[0x164] = 0x00000002
    ADDI  R9, R0, 1
    BLTU  R2, R1, 1           # taken
    ADDI  R9, R0, 2
    SW    R9, 0x68(R13)       # M[0x168] = 0x00000001
    ADDI  R9, R0, 1
    BLTU  R2, R2, 1           # not taken
    ADDI  R9, R0, 2
    SW    R9, 0x6C(R13)       # M[0x16C] = 0x00000002
    ADDI  R9, R0, 1
    BGEU  R1, R2, 1           # taken
    ADDI  R9, R0, 2
    SW    R9, 0x70(R13)       # M[0x170] = 0x00000001
    ADDI  R9, R0, 1
    BGEU  R2, R1, 1           # not taken
    ADDI  R9, R0, 2
    SW    R9, 0x74(R13)       # M[0x174] = 0x00000002

# Backward branch
    ADDI  R10, R0, 3
    ADDI  R11, R0, 0
COUNTDOWN:
    ADD   R11, R11, R10
    ADDI  R10, R10, -1
    BNE   R10, R0, COUNTDOWN
    SW    R11, 0x78(R13)      # M[0x178] = 0x00000006

# J
    ADDI  R9, R0, 1
    J     J_DONE
    ADDI  R9, R0, 2           # skipped
J_DONE:
    SW    R9, 0x7C(R13)       # M[0x17C] = 0x00000001

# JAL, JR
    JAL   SUB
    SW    R15, 0x80(R13)      # M[0x180] = 0x00000068

# FP
    FLW   F1, 0x10(R0)        # F1 = 6.5
    FLW   F2, 0x14(R0)        # F2 = -2.0
    FADD  F3, F1, F2
    FSW   F3, 0x88(R13)       # M[0x188] = 0x40900000 (4.5)
    FSUB  F4, F1, F2
    FSW   F4, 0x8C(R13)       # M[0x18C] = 0x41080000 (8.5)
    FMUL  F5, F1, F2
    FSW   F5, 0x90(R13)       # M[0x190] = 0xC1500000 (-13.0)
    FDIV  F6, F1, F2
    FSW   F6, 0x94(R13)       # M[0x194] = 0xC0500000 (-3.25)
    FLT   R6, F6, F2
    SW    R6, 0x98(R13)       # M[0x198] = 0x00000001
    FMOV  F7, F1
    FSW   F7, 0x9C(R13)       # M[0x19C] = 0x40D00000 (6.5)
    FEQ   R6, F7, F1
    SW    R6, 0xA0(R13)       # M[0x1A0] = 0x00000001
    FSUB  F8, F1, F1          # F8 = 0.0
    FDIV  F9, F1, F8
    FSW   F9, 0xA4(R13)       # M[0x1A4] = 0x7F800000 (+inf)

    HALT

SUB:
    ADDI  R14, R0, 0x5B
    SW    R14, 0x84(R13)      # M[0x184] = 0x0000005B
    JR    R15
