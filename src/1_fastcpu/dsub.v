/* verilator lint_off WIDTH */
/* verilator lint_off CASEINCOMPLETE */

module dsub
(
    // Опорная частота
    input   wire        clock,
    input   wire        reset_n,
    input   wire        mode,       // 0=text, 1=graphics

    // Выходные данные
    output  reg  [3:0]  R,          // 4 бит на красный
    output  reg  [3:0]  G,          // 4 бит на зеленый
    output  reg  [3:0]  B,          // 4 бит на синий
    output  wire        HS,         // горизонтальная развертка
    output  wire        VS,         // вертикальная развертка

    // Доступ к памяти
    output  reg  [15:0] address,    // 4k Шрифты 8x16 [0000-0FFF] | 4k Видеоданные [1000..1FFF]
    input   wire [ 7:0] data,       // data = videoram[ address ]

    // 125K = 640 x 400 x 0.5 (16)
    output  reg  [17:0] ga,         // Графический адрес
    output  reg  [17:0] gw,         // Графический адрес
    input   wire [ 3:0] gd,         // Графические данные (IN)
    output  reg  [ 3:0] go,         // Графические данные (OUT)
    output  reg         gwe,        // Запись в память (WE)

    // Внешний интерфейс
    input   wire [10:0] cursor      // Положение курсора от 0 до 2047
);

initial begin go = 4'h0; gwe = 1'b0; end

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
reg  [10:0] x    = 0;
reg  [10:0] y    = 0;
wire [10:0] X    = x - hz_back + 8; // X=[0..639]
wire [ 9:0] Y    = y - vt_back;     // Y=[0..399]
wire [10:0] Xg   = x - hz_back + 2;
// ---------------------------------------------------------------------

// ---------------------------------------------------------------------
// Текстовый видеоадаптер
// ---------------------------------------------------------------------
reg  [ 7:0] char;  reg [7:0] tchar; // Битовая маска
reg  [ 7:0] attr;  reg [7:0] tattr; // Атрибут
reg  [23:0] timer;                  // Мерцание курсора
reg         flash;
// ---------------------------------------------------------------------

// Текущая позиция курсора
wire [10:0] id = X[9:3] + (Y[8:4] * 80);

