all: loader.bin

loader.bin: loader.elf
	 objcopy -O elf32-i386 $^ $@

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
	 rm -f loader.elf loader.bin

qemu:
	 qemu-system-x86_64 -kernel loader.bin -serial mon:stdio -gdb tcp::26000 -S
