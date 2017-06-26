quiet = $(if $V, $1, @echo " $2"; $1)

all: loader.bin loader.img

loader.bin: loader.elf
	 objcopy -O elf32-i386 $^ $@

boot.bin: arch/x64/boot16.ld arch/x64/boot16.o
	 $(LD) -o $@ -T $^

loader.img: boot.bin loader.elf
	 $(call quiet, dd if=boot.bin of=$@ > /dev/null 2>&1, DD $@ boot.bin)
	 $(call quiet, dd if=loader.elf of=$@ conv=notrunc seek=128 > /dev/null 2>&1, \
					   DD $@ loader.elf)

loader.elf: arch/x64/boot.o loader.o
	 $(CXX) -nostartfiles -static -nodefaultlibs -g -T arch/x64/loader.ld -o $@ $^

MULTIROOT := $(shell if grub-file --is-x86-multiboot loader.bin; \
						   then echo multiboot confirmed;\
						   else \
								echo the file is not multiboot; \
						   fi;)

arch/x64/%.o: arch/x64/%.s
	 $(CC) $(KERN_CFLAGS) -g -c -o $@ $<

check:
	 @echo + $(MULTIROOT)

clean:
	 find -name '*.[od]' | xargs rm
	 rm -f loader.elf loader.bin loader.img boot.bin

qemu:
	 qemu-system-x86_64 -kernel loader.bin -serial mon:stdio -gdb tcp::26000 -S -no-shutdown -no-reboot -d int

qemu-run:
	 qemu-system-x86_64 -kernel loader.bin
