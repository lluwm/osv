SECTIONS
{
	 . = 0x200000;
	 .text : { *(.text) }
	 .data : { *(.data) }
	 .bss  : { *(.bss) }
}
ENTRY(start32)
