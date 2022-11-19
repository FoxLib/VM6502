/*
 * Для реализации процессора с набором инструкции 6502
 */

/* verilator lint_off WIDTH */
/* verilator lint_off CASEX */
/* verilator lint_off CASEOVERLAP */
/* verilator lint_off CASEINCOMPLETE */

module core
(
    input               clock,
    input               hold,
    input               reset_n,
    input               intr,
    output      [15:0]  address,
    input       [ 7:0]  in,
    output  reg [ 7:0]  out,
    output  reg         we
);

assign address = bus ? ea : pc;

initial begin out = 8'h00; we = 1'b0; end

// Состояния процессора
localparam
    MAIN = 0,
    NDX  = 1, NDX2 = 2, NDX3 = 3,
    NDY  = 4, NDY2 = 5, NDY3 = 6,
    ZP   = 7, ZPX  = 8, ZPY  = 9,
    ABS  = 10, ABS2 = 11,
    ABX  = 12, ABX2 = 13, ABY  = 14,
    REL  = 15, EXEC = 16,
    WRT  = 17, PUSH = 18, IND  = 19,
    JSR  = 20, JSR1 = 21, JSR2 = 22, JSR3 = 23,
    RTS  = 24, RTS1 = 25, RTI  = 26,
    BRK  = 27;

// Все регистры процессора
// -----------------------------------------------------------------------------
reg [15:0]  pc = 16'h0000;
reg [ 7:0]  A  = 8'h23;
reg [ 7:0]  X  = 8'h12;
reg [ 7:0]  Y  = 8'hAF;
reg [ 7:0]  S  = 8'h77;                     // Указатель стека
//                  NV BDIZC
reg [ 7:0]  P  = 8'b00100100;               // Регистр флагов
// -----------------------------------------------------------------------------
reg [ 4:0]  t           = 5'b0;             // Фаза исполнения
reg         bus         = 1'b0;             // =0 PC; =1 EA указатель
reg [15:0]  ea          = 16'h0000;         // Указатель в память
reg [ 7:0]  opcode      = 8'h00;            // Текущий опкод
reg [ 7:0]  tr          = 8'h00;            // Временный регистр
reg         cout        = 1'b0;             // Для вычисления адресов
reg [ 3:0]  alu         = 4'h0;             // Номер функции АЛУ
reg         intr_       = 1'b0;
// -----------------------------------------------------------------------------
wire [15:0] eainc       = ea + 1'b1;        // Инкремент EA
wire [8:0]  xdin        = X + in;           // Для преиндексной адресации
wire [8:0]  ydin        = Y + in;           // Для постиндексной адресации
wire [7:0]  inx         = X + 1'b1;
wire [7:0]  dex         = X - 1'b1;
wire [7:0]  iny         = Y + 1'b1;
wire [7:0]  dey         = Y - 1'b1;
wire [7:0]  sp          = S + 1'b1;
wire [7:0]  sm          = S - 1'b1;
wire [2:0]  trinc       = tr[2:0] + 1'b1;
// -----------------------------------------------------------------------------
reg  [1:0]  dst         = 2'b00;            // Левый операнд
reg  [1:0]  src         = 2'b00;            // Правый операнд

// Левый операнд
wire [7:0]  op1 = src == 2'b00 ? A :
                  src == 2'b01 ? X :
                  src == 2'b10 ? Y : 8'b0;

// Правый операнд
wire [7:0]  op2 = dst == 2'b00 ? in:
                  dst == 2'b01 ? X :
                  dst == 2'b10 ? Y : A;
// -----------------------------------------------------------------------------
//                  Z     C     V     N
wire [3:0]  br = {P[1], P[0], P[6], P[7]};

