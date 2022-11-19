all:
	ca65 main.s --listing main.lst
	php ../makemif.php main.lst bin=../../program.bin mif=../../de0/mem.mif hex=../../tb.hex
	cd ../.. && make iverilog && ./tb
