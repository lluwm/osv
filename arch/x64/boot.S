
.text
.code32

mb_magic = 0x1BADB002
mb_flags = 0x00000001

multiboot:
	 .long mb_magic
	 .long mb_flags
	 .long 0-mb_magic-mb_flags

.data
.align 4096  #align to 4KB
ident_pt_l4: #PML4 entry
	 .quad ident_pt_l3 + 0x67 #P | RW | User | WB | Cache | Accessed
	 .rept 511
	 .quad 0
	 .endr
ident_pt_l3: #PDPT entry
	 .quad ident_pt_l2 + 0x67 #P | RW | User | WB | Cache | Accessed
	 .rept 511
	 .quad 0
	 .endr
ident_pt_l2: #PDE entry
	 index = 0
	 .rept 512
	 .quad (index << 21) + 0x1e7 #P | RW | User | WB | Cache | Accessed | Dirty | *PS* | Global (2M * 512 = 1GB is global for OS)
	 index = index + 1
	 .endr

gdt_desc:
	 .short gdt_end - gdt - 1
	 .long gdt

.align 8
gdt = . - 8
	 .quad 0x00af9b000000ffff #64-bit code segment
	 .quad 0x00cf93000000ffff #64-bit data segment
	 .quad 0x00cf9b000000ffff #32-bit code segment
gdt_end = .

.text
.globl start32
start32:
	 # boot16.S set %eax to 0x200000, we use it
	 mov  %eax, %ebp
	 lgdt gdt_desc
	 movw $0x10, %ax #Segment Selector points to 64-bit code segment.
	 movw %ax, %ds
	 movw %ax, %es
	 movw %ax, %fs
	 movw %ax, %gs
	 movw %ax, %ss
	 ljmp $0x18, $1f #Use segment selecotr=0x18(32-bit code segment) to jump to label 1.
1:
    // Throw error if the CPU doesn't support Long Mode.
    movl $0x80000000, %eax  // Set the A-register to 0x80000000.
    cpuid                   // CPU identification.
    cmp $0x80000001, %eax   // Compare the A-register with 0x80000001.
    mov $'2', %al
    jb no_long_mode         // It is less, there is no long mode.
    movl $0x80000001, %eax  // Set the A-register to 0x80000001.
    cpuid                   // CPU identification.
    test $1 << 29, %edx     // Test if the LM-bit, which is bit 29, is set in the D-register.
    mov $'3', %al
    jz no_long_mode         // They aren't, there is no long mode.
    test $1 << 6, %edx      // Test if the PAE, is set
    mov $'4', %al
    jz no_long_mode
no_long_mode:
    jmp error

	 mov $0x000007b8, %eax
	 mov %eax, %cr4         #CR4 = DE | PSE | *PAE* | PGE | PCE | OSFXSR | OSXMMEXCEPT
	 lea ident_pt_l4, %eax
	 mov %eax, %cr3         #CR3 points to PLM4's addr
	 mov 0xc0000080, %ecx
	 mov 0x00000900, %eax
	 xor %edx, %edx         #Extended Feature Enable Register (EFER) = LME (Long Mode Enable) | NXE (No-Execute Enable)
	 wrmsr
	 mov 0x80010001, %eax
	 mov %eax, %cr0         #CR0 = PE | WP | PG
	 ljmp $8, $start64

.code64
start64:
	 jmp main 

// Prints `ERR: ` and the given error code to screen and hangs.
// parameter: error code (in ascii) in al
error:
    movl $0x4f524f45, (0xb8000)
    movl $0x4f3a4f52, (0xb8004)
    movl $0x4f204f20, (0xb8008)
    movb %al, (0xb800a)
    hlt
