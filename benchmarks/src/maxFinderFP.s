# maxFinderFP -- finds the largest floating-point value in an array.
#
# Memory layout (byte addresses; 32-bit big-endian words):
#   0x000  N              number of elements (an integer)
#   0x004  MAX            result, written by this program
#   0x008  A[0] ...       the array: N IEEE-754 single-precision values
#
# Works for whatever N and array the memory file supplies. If N <= 0 there
# is no maximum, so the program stores nothing and halts.
#
# Registers: R1 = N, R2 = address of the current element, R5 = compare
# result, R6 = end address (one word past the last element),
# F1 = largest so far, F2 = current element.

    LW    R1, 0(R0)           # R1 = N
    BGE   R0, R1, DONE        # N <= 0: nothing to do
    ADDI  R2, R0, 8           # R2 = address of A[0]
    ADDI  R7, R0, 2           # R7 = 2, the shift amount for "times 4"
    SLL   R6, R1, R7          # R6 = N * 4, the size of the array in bytes
    ADD   R6, R6, R2          # R6 = end address
    FLW   F1, 0(R2)           # max = A[0]
LOOP:
    ADDI  R2, R2, 4           # move to the next element
    BGEU  R2, R6, STORE       # past the last element: finished
    FLW   F2, 0(R2)           # F2 = A[i]
    FLT   R5, F1, F2          # R5 = 1 if max < A[i]
    BEQ   R5, R0, LOOP        # not larger: keep max
    FMOV  F1, F2              # max = A[i]
    J     LOOP                # check the next element
STORE:
    FSW   F1, 4(R0)           # MAX = max
DONE:
    HALT                      # stop
