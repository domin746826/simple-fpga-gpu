module spi_slave (
    input  wire       rst_n,      
    input  wire       clk_sys,    // system clock
    
    // SPI Interface
    input  wire       sclk,       // SPI clock (directly controls TX)
    input  wire       cs_n,       
    input  wire       mosi,
    output wire       miso,
    
    // User Interface
    output reg        rx_ready,
    output reg  [7:0] rx_data,
    input  wire [7:0] tx_data 
);

    // ==========================================================
    // RX SECTION
    // ==========================================================
    reg [2:0] sclk_sync;
    reg [2:0] cs_sync;
    reg [1:0] mosi_sync;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            sclk_sync <= 3'b000;
            cs_sync   <= 3'b111;
            mosi_sync <= 2'b00;
        end else begin
            sclk_sync <= {sclk_sync[1:0], sclk};
            cs_sync   <= {cs_sync[1:0], cs_n};
            mosi_sync <= {mosi_sync[0], mosi};
        end
    end

    wire sclk_rising = (sclk_sync[2:1] == 2'b01);
    wire cs_active   = ~cs_sync[1];

    reg [2:0] rx_bit_cnt;
    reg [7:0] rx_shift;

    always @(posedge clk_sys or negedge rst_n) begin
        if (!rst_n) begin
            rx_ready <= 0;
            rx_data  <= 0;
            rx_bit_cnt <= 0;
            rx_shift <= 0;
        end else begin
            rx_ready <= 0;
            if (!cs_active) begin
                rx_bit_cnt <= 0;
            end else if (sclk_rising) begin
                rx_shift <= {rx_shift[6:0], mosi_sync[1]};
                rx_bit_cnt <= rx_bit_cnt + 1;
                if (rx_bit_cnt == 7) begin
                    rx_data <= {rx_shift[6:0], mosi_sync[1]};
                    rx_ready <= 1;
                end
            end
        end
    end

    // ==========================================================
    // TX SECTION
    // ==========================================================
    reg [7:0] tx_shift;
    reg [2:0] tx_bit_cnt;
    
    
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            tx_shift   <= tx_data; 
            tx_bit_cnt <= 3'b111;
        end else begin
            if (tx_bit_cnt == 3'b000) begin
                tx_shift   <= tx_data; // Auto-reload for the next byte
                tx_bit_cnt <= 3'b111;
            end else begin
                // Classic left shift (MSB First)
                tx_shift <= {tx_shift[6:0], 1'b0}; 
                tx_bit_cnt <= tx_bit_cnt - 1;
            end
        end
    end

    // Output control
    assign miso = (cs_n) ? 1'bz : tx_shift[7];

endmodule