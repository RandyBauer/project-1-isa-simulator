# maxFinderInt -- finds the largest signed integer in an array.
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

    LW    R1, 0(R0)           # R1 = N
    BGE   R0, R1, DONE        # N <= 0: nothing to do
    ADDI  R2, R0, 8           # R2 = address of A[0]
    ADDI  R7, R0, 2           # R7 = 2, the shift amount for "times 4"
    SLL   R6, R1, R7          # R6 = N * 4, the size of the array in bytes
    ADD   R6, R6, R2          # R6 = end address
    LW    R3, 0(R2)           # max = A[0]
LOOP:
    ADDI  R2, R2, 4           # move to the next element
    BGEU  R2, R6, STORE       # past the last element: finished
    LW    R5, 0(R2)           # R5 = A[i]
    BGE   R3, R5, LOOP        # max >= A[i]: keep max
    ADDI  R3, R5, 0           # max = A[i]
    J     LOOP                # check the next element
STORE:
    SW    R3, 4(R0)           # MAX = max
DONE:
    HALT                      # stop
