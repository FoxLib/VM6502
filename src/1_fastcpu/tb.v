`timescale 10ns / 1ns

module tb;
// ---------------------------------------------------------------------
reg clock;     always #0.5 clock    = ~clock;
reg clock_25;  always #1.0 clock_50 = ~clock_50;
reg clock_50;  always #2.0 clock_25 = ~clock_25;
reg reset_n = 1'b0;
reg intr    = 1'b0;
// ---------------------------------------------------------------------
initial begin clock = 0; clock_25 = 0; clock_50 = 0; #5 reset_n = 1'b1; #20 intr = 1'b1; #2000 $finish; end
initial begin $dumpfile("tb.vcd"); $dumpvars(0, tb); end
initial begin $readmemh("tb.hex", mem, 1'b0); end
// ---------------------------------------------------------------------
reg  [ 7:0] mem[65536];
reg  [ 7:0] vim[2048];

reg  [ 7:0] in;
wire [ 7:0] out;
wire [15:0] address;
wire [15:0] address_vga;

always @(posedge clock) begin in <= mem[address]; if (we) mem[address] <= out; end
// ---------------------------------------------------------------------

core Ricoh6502
(
    .clock      (clock_25),
    .hold       (1'b1),
    .reset_n    (reset_n),
    .intr       (intr),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

endmodule
