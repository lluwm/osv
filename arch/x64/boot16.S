.code16

tmp = 0x8000        # 1KB away from 0x7c00
bootsect = 0x7c00
target = 0x200000
entry = 24 + target # 0x200018

mb_info = 0x1000
mb_mmap_len = (mb_info + 44)  # mb length  info is at location: 0x102c
mb_mmap_addr = (mb_info + 48) # mb address info is at location: 0x1030
e820data = 0x2000

.text

.globl start
start:
    ljmp $0, $init

count32:
	 .word 4096 # in 32KB unit, 32KB * 4096 = 128MB

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

xfer: .long target

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
    mov $0x7c00, %sp
    mov $0x2401, %ax # enable a20 gate
    int $0x15

read_disk:
    # read 32KB starting from sector $lba to 0x8000
    lea int1342_struct, %si
    mov $0x42, %ah
    mov $0x80, %dl #"C" drive
    int $0x13

    # Disable maskable hardware interrupts, entering protected mode.
    # All interrupts work in real mode will not be available in protected mode
    cli

	 # load global descriptor table.
	 lgdtw gdt

	 # Switch to protected mode.
    mov $0x11, %ax
    lmsw %ax
	 # Jump to flush the instruction queue.
    ljmp $8, $1f

1:
    .code32
	 # move 32KB data from 0x8000 to xfer (1st: 0x200000; 2nd: 0x28000; etc...)
	 cld				  # string operation increment
	 mov $0x10, %ax  # DS and ES point to 32-bit DATA seg.
	 mov %eax, %ds
	 mov %eax, %es
	 mov $tmp, %esi
	 mov xfer, %edi
	 mov $0x8000, %ecx
	 rep movsb		  # move (ECX) bytes at address DS:(ESI) to address ES:(EDI)
	 mov %edi, xfer  # xfer stores the ending address
	 mov $0x20, %ax  # DS and ES point to 16-bit DATA seg.
	 mov %eax,  %ds
	 mov %eax,  %es
	 ljmpw $0x18, $1f # jump to 16-bit CODE segment
1:
	 .code16
	 # Switch back to real mode to do another disk read !!
	 mov %cr0, %eax
	 and 0xfe, %al    # clear PE
	 mov %eax, %cr0
	 # Jump to flush the instruction queue
	 ljmpw $0, $1f
1:
	 # clear DS and ES registers
	 xor %ax, %ax
	 mov %ax, %ds
	 mov %ax, %es

	 # enable interrupts
	 sti

	 addl $(0x8000 / 0x200), lba # update LBA starting number
	 decw count32
	 jnz read_disk # read $count32 times.

	 # Now detecting memory
	 mov $e820data, %edi   # ES:DI at the destination buffer for the list
	 mov %edi, mb_mmap_len # fill in mb address info
	 xor %ebx, %ebx        # clear EBX
more_e820:
	 mov $100, %ecx        # buffer size
	 mov $0x534D4150, %edx # magic number
	 mov $0xe820, %ax
	 add $4, %edi          # reserve 4 byte space
	 int $0x15
	 jc done_e820			  # error, jump out
	 mov %ecx, -4(%edi)	  # ECX contains # of bytes returned by the BIOS
								  # move the number before the returned entry.
	 add %ecx, %edi        # next dest location
	 test %ebx, %ebx		  # EBX reset to 0 if reach the end
	 jnz more_e820
done_e820:
	 sub $e820data, %edi
	 mov %edi, mb_mmap_len # fill in mb address info

	 cli
	 # Switch to protected mode !!
	 mov $0x11, %ax
	 lmsw %ax
	 ljmp $8, $1f
1:
	 .code32
	 mov $0x10, %ax
	 mov %eax, %ds
	 mov %eax, %es
	 mov %eax, %gs
	 mov %eax, %fs
	 mov %eax, %ss
	 mov $target, %eax
	 mov $mb_info, %ebx
	 jmp *entry

.org 0x1fe
.byte 0x55, 0xaa