// Если появляется курсор [1..4000], то он использует нижние 2 строки у линии
wire maskbit = (char[ 3'h7 ^ X[2:0] ]) | (flash && (id == cursor+1) && Y[3:0] >= 14);

// Разбираем цветовую компоненту (нижние 4 бита отвечают за цвет символа)
wire [15:0] frcolor =

    attr[3:0] == 4'h0 ? 12'h111 : // 0 Черный (почти)
    attr[3:0] == 4'h1 ? 12'h008 : // 1 Синий (темный)
    attr[3:0] == 4'h2 ? 12'h080 : // 2 Зеленый (темный)
    attr[3:0] == 4'h3 ? 12'h088 : // 3 Бирюзовый (темный)
    attr[3:0] == 4'h4 ? 12'h800 : // 4 Красный (темный)
    attr[3:0] == 4'h5 ? 12'h808 : // 5 Фиолетовый (темный)
    attr[3:0] == 4'h6 ? 12'h880 : // 6 Коричневый
    attr[3:0] == 4'h7 ? 12'hccc : // 7 Серый -- тут что-то не то
    attr[3:0] == 4'h8 ? 12'h888 : // 8 Темно-серый
    attr[3:0] == 4'h9 ? 12'h00f : // 9 Синий (темный)
    attr[3:0] == 4'hA ? 12'h0f0 : // 10 Зеленый
    attr[3:0] == 4'hB ? 12'h0ff : // 11 Бирюзовый
    attr[3:0] == 4'hC ? 12'hf00 : // 12 Красный
    attr[3:0] == 4'hD ? 12'hf0f : // 13 Фиолетовый
    attr[3:0] == 4'hE ? 12'hff0 : // 14 Желтый
                        12'hfff;  // 15 Белый

// Цветовая компонента фона (только 8 цветов)
wire [15:0] bgcolor =

    attr[6:4] == 3'd0 ? 12'h111 : // 0 Черный (почти)
    attr[6:4] == 3'd1 ? 12'h008 : // 1 Синий (темный)
    attr[6:4] == 3'd2 ? 12'h080 : // 2 Зеленый (темный)
    attr[6:4] == 3'd3 ? 12'h088 : // 3 Бирюзовый (темный)
    attr[6:4] == 3'd4 ? 12'h800 : // 4 Красный (темный)
    attr[6:4] == 3'd5 ? 12'h808 : // 5 Фиолетовый (темный)
    attr[6:4] == 3'd6 ? 12'h880 : // 6 Коричневый
                        12'hccc;  // 7 Серый

// ---------------------------------------------------------------------
reg [4:0]   st          = 1'b0;
reg [4:0]   next        = 1'b0;
reg [7:0]   fn          = 1'b0;
reg [7:0]   pv          = 8'h00;        // Предыдущее значение в $204
reg [7:0]   opcode      = 8'h00;
reg [15:0]  xc          = 16'h0;
reg [15:0]  yc          = 16'h0;
reg [15:0]  paddr       = 16'h0;        // Сохранение адреса
// ---------------------------------------------------------------------
reg [15:0]  x1;
reg [15:0]  y1;
reg [15:0]  x2;
reg [15:0]  y2;
reg [ 7:0]  cl;
reg [ 2:0]  dx;
// ---------------------------------------------------------------------
wire [15:0] A1 = address + 1'b1;
// ---------------------------------------------------------------------

// Вывод видеосигнала
always @(posedge clock) begin

    // Кадровая развертка
    x <= xmax ?         0 : x + 1;
    y <= xmax ? (ymax ? 0 : y + 1) : y;

    // Вывод окна видеоадаптера
    if (x >= hz_back && x < hz_visible + hz_back &&
        y >= vt_back && y < vt_visible + vt_back)
    begin

        if (mode)
            {R, G, B} <= frcolor;
        else
            {R, G, B} <= maskbit ? (attr[7] & flash ? bgcolor : frcolor) : bgcolor;

    end
    else {R, G, B} <= 12'h000;

end

// Извлечение битовой маски и атрибутов для генерации шрифта
always @(posedge clock) begin

    // Графический режим и видеоускоритель
    if (mode) begin

        // Вывод на экран
        ga   <= Xg + Y*640;
        attr <= gd;

        // Исполнительное устройство
        if (reset_n == 1'b0) st <= 1'b0;
        else case (st)

            // Тест на изменение состояния памяти
            // ---------------------------------------------------------

            0: begin st <= 1; address <= 16'h204; end
            1: begin

                st      <= (pv == data) ? 0: 2;
                pv      <= data;
                address <= 16'h2000;

            end

            // (NEXT) Исполнение одной инструкции
            // ---------------------------------------------------------

            2: begin

                next    <= 0;
                gwe     <= 1'b0;
                fn      <= 1'b0;
                opcode  <= data;
                address <= A1;

                case (data)

                    // BLOCK (x1, y1)-(x2,y2), cl
                    8'h01: begin st <= 3; next <= 4; end

                    // BDRAW (x1,y1),address,width,height,cl
                    8'h02: begin st <= 3; next <= 5; end

                    // SPRITE (x1,y1),address,width,height,opacity
                    8'h03: begin st <= 3; next <= 6; end

                    // $FIN
                    8'hFF: begin st <= 0; end

                endcase

            end

            // Считывание X1,Y1,X2,Y2,CL
            // ---------------------------------------------------------

            3: case (fn)

                // x1, y1
                0: begin fn <= 1; x1[ 7:0] <= data; address <= A1; end
                1: begin fn <= 2; x1[15:8] <= data; address <= A1; end
                2: begin fn <= 3; y1[ 7:0] <= data; address <= A1; end
                3: begin fn <= 4; y1[15:8] <= data; address <= A1; end
                // x2, y2
                4: begin fn <= 5; x2[ 7:0] <= data; address <= A1; end
                5: begin fn <= 6; x2[15:8] <= data; address <= A1; end
                6: begin fn <= 7; y2[ 7:0] <= data; address <= A1; end
                7: begin fn <= 8; y2[15:8] <= data; address <= A1; end
                // color
                8: begin fn <= 9; cl       <= data; address <= A1; fn <= 0; st <= next; end

            endcase

            // $01 Рисование прямоугольника
            // ---------------------------------------------------------

            4: case (fn)

                // Вычисление границ прямоугольника
                0: begin

                    fn <= 1;

                    // Блок за пределами рисования -- не рисовать его вообще
                    if (x1 > x2 || y1 > y2 || x2[15] || y2[15] || x1 > 639 || y1 > 399) st <= 2;
                    else begin

                        yc <= y1;

                        // Коррекция границ
                        if (x1[15]) x1 <= 1'b0; else if (x2 > 639) x2 <= 639;
                        if (y1[15]) yc <= 1'b0; else if (y2 > 399) y2 <= 399;

                    end

                end

                // Начало линии
                1: begin

                    fn  <= 2;
                    xc  <= x1;
                    go  <= cl;
                    gwe <= 1'b0;

                end

                // Рисование линии
                2: begin

                    gwe <= 1'b1;
                    gw  <= xc + yc*640;
                    xc  <= xc + 1'b1;

                    // Если линия достигла предела, то остановить запись в память
                    if (xc == x2) begin

                        if (yc == y2)
                             begin st <= 2; end
                        else begin fn <= 1; xc <= x1; yc  <= yc + 1'b1; end

                    end

                end

            endcase

            // $02 Рисование битовой маски
            // ---------------------------------------------------------

            5: case (fn)

                0: begin

                    paddr   <= address;
                    address <= x2;
                    fn      <= 1;
                    yc      <= y1;
                    go      <= cl;
                    x2      <= x1 + y2[7:0];

                end

                1: begin

                    gwe <= 1'b0;
                    fn  <= 2;
                    xc  <= x1;
                    dx  <= 7;

                end

                2: begin

                    dx  <= dx - 1'b1;
                    gw  <= xc + 640*yc;
                    xc  <= xc + 1'b1;

                    // Рисовать точку если она в пределах досягаемости
                    gwe <= {xc[15], yc[15]} == 2'b00 && xc < 640 && yc < 400 && data[dx];

                    if (xc == x2 || dx == 1'b0) begin

                        fn <= 1;
                        yc <= yc + 1'b1;
                        address <= address + 1'b1;

                        if (y2[15:8] == 1'b0)
                             begin st <= 2; address <= paddr; end
                        else begin y2[15:8] <= y2[15:8] - 1'b1; end

                    end

                end

            endcase

        endcase

    end
    // Текстовый режим
    else case (X[2:0])

        0: begin address <= {4'b0010, 1'b0, id[10:0]}; end // $2000
        1: begin tchar   <= data; address[11] <= 1'b1; end // $2800
        2: begin tattr   <= data; address <= {4'b0011, tchar[7:0], Y[3:0]}; end // $3000
        3: begin tchar   <= data; end
        7: begin attr    <= tattr; char <= tchar; end

    endcase

end


// Каждые 0,5 секунды перебрасывается регистр flash
always @(posedge clock) begin

    if (timer == 12500000) begin
        flash <= ~flash;
        timer <= 0;
    end else
        timer <= timer + 1;
end

endmodule
