OUTPUT_FORMAT(binary)

MEMORY
{
	 bootsect : ORIGIN = 0, LENGTH = 0x10000
}

SECTIONS
{
	 .text 0x7c00 : { *(.text) } > bootsect
}
