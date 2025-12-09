#include <stdio.h>
#include <stddef.h>

/* Minimal BPF definitions */
struct bpf_insn {
    unsigned short code;
    unsigned char jt;
    unsigned char jf;
    unsigned int k;
};

#define BPF_LD     0x00
#define BPF_LDX    0x01
#define BPF_ST     0x02
#define BPF_ALU    0x04
#define BPF_JMP    0x05
#define BPF_RET    0x06

#define BPF_IMM 0x00  // Load the constant 0x80 into A
#define BPF_ABS 0x20 // Load the constant at index k
#define BPF_IND 0x40 // Load the value at packet[k + A]
#define BPF_MEM 0x60	// Store A into scratch memory spot k
#define BPF_LEN 0x80
#define BPF_MSH 0xa0


#define BPF_ADD   0x00
#define  BPF_SUB   0x10
#define  BPF_MUL   0x20
#define  BPF_DIV   0x30
#define BPF_OR    0x40
#define BPF_AND   0x50
#define  BPF_LSH   0x60
#define  BPF_RSH   0x70
#define  BPF_NEG   0x80
#define  BPF_MOD   0x90
#define BPF_XOR   0xa0

#define BPF_X      0x08
#define BPF_K      0x00

#define BPF_STMT(code, k) { (unsigned short)(code), 0, 0, k }

struct bpf_insn mul_scratch_prog[] = {
    BPF_STMT(BPF_LD | BPF_IMM, 7),    // A = 7
    BPF_STMT(BPF_ST, 0),              // M[0] = A
    BPF_STMT(BPF_LDX | BPF_IMM, 3),   // X = 3
    BPF_STMT(BPF_ALU | BPF_MUL | BPF_X, 0), // A = A * X
    BPF_STMT(BPF_ST, 1),              // M[1] = A
    BPF_STMT(BPF_LDX | BPF_MEM, 1),    // A = M[1]
    BPF_STMT(BPF_RET | BPF_K, 1),     // return 1 -> accept packet
};

int main() {
    size_t n = sizeof(mul_scratch_prog)/sizeof(mul_scratch_prog[0]);
    for (size_t i = 0; i < n; i++) {
        struct bpf_insn ins = mul_scratch_prog[i];
        printf("Instruction %zu: code=0x%04x jt=0x%02x jf=0x%02x k=0x%08x\n",
               i, ins.code, ins.jt, ins.jf, ins.k);
    }
    return 0;
}