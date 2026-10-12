# maxFinderInt -- finds the largest signed integer in an array.
#
# Labels have been replaced by numbers. Each comment starts with the
# instruction's address ("N:"), and [LABEL = address N] names the target
# of a branch or jump. A branch operand is an offset counted from the next
# instruction; a J or JAL operand is an absolute instruction address.
#
# Memory layout (byte addresses; 32-bit big-endian words):
#   0x000  N              number of elements
#   0x004  MAX            result, written by this program
#   0x008  A[0] ...       the array: N signed integers, one per word
#
# Works for whatever N and array the memory file supplies. If N <= 0 there
# is no maximum, so the program stores nothing and halts.
#
# Registers: R1 = N, R2 = address of the current element, R3 = largest so far,
# R5 = current element, R6 = end address (one word past the last element).

    LW    R1, 0(R0)           #   0: R1 = N
    BGE   R0, R1, 12          #   1: N <= 0: nothing to do  [DONE = address 14]
    ADDI  R2, R0, 8           #   2: R2 = address of A[0]
    ADDI  R7, R0, 2           #   3: R7 = 2, the shift amount for "times 4"
    SLL   R6, R1, R7          #   4: R6 = N * 4, the size of the array in bytes
    ADD   R6, R6, R2          #   5: R6 = end address
    LW    R3, 0(R2)           #   6: max = A[0]
# LOOP:  (address 7)
    ADDI  R2, R2, 4           #   7: move to the next element
    BGEU  R2, R6, 4           #   8: past the last element: finished  [STORE = address 13]
    LW    R5, 0(R2)           #   9: R5 = A[i]
    BGE   R3, R5, -4          #  10: max >= A[i]: keep max  [LOOP = address 7]
    ADDI  R3, R5, 0           #  11: max = A[i]
    J     7                   #  12: check the next element  [LOOP = address 7]
# STORE:  (address 13)
    SW    R3, 4(R0)           #  13: MAX = max
# DONE:  (address 14)
    HALT                      #  14: stop
