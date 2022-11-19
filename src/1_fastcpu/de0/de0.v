module de0(

    // Reset
    input              RESET_N,

    // Clocks
    input              CLOCK_50,
    input              CLOCK2_50,
    input              CLOCK3_50,
    inout              CLOCK4_50,

    // DRAM
    output             DRAM_CKE,
    output             DRAM_CLK,
    output      [1:0]  DRAM_BA,
    output      [12:0] DRAM_ADDR,
    inout       [15:0] DRAM_DQ,
    output             DRAM_CAS_N,
    output             DRAM_RAS_N,
    output             DRAM_WE_N,
    output             DRAM_CS_N,
    output             DRAM_LDQM,
    output             DRAM_UDQM,

    // GPIO
    inout       [35:0] GPIO_0,
    inout       [35:0] GPIO_1,

    // 7-Segment LED
    output      [6:0]  HEX0,
    output      [6:0]  HEX1,
    output      [6:0]  HEX2,
    output      [6:0]  HEX3,
    output      [6:0]  HEX4,
    output      [6:0]  HEX5,

    // Keys
    input       [3:0]  KEY,

    // LED
    output      [9:0]  LEDR,

    // PS/2
    inout              PS2_CLK,
    inout              PS2_DAT,
    inout              PS2_CLK2,
    inout              PS2_DAT2,

    // SD-Card
    output             SD_CLK,
    inout              SD_CMD,
    inout       [3:0]  SD_DATA,

    // Switch
    input       [9:0]  SW,

    // VGA
    output      [3:0]  VGA_R,
    output      [3:0]  VGA_G,
    output      [3:0]  VGA_B,
    output             VGA_HS,
    output             VGA_VS
);

// Z-state
assign DRAM_DQ = 16'hzzzz;
assign GPIO_0  = 36'hzzzzzzzz;
assign GPIO_1  = 36'hzzzzzzzz;

// LED OFF
assign HEX0 = 7'b1111111;
assign HEX1 = 7'b1111111;
assign HEX2 = 7'b1111111;
assign HEX3 = 7'b1111111;
assign HEX4 = 7'b1111111;
assign HEX5 = 7'b1111111;

// ГЕНЕРАТОР ЧАСТОТЫ
// -----------------------------------------------------------------------------

wire locked;
wire clock_25;
wire clock_50;
wire clock_100;

de0pll unit_pll
(
    .clkin     (CLOCK_50),
    .m25       (clock_25),
    .m50       (clock_50),
    .m100      (clock_100),
    .locked    (locked)
);

// ВИДЕОАДАПТЕР
// -----------------------------------------------------------------------------

reg         mode;
wire [15:0] scr_addr;
wire [ 7:0] scr_data;
wire [17:0] ga;
wire [17:0] gw;
wire [ 3:0] gd;
wire [ 3:0] go;
wire        gwe;

dsub dsub_inst
(
    .clock      (clock_25),
    .reset_n    (locked),
    .mode       (mode),
    .R          (VGA_R),
    .G          (VGA_G),
    .B          (VGA_B),
    .HS         (VGA_HS),
    .VS         (VGA_VS),
    // Текстовый
    .address    (scr_addr),
    .data       (scr_data),
    .cursor     (10'h0),
    // Графический
    .ga         (ga),
    .gd         (gd),
    // Запись в графическую область
    .gw         (gw),
    .go         (go),
    .gwe        (gwe),
);

// МАРШРУТИЗАЦИЯ ПАМЯТИ
// -----------------------------------------------------------------------------

wire [ 7:0] in_mem64;

always @(*) begin

    case (address)

        // Состояние клавиатуры
        16'h0200: in = ps2_data;
        16'h0201: in = keyb_latch;

        // Области память
        default:  in = in_mem64;

    endcase

end

// Запись в память (порт)
always @(posedge clock_25)
begin

    if (we) begin

        case (address)

        // Видеорежим, меняется только 0-й бит
        16'h202: mode <= out[0];

        endcase
    end

end

// ЯДРО ПРОЦЕССОРА
// -----------------------------------------------------------------------------

wire [15:0] address;
reg  [ 7:0] in;
wire [ 7:0] out;
wire        we;

core Ricoh6502
(
    .clock      (clock_25),
    .hold       (1'b1),
    .reset_n    (locked),
    .address    (address),
    .in         (in),
    .out        (out),
    .we         (we)
);

// МОДУЛИ ПАМЯТИ 64+128=192
// -----------------------------------------------------------------------------

// Общий
mem mem_inst
(
    .clock  (clock_100),
    .a0     (address),
    .q0     (in_mem64),
    .d0     (out),
    .w0     (we),

    // Видеоданные в 2xxx; Шрифт 3xxx
    .a1     (scr_addr),
    .q1     (scr_data)
);

// Графический 128К
vid vid_inst
(
    .clock  (clock_100),
    // Чтение
    .a0     (ga),
    .q0     (gd),
    // Запись
    .a1     (gw),
    .d1     (go),
    .w1     (gwe),
);

// ПЕРИФЕРИЯ
// -----------------------------------------------------------------------------

wire [7:0]  ps2_data;
wire        ps2_hit;
reg  [7:0]  keyb_latch = 8'h00;

ps2 ps2_inst
(
    .clock      (clock_25),
    .ps_clock   (PS2_CLK),
    .ps_data    (PS2_DAT),
    .done       (ps2_hit),
    .data       (ps2_data)
);

always @(posedge clock_25) if (ps2_hit) keyb_latch <= keyb_latch + 1'b1;

endmodule

`include "../core.v"
`include "../dsub.v"
`include "../ps2.v"
