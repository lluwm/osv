
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
	 .short 0x1f    #0x1f=31 (4 global descriptors).
	 .long gdt - 8  #

.align 8
gdt:
	 .quad 0x00af9b000000ffff #64-bit code segment
	 .quad 0x00cf93000000ffff #64-bit data segment
	 .quad 0x00cf9b000000ffff #32-bit code segment

.text
.globl start32
start32:
	 lgdt gdt_desc
	 mov $0x10, %eax #Segment Selector points to 64-bit code segment.
	 mov %eax, %ds
	 mov %eax, %es
	 mov %eax, %fs
	 mov %eax, %gs
	 mov %eax, %ss
	 ljmp $0x18, $1f #Use segment selecotr=0x18(32-bit code segment) to jump to label 1.
1:
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
