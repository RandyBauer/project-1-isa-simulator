# maxFinderInt: stores the largest signed integer in A[0..N-1] at MAX.
# If N <= 0, nothing is stored.
#
#   0x000  N
#   0x004  MAX
#   0x008  A[0] ... A[N-1]
#
# R1 = N, R2 = element address, R3 = max, R5 = A[i], R6 = end address

    LW    R1, 0(R0)           # R1 = N
    BGE   R0, R1, DONE        # N <= 0
    ADDI  R2, R0, 8           # R2 = address of A[0]
    ADDI  R7, R0, 2
    SLL   R6, R1, R7          # R6 = 4N
    ADD   R6, R6, R2          # R6 = address of A[N]
    LW    R3, 0(R2)           # max = A[0]
LOOP:
    ADDI  R2, R2, 4           # next element
    BGEU  R2, R6, STORE       # end of array
    LW    R5, 0(R2)           # R5 = A[i]
    BGE   R3, R5, LOOP        # max >= A[i]
    ADDI  R3, R5, 0           # max = A[i]
    J     LOOP
STORE:
    SW    R3, 4(R0)           # MAX = max
DONE:
    HALT
