all:
	ca65 main.s
	ld65 -t none main.o -o ../../program.bin
	rm main.o
	cd ../.. && make iverilog && ./tb
