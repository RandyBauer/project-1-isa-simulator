# maxFinderFP: stores the largest single-precision value in A[0..N-1] at MAX.
# If N <= 0, nothing is stored.
#
#   0x000  N (integer)
#   0x004  MAX
#   0x008  A[0] ... A[N-1]
#
# R1 = N, R2 = element address, R5 = compare result, R6 = end address,
# F1 = max, F2 = A[i]

    LW    R1, 0(R0)           # R1 = N
    BGE   R0, R1, DONE        # N <= 0
    ADDI  R2, R0, 8           # R2 = address of A[0]
    ADDI  R7, R0, 2
    SLL   R6, R1, R7          # R6 = 4N
    ADD   R6, R6, R2          # R6 = address of A[N]
    FLW   F1, 0(R2)           # max = A[0]
LOOP:
    ADDI  R2, R2, 4           # next element
    BGEU  R2, R6, STORE       # end of array
    FLW   F2, 0(R2)           # F2 = A[i]
    FLT   R5, F1, F2          # R5 = (max < A[i])
    BEQ   R5, R0, LOOP        # max >= A[i]
    FMOV  F1, F2              # max = A[i]
    J     LOOP
STORE:
    FSW   F1, 4(R0)           # MAX = max
DONE:
    HALT