always @(posedge clock)
// Если =1, процессор запущен в работу
if (hold) begin
// Сброс процессор
if (reset_n == 1'b0) begin

    t  <= BRK;
    //    ВЕКТОР   ФАЗА
    tr <= 8'b10_000_011;

end
else case (t)

    // ИНИЦИАЛИЗИРУЮЩИЙ ТАКТ
    // -------------------------------------------------------------------------

    MAIN: begin

        opcode  <= in;
        tr      <= 8'b0;
        src     <= 2'b0;            // A
        dst     <= 2'b0;            // MEM
        pc      <= pc + 1'b1;
        intr_   <= intr;

        // ==================================
        // Вызов прерывания (I=0)
        // ==================================

        if ({intr_, intr} == 2'b01 && !P[2]) begin

            t       <= BRK;
            pc      <= pc;
            tr[7:6] <= 2'b11;

        end
        else begin

            // ==================================
            // Декодер или исполнитель инструкции
            // ==================================

            casex (in)
            // NOP, TAX, TYA, INX, CLC и т.д. ОДНОТАКТОВЫЕ
            8'hEA, 8'h18, 8'h38, 8'h58, 8'h78, 8'hD8,
            8'hF8, 8'hB8, 8'hBA, 8'h88, 8'hC8, 8'hCA,
            8'hE8, 8'h8A, 8'h98, 8'hAA, 8'hA8, 8'h9A: t <= MAIN;
            // SUBROUTINE
            8'b001_000_00: t <= JSR;
            // BRK
            8'b000_000_00: begin

                t       <= BRK;
                pc      <= pc + 16'h2;
                tr[7:6] <= 2'b11;       // Вектор

            end
            // RTS, RTI
            8'b01x_000_00: begin

                t       <= in[5] ? RTS : RTI;
                S       <= sp;
                ea      <= {8'h01, sp};
                bus     <= 1'b1;

            end
            // Операнды
            8'bxxx_000_x1: t <= NDX;
            8'bxxx_010_x1,
            8'b1xx_000_x0: t <= EXEC;
            8'bxxx_100_x1: t <= NDY;
            8'bxxx_110_x1: t <= ABY;
            8'bxxx_001_xx: t <= ZP;
            8'bxxx_011_xx,
            8'b001_000_00: t <= ABS;
            8'b10x_101_1x: t <= ZPY;
            8'bxxx_101_xx: t <= ZPX;
            8'b10x_111_1x: t <= ABY;
            8'bxxx_111_xx: t <= ABX;
            // Относительный переход
            8'bxxx_100_00: begin

                if (br[ in[7:6] ] == in[5])
                     begin t <= REL; end
                else begin t <= MAIN; pc <= pc + 16'h2; end

            end
            // Все остальные без операнда
            default: t <= EXEC;
            endcase

            // ==================================
            // Дополнительные коррекции
            // ==================================

            case (in)

            // Выбор источников данных для АЛУ
            8'hE0, 8'hE4, 8'hEC: src <= 2'b01;          // CPX
            8'hC0, 8'hC4, 8'hCC: src <= 2'b10;          // CPY
            8'h0A, 8'h2A, 8'h4A, 8'h6A: dst <= 2'h3;    // (ASL|LSR|ROL|ROR) A

            // PHP, PHA
            8'h08, 8'h48: begin

                t   <= PUSH;
                we  <= 1'b1;
                bus <= 1'b1;
                ea  <= {8'h01, S};
                out <= in[6] ? A : (P | 8'h30);

            end

            // PLA, PLP
            8'h68, 8'h28: begin S <= sp; bus <= 1'b1; ea <= {8'h01, sp}; end

            // Флаговые инструкции
            8'h18, 8'h38: begin P[0] <= in[5]; end // CLC, SEC
            8'h58, 8'h78: begin P[2] <= in[5]; end // CLI, SEI
            8'hD8, 8'hF8: begin P[3] <= in[5]; end // CLD, SED
            8'hB8:        begin P[6] <= 1'b0;  end // CLV

            // Декремент и инкремент регистров
            8'h88:/*DEY*/ begin Y <= dey; {P[7], P[1]} <= {dey[7], dey == 8'b0}; end
            8'hC8:/*INY*/ begin Y <= iny; {P[7], P[1]} <= {iny[7], iny == 8'b0}; end
            8'hCA:/*DEX*/ begin X <= dex; {P[7], P[1]} <= {dex[7], dex == 8'b0}; end
            8'hE8:/*INX*/ begin X <= inx; {P[7], P[1]} <= {inx[7], inx == 8'b0}; end

            // Перемещения из регистра в регистр, декремент, и
            8'h8A:/*TXA*/ begin A <= X; {P[7], P[1]} <= {X[7], X == 8'b0}; end
            8'h98:/*TYA*/ begin A <= Y; {P[7], P[1]} <= {Y[7], Y == 8'b0}; end
            8'hAA:/*TAX*/ begin X <= A; {P[7], P[1]} <= {A[7], A == 8'b0}; end
            8'hA8:/*TAY*/ begin Y <= A; {P[7], P[1]} <= {A[7], A == 8'b0}; end
            8'hBA:/*TSX*/ begin X <= S; {P[7], P[1]} <= {S[7], S == 8'b0}; end
            8'h9A:/*TXS*/ begin S <= X; end
            endcase

            // ==================================
            // Выбор АЛУ
            // ==================================

            case (in)
            8'h24, 8'h2C: alu <= 4'hC;                      // BIT
            8'h06, 8'h0E, 8'h16, 8'h1E, 8'h0A: alu <= 4'h8; // ASL
            8'h26, 8'h2E, 8'h36, 8'h3E, 8'h2A: alu <= 4'h9; // ROL
            8'h46, 8'h4E, 8'h56, 8'h5E, 8'h4A: alu <= 4'hA; // LSR
            8'h66, 8'h6E, 8'h76, 8'h7E, 8'h6A: alu <= 4'hB; // ROR
            8'hC6, 8'hCE, 8'hD6, 8'hDE: alu <= 4'hD;        // DEC
            8'hE6, 8'hEE, 8'hF6, 8'hFE: alu <= 4'hE;        // INC
            default: alu <= {1'b0, in[7:5]};                // ОБЩИЕ
            endcase

        end

    end

    // ПРОЧИТАТЬ АДРЕС ОПЕРАНДА В ПАМЯТИ
    // -------------------------------------------------------------------------

    // (Indirect,X)
    NDX:  begin t <= NDX2; ea <=  xdin[7:0]; bus <= 1'b1; pc <= pc + 16'b1; end
    NDX2: begin t <= NDX3; ea <= eainc[7:0]; tr  <= in; end
    NDX3: begin t <= EXEC; ea <= {in, tr}; end

    // (Indirect),Y
    NDY:  begin t <= NDY2; ea <= in; bus <= 1'b1; pc <= pc + 16'b1; end
    NDY2: begin t <= NDY3; ea <= eainc[7:0]; {cout, tr} <= ydin; end
    NDY3: begin t <= EXEC; ea <= {in + cout, tr}; end

    // ZP, ZPX, ZPY
    ZP:   begin t <= EXEC; pc <= pc + 1'b1; bus <= 1'b1; ea <= in;end
    ZPX:  begin t <= EXEC; pc <= pc + 1'b1; bus <= 1'b1; ea <= xdin[7:0]; end
    ZPY:  begin t <= EXEC; pc <= pc + 1'b1; bus <= 1'b1; ea <= ydin[7:0];  end

    // Absolute
    ABS:  begin t <= ABS2; tr <= in; pc <= pc + 1'b1; end
    ABS2: begin

        if (opcode == 8'h4C)
             begin t <= MAIN; pc <= {in, tr}; bus <= 1'b0; end
        else begin t <= EXEC; ea <= {in, tr}; bus <= 1'b1; pc <= pc + 1'b1; end

    end

    // Absolute,X/Y
    ABX:  begin t <= ABX2; pc <= pc + 1'b1; tr <= xdin[7:0]; cout <= xdin[8]; end
    ABY:  begin t <= ABX2; pc <= pc + 1'b1; tr <= ydin[7:0]; cout <= ydin[8]; end
    ABX2: begin t <= EXEC; pc <= pc + 1'b1; ea <= {in + cout, tr}; bus <= 1'b1; end

    // Исполнение условного перехода
    REL:  begin t <= MAIN; pc <= pc + 1'b1 + {{8{in[7]}}, in}; end

    // ИСПОЛНЕНИЕ ИНСТРУКЦИИ
    // -------------------------------------------------------------------------

    EXEC: begin

        t <= MAIN;

        casex (opcode)

            // STA, STX, STY
            8'b100xxx01: begin we <= 1'b1; out <= A; t <= WRT; end
            8'b100xx110: begin we <= 1'b1; out <= X; t <= WRT; end
            8'b100xx100: begin we <= 1'b1; out <= Y; t <= WRT; end

            // BIT
            8'h24, 8'h2C: begin P <= af; bus <= 1'b0; end

            // ROL,ROR,ASR,LSR, DEC,INC
            8'b0xxxx110,
            8'b11xxx110: begin we <= 1'b1; out <= R[7:0]; P <= af; t <= WRT; end

            // <ROL,ROR,ASR,LSR> Acc
            8'b0xx01010: begin A <= R[7:0]; P <= af; end

            // LDY, LDX
            8'hA0, 8'hA4, 8'hAC, 8'hB4, 8'hBC: begin P <= af; bus <= 1'b0; Y <= R[7:0]; end
            8'hA2, 8'hA6, 8'hAE, 8'hB6, 8'hBE: begin P <= af; bus <= 1'b0; X <= R[7:0]; end

            // CPX, CPY
            8'hE0, 8'hE4, 8'hEC,
            8'hC0, 8'hC4, 8'hCC: begin P <= af; bus <= 1'b0; end

            // PLA, PLP
            8'h68: begin A <= in; bus <= 1'b0; {P[7], P[1]} <= {in[7], in == 1'b0}; end
            8'h28: begin P <= in; bus <= 1'b0; end

            // JMP (IND)
            8'h6C: begin t <= IND; tr <= in; ea <= ea + 1'b1; end

            // <ALU> A, op
            8'bxxxxxx01: begin P <= af; bus <= 1'b0; if (opcode[7:5] != 3'b110 /*CMP*/) A <= R[7:0]; end

        endcase

        // При IMM, добавить PC+1
        casex (opcode) 8'bxxx0_10x1, 8'b1xx_000_x0: pc <= pc + 1'b1; endcase

    end

    // Дополнительный такт к EXEC
    // -----------------------------------------------------------------

    // Завершение записи в память и переход к выполнению новой инструкции
    WRT:  begin we <= 1'b0; bus <= 1'b0; t <= MAIN; end

    // После операции PHA/PHP
    PUSH: begin t <= MAIN; we <= 1'b0; bus <= 1'b0; S <= sm; end

    // Инструкция JMP (IND)
    IND: begin t <= MAIN; bus <= 1'b0; pc <= {in, tr}; end

    // JSR: Вызов подпрограммы
    // -----------------------------------------------------------------

    JSR:  begin t <= JSR1; tr <= in; pc <= pc + 1'b1; end
    JSR1: begin t <= JSR2;

        bus <= 1'b1;
        we  <= 1'b1;
        pc  <= {in, tr};
        tr  <= pc[ 7:0];
        out <= pc[15:8];
        ea  <= {8'h01, S};
        S   <= sm;

    end

    JSR2: begin t <= JSR3; out <= tr;   ea <= {8'h01, S}; S <= sm; end
    JSR3: begin t <= MAIN; bus <= 1'b0; we <= 1'b0; end

    // Возврат из подпрограммы (RTS) или прерывания (RTI)
    // -----------------------------------------------------------------

    RTI:  begin t <= RTS;  P   <= in;   S <= sp; ea[7:0] <= sp; end
    RTS:  begin t <= RTS1; pc  <= in;   S <= sp; ea[7:0] <= sp; end
    RTS1: begin t <= MAIN; bus <= 1'b0; S <= sp; pc <= {in, pc[7:0]} + opcode[5]; end

    // Вызов пользовательского или аппаратного прерывания
    // -----------------------------------------------------------------

    BRK: case (tr[2:0])

        // Прерывание
        0: begin tr[2:0] <= trinc; out <= pc[15:8];  ea <= {8'h01, S}; S <= sm; bus <= 1'b1; we <= 1'b1; end
        1: begin tr[2:0] <= trinc; out <= pc[ 7:0];  ea <= {8'h01, S}; S <= sm; end
        2: begin tr[2:0] <= trinc; out <= P | 8'h10; ea <= {8'h01, S}; S <= sm; P[2] <= 1'b1; end
        // Сброс
        3: begin tr[2:0] <= trinc; we  <= 1'b0; ea <= {8'hFF, 5'b11111, tr[7:6], 1'b0}; bus <= 1'b1; end
        4: begin tr[2:0] <= trinc;       pc[ 7:0] <= in; ea[0] <= 1'b1; end
        5: begin t <= MAIN; bus <= 1'b0; pc[15:8] <= in; end

    endcase

endcase

end

// Арифметико-логическое устройство
// =============================================================================

reg  [8:0]  R;
reg  [7:0]  af;

// Статусы ALU
wire zero  = R[7:0] == 8'b0; // Флаг нуля
wire sign  = R[7];           // Флаг знака
wire oadc  = (op1[7] ^ op2[7] ^ 1'b1) & (op1[7] ^ R[7]); // Переполнение ADC
wire osbc  = (op1[7] ^ op2[7]       ) & (op1[7] ^ R[7]); // Переполнение SBC
wire cin   =  P[0];
wire carry =  R[8];

always @* begin

    // Расчет результата
    case (alu)

        // Основные
        /* ORA */ 4'h0: R = op1 | op2;
        /* AND */ 4'h1: R = op1 & op2;
        /* EOR */ 4'h2: R = op1 ^ op2;
        /* ADC */ 4'h3: R = op1 + op2 + cin;
        /* STA */ 4'h4: R = op1;
        /* LDA */ 4'h5: R = op2;
        /* CMP */ 4'h6: R = op1 - op2;
        /* SBC */ 4'h7: R = op1 - op2 - !cin;
        // Дополнительные
        /* ASL */ 4'h8: R = {op2[6:0], 1'b0};
        /* ROL */ 4'h9: R = {op2[6:0], cin};
        /* LSR */ 4'hA: R = {1'b0, op2[7:1]};
        /* ROR */ 4'hB: R = {cin,  op2[7:1]};
        /* BIT */ 4'hC: R = op1 & op2;
        /* DEC */ 4'hD: R = op2 - 1'b1;
        /* INC */ 4'hE: R = op2 + 1'b1;

    endcase

    // Расчет флагов
    casex (alu)

        // ORA, AND, EOR, STA, LDA, DEC, INC
        4'b000x, 4'b0010, 4'b010x, 4'b111x:
                 af = {sign,       P[6:2], zero,   P[0]}; // OTH
        4'b0011: af = {sign, oadc, P[5:2], zero,  carry}; // ADC
        4'b0110: af = {sign,       P[6:2], zero, ~carry}; // CMP
        4'b0111: af = {sign, osbc, P[5:2], zero, ~carry}; // SBC
        4'b100x: af = {sign,       P[6:2], zero, op2[7]}; // ASL, ROL
        4'b101x: af = {sign,       P[6:2], zero, op2[0]}; // LSR, ROR
        4'b1100: af = {op2[7:6],   P[5:2], zero,   P[0]}; // BIT

    endcase

end

endmodule
