/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */

module ga
(
    // Физический интерфейс
    input               clock,
    output  reg [3:0]   R,
    output  reg [3:0]   G,
    output  reg [3:0]   B,
    output              HS,
    output              VS,

    // Доступ к памяти
    output  reg [9:0]   char_addr,  // Адрес знака
    input       [7:0]   char_data,  // Знакоместо
    output  reg [9:0]   font_addr,  // Адрес маски
    input       [7:0]   font_data   // Маска
);

// ---------------------------------------------------------------------
// Тайминги для горизонтальной|вертикальной развертки (640x400)
// ---------------------------------------------------------------------

parameter
    hz_visible = 640, vt_visible = 400,
    hz_front   = 16,  vt_front   = 12,
    hz_sync    = 96,  vt_sync    = 2,
    hz_back    = 48,  vt_back    = 35,
    hz_whole   = 800, vt_whole   = 449;

assign HS = x  < (hz_back + hz_visible + hz_front); // NEG.
assign VS = y >= (vt_back + vt_visible + vt_front); // POS.
// ---------------------------------------------------------------------
wire        xmax = (x == hz_whole - 1);
wire        ymax = (y == vt_whole - 1);
wire [10:0] X    = x - hz_back - 64;    // X=[0..511]
wire [ 9:0] Y    = y - vt_back - 8;     // Y=[0..191]
wire [10:0] Xnxt = X + 5'h10;
// ---------------------------------------------------------------------
// Регистры
// ---------------------------------------------------------------------
reg  [10:0] x    = 0;
reg  [10:0] y    = 0;
reg  [ 7:0] mask;
reg         attr;
// ---------------------------------------------------------------------

// Вывод видеосигнала
always @(posedge clock) begin

    {R, G, B} <= 12'h000;

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    if (x >= hz_back && x < hz_visible + hz_back &&
        y >= vt_back && y < vt_visible + vt_back)
    begin
        {R, G, B} <= (X < 512 && Y < 384) ? (mask[ 3'h7 ^ X[3:1] ] ^ attr ? 12'hCCC : 12'h111) : 12'h111;
    end

    // Считывание символа
    case (X[3:0])

    4'h0: begin char_addr <= {Y[8:4], Xnxt[8:4]}; end
    4'h1: begin font_addr <= {char_data, Y[3:1]}; attr <= char_data[7]; end
    4'hF: begin mask      <= font_data; end

    endcase

end

endmodule
