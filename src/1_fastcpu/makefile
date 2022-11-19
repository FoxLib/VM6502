VRL=/usr/share/verilator/include

all: iverilog
tbc: iverilog verilated
	g++ -o tb -I$(VRL) $(VRL)/verilated.cpp tb.cc -lSDL2 \
	obj_dir/Vdsub__ALL.a \
	obj_dir/Vps2__ALL.a \
	obj_dir/Vcore__ALL.a
iverilog:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v core.v dsub.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
verilated:
	verilator -cc dsub.v
	verilator -cc core.v
	verilator -cc ps2.v
	cd obj_dir && make -f Vdsub.mk
	cd obj_dir && make -f Vcore.mk
	cd obj_dir && make -f Vps2.mk
vcd:
	gtkwave tb.vcd
wave:
	gtkwave tb.gtkw
mif:
	quartus_cdb de0 -c de0 --update_mif
	quartus_asm --read_settings_files=on --write_settings_files=off de0 -c de0
clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld *.rpt *.summary *.sof *.done *.pin *.qws *.bak *.smsg *.qws *.vcd *.qqq *.jic *.map .qsys_edit undo_redo.txt PLLJ_PLLSPE_INFO.txt c5_pin_model_dump.txt

