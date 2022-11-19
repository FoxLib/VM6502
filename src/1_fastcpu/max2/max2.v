module max2
(
    input  wire         clock, // 100 Mhz (pd)
    input  wire [3:0]   key,   // 4 кнопки
    output wire [7:0]   led,   // 8 светодиодов
    output wire [9:0]   f0,    // Силовой двигатель 0
    output wire [9:0]   f1,    // Силовой двигатель 1
    output wire [9:0]   f2,    // Силовой двигатель 2
    output wire [9:0]   f3,    // Силовой двигатель 3
    output wire [9:0]   f4,    // Силовой двигатель 4
    output wire [9:0]   f5,    // Силовой двигатель 5
    inout  wire         dp,    // DP для USB
    inout  wire         dn,    // DN для USB
    inout  wire         pt     // Свободный контакт
);

core N6502
(
    .clock   (clock),
    .hold    (1'b1),
    .reset_n (1'b1),
    .address ({f1[4:0], f0[9:0]}),
    .in      ({key, f2[8:5]}),
    .out     (led),
    .we      (dn)
);

endmodule

`include "../core.v"
