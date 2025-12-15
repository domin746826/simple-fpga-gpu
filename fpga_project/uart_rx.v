module uart_rx (
    input clk,          // 10 MHz zegar
    input rst,          // reset
    input rx,           // wejście szeregowe
    input data_ack,     // sygnał potwierdzający odczyt danych
    output reg [7:0] data,     // odebrane dane
    output reg data_ready,     // flaga gotowości danych
    output reg error         // błąd stopu
);

// Parametry czasowe
parameter CLK_FREQ = 40_000_000;//106_666_666;
// parameter CLK_FREQ = 106_666_666;

parameter BAUD_RATE = 1000000;
parameter CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
parameter CLKS_HALF_BIT = CLKS_PER_BIT / 2;

// Stany automatu
parameter IDLE  = 2'b00;
parameter START = 2'b01;
parameter DATA  = 2'b10;
parameter STOP  = 2'b11;

reg [1:0] state = IDLE;
reg [15:0] clk_count = 0;
reg [2:0] bit_index = 0;
reg [7:0] data_reg = 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= IDLE;
        clk_count <= 0;
        bit_index <= 0;
        data_reg <= 0;
        data_ready <= 0;
        error <= 0;
    end else begin
        // Kasowanie flagi przez zewnętrzny moduł
        if (data_ack)
            data_ready <= 0;
            
        case (state)
            IDLE: begin
                if ((rx == 0) && (!data_ready)) begin
                    state <= START;
                    clk_count <= 0;
                    error <= 0;
                end
            end
            
            START: begin
                if (clk_count == CLKS_HALF_BIT - 1) begin
                    if (rx == 0) begin // potwierdzenie bitu startu
                        state <= DATA;
                        clk_count <= 0;
                        bit_index <= 0;
                    end else begin
                        state <= IDLE;
                    end
                end else
                    clk_count <= clk_count + 1;
            end
            
            DATA: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    data_reg[bit_index] <= rx;
                    clk_count <= 0;
                    if (bit_index == 7)
                        state <= STOP;
                    else
                        bit_index <= bit_index + 1;
                end else
                    clk_count <= clk_count + 1;
            end
            
            STOP: begin
                if (clk_count == CLKS_PER_BIT - 1) begin
                    data <= data_reg;
                    data_ready <= 1;      // ustaw flagę gotowości
                    error <= (rx != 1);   // sprawdź bit stopu
                    state <= IDLE;
                    clk_count <= 0;
                end else
                    clk_count <= clk_count + 1;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule
