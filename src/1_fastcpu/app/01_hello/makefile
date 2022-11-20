MIF=php ../makemif.php

all:
	ca65 main.s --listing main.lst
	$(MIF) main.lst \
		bin=../../program.bin \
		mif=../../de0/mem.mif \
		hex=../../tb.hex
	rm *.o
	cd ../.. && make iverilog && ./tb
