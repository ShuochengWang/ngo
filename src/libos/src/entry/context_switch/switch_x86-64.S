#define __ASSEMBLY__
#include "switch.h"

    .global __switch_to_user
    .type __switch_to_user, @function
__switch_to_user:
    // %rdi - CpuContext* user_context
    // %rsi - jmp_buf jb
    // %rdx - void* fault

    // Save the states of the kernel space
    movq %rdi, %gs:(TD_USER_CONTEXT)
    movq %rsi, %gs:(TD_KERNEL_JMPBUF)
    movq %rdx, %gs:(TD_USER_FAULT)
    movq %rsp, %gs:(TD_KERNEL_RSP)
    rdfsbase %rcx
    movq %rcx, %gs:(TD_KERNEL_FS)

    // Use user FS
    movq CPU_CONTEXT_FSBASE(%rdi), %rsi
    wrfsbase %rsi

    // Get the user's RIP
    movq (16*8)(%rdi), %rcx
    movq %rcx, %gs:(TD_USER_RIP)

    // Restore the CPU context of the user space
    movq %rdi, %rsp
    pop %r8
    pop %r9
    pop %r10
    pop %r11
    pop %r12
    pop %r13
    pop %r14
    pop %r15
    pop %rdi
    pop %rsi
    pop %rbp
    pop %rbx
    pop %rdx
    pop %rax
    pop %rcx
    pop %rsp
    jmp *%gs:(TD_USER_RIP)

    // This should never happen
    ud2

    .global __syscall_entry_linux_abi
    .type __syscall_entry_linux_abi, @function
__syscall_entry_linux_abi:
    //      num  - %rax
    //      arg0 - %rdi
    //      arg1 - %rsi
    //      arg2 - %rdx
    //      arg3 - %r10
    //      arg4 - %r8
    //      arg5 - *r9
    //      return address - %rcx

    // Get the pointer of the target CPU context.
    // We can use %r11 safely because r11 is used to store RFLAGs.
    movq %gs:(TD_USER_CONTEXT), %r11

    // Save most general-purpose registers of user
    movq %r8,  CPU_CONTEXT_R8(%r11)
    movq %r9,  CPU_CONTEXT_R9(%r11)
    movq %r10, CPU_CONTEXT_R10(%r11)
    movq %r11, CPU_CONTEXT_R11(%r11)
    movq %r12, CPU_CONTEXT_R12(%r11)
    movq %r13, CPU_CONTEXT_R13(%r11)
    movq %r14, CPU_CONTEXT_R14(%r11)
    movq %r15, CPU_CONTEXT_R15(%r11)
    movq %rdi, CPU_CONTEXT_RDI(%r11)
    movq %rsi, CPU_CONTEXT_RSI(%r11)
    movq %rbp, CPU_CONTEXT_RBP(%r11)
    movq %rbx, CPU_CONTEXT_RBX(%r11)
    movq %rdx, CPU_CONTEXT_RDX(%r11)
    movq %rax, CPU_CONTEXT_RAX(%r11)
    movq %rcx, CPU_CONTEXT_RCX(%r11)
    movq %rsp, CPU_CONTEXT_RSP(%r11)
    movq %rcx, CPU_CONTEXT_RIP(%r11)

    // Switch to the kernel stack
    movq %gs:(TD_KERNEL_RSP), %rsp

    // Save the rflags of user
    pushfq
    popq %rcx
    movq %rcx, CPU_CONTEXT_RFLAGS(%r11)

    // Switch to the kernel FS
    movq %gs:(TD_KERNEL_FS), %rcx
    wrfsbase %rcx

    // Set the two pointers to NULL so that we can detect misuse
    xor %rax, %rax
    movq %rax, %gs:(TD_USER_CONTEXT)
    movq %rax, %gs:(TD_USER_FAULT)

    movq %gs:(TD_KERNEL_JMPBUF), %rdi
    // Keep the stack 16-byte alignment
    and $-16, %rsp
    call _restore_kernel_state

    // This should never happen
    ud2

    .global __switch_to_kernel
    .type __switch_to_kernel, @function
__switch_to_kernel:
    // Switch to the kernel stack
    movq %gs:(TD_KERNEL_RSP), %rsp

    // Switch to the kernel FS
    movq %gs:(TD_KERNEL_FS), %rcx
    wrfsbase %rcx

    // Set the two pointers to NULL so that we can detect misuse
    xor %rax, %rax
    movq %rax, %gs:(TD_USER_CONTEXT)
    movq %rax, %gs:(TD_USER_FAULT)

    movq %gs:(TD_KERNEL_JMPBUF), %rdi
    // Keep the stack 16-byte alignment
    and $-16, %rsp
    call _restore_kernel_state

    // This should never happen
    ud2

    .global __current_context_ptr
    .type __current_context_ptr, @function
__current_context_ptr:
    movq %gs:(TD_USER_CONTEXT), %rax
    ret

    .global __current_fault_ptr
    .type __current_fault_ptr, @function
__current_fault_ptr:
    movq %gs:(TD_USER_FAULT), %rax
    ret
