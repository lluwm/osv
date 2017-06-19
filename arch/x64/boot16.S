.code16

tmp = 0x8000        # 1KB away from 0x7c00
bootsect = 0x7c00

.text

.globl start
start:
    ljmp $0, $init

#LBA in extended mode.
#Format of disk address packet:
int1342_struct:
    .byte  0x10
    .byte  0x00
    .short 0x40 #0x40 * 512byte = 32KB
    .short 0x00 #transfer buffer (16bit segment)
    .short tmp / 16 #(16bit offset)
lba:
    .quad  128 #starting LBA number

gdt:
    .word gdt_size - 1
    .word gdt
    .long 0                  # trick to save 8 bytes, cause it will never be used. 
    .quad 0x00cf9b000000ffff # 32-bit code segment
    .quad 0x00cf93000000ffff # 32-bit data segment
    .quad 0x00009b000000ffff # 16-bit code segment
    .quad 0x000093000000ffff # 16-bit data segment
gdt_size = . - gdt
    

init:
    # BIOS does not guarantee anything about the contents of %ds, %es and %ss.
    # Set up the important data segment registers (DS, ES, SS).
    xor %ax, %ax
    mov %ax, %ds
    mov %ax, %es
    mov %ax, %ss
    mov $tmp, %sp

read_disk:
    # read 32KB starting from sector #128 to 0x8000
    lea int1342_struct, %si
    mov $0x42, %ah
    mov $0x80, %dl #"C" drive
    int $0x13

    # Disable maskable hardware interrupts, entering protected mode.
    # All interrupts work in real mode will not be available in protected mode
    cli

    mov $0x11, %ax
    lmsw %ax
    ljmp $8, $1f

1:
    .code32

