`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date:    21:46:07 04/27/2024
// Design Name:
// Module Name:    main
// Project Name:
// Target Devices:
// Tool versions:
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

/*
Modes:

0x00 Text mode 1440x900, font Terminus ter-216n 8x16
180 cols 56 rows

Format: character, color
color: low nibble - foreground, high nibble - background

0x0000-0x2759 - text (10080 bytes)
0x2760-0x4EBF - fg/bg colors (10080 bytes)
0x4EC0-0x5EBF - font (4096 bytes)
0x5EC0-0x5ECF - color palette (16 colors, 6 bit each, two oldest bits unused)
0x5ED0-0x5F00 - registers and reserved (48 bytes)
text 180x56
*/

module main (
    input clk10m,
    output wire vsync_pin,
    output wire hsync_pin,
    output wire r0_pin,
    output wire r1_pin,
    output wire g0_pin,
    output wire g1_pin,
    output wire b0_pin,
    output wire b1_pin,
    input wire btn1,
    input wire btn2,
    input wire btn3,
    output wire led1,
    output wire led2,
    
    // SPI interface
    input wire spi_clk, // vport 3
    output wire spi_miso, // vport 2
    input wire spi_mosi, // vport 1
    input wire spi_cs_n // vport 4
);


// #define PIN_MISO 16
// #define PIN_CS   17
// #define PIN_SCK  18
// #define PIN_MOSI 19

/*
 * Mode selection
    * 0 - disabled
    * 1 - text mode
    * 2 - graphic mode 6 bit color
    * 3 - graphic mode 4 bit color
    * 4 - Graphic mode 2 bit color
    * 5 - Graphic mode tiled
    * 6-7 - reserved
*/
reg [2:0] current_mode = 3'd1; // Default to text mode
reg spi_set_mode = 0;
reg [2:0] spi_new_mode = 0;

// Button handling for mode switching (SPI can also change mode via flags)
always @(posedge clk10m) begin
    if (btn1) begin
        current_mode <= 1;
    end else if(btn2) begin
        current_mode <= 2;
    end else if(btn3) begin
        current_mode <= 0;
    end else if (spi_set_mode) begin
        current_mode <= spi_new_mode;
    end
end

wire [7:0] vram_data_out;
reg [7:0] vram_write_data;
reg [14:0] vram_write_addr;
reg vram_write_en;

wire [11:0] vcounter;
reg [11:0] vcounter_dbuf;

wire clk160_int;
wire clk160m;

mode_mux mux (
    .clk10m(clk10m),
    .mode(current_mode),
    .hsync(hsync_pin),
    .vsync(vsync_pin),
    .vcounter(vcounter),
    .r0(r0_pin),
    .r1(r1_pin),
    .g0(g0_pin),
    .g1(g1_pin),
    .b0(b0_pin),
    .b1(b1_pin),
    .user_data_out(vram_data_out),
    .user_data_in(vram_write_data),
    .user_we(vram_write_en),
    .user_addr(vram_write_addr),
    .user_clk(clk160m)
);

assign led1 = 1;
assign led2 = 1;

/* SPI protocol
    * Commands:
    * 0xH1 - Write sequential data to VRAM (after setting address). 
        Next byte is a low byte of amount of bytes to write, H is low nibble of high byte of amount of bytes to write.
        Following bytes are data to write.
    * 0x02 - Set VRAM address, following 2 bytes: high byte then low byte
    * 0xH3 - Set display mode (H - mode)
    * 0x04 - Vcounter read: returns 2 bytes: first byte is high byte of vcounter, 
        second byte is low byte of vcounter
*/

localparam SPI_CMD_WRITE_CODE = 4'h1;
localparam SPI_CMD_SET_ADDR_CODE = 4'h2;
localparam SPI_CMD_SET_DISPLAY_MODE_CODE = 4'h3;
localparam SPI_CMD_READ_VCOUNTER_CODE = 4'h4;


wire spi_rx_ready;
wire [7:0] spi_rx_byte;
reg [7:0] spi_tx_byte = 8'h23;
reg [11:0] spi_write_bytes_remaining = 12'b0;

wire dcm_locked;

DCM_SP #(
    .CLKFX_MULTIPLY(22), 
    .CLKFX_DIVIDE(1), 
    .CLKIN_PERIOD(100.0),     // T clk10m = 100 ns
    .CLK_FEEDBACK("NONE"),
    .STARTUP_WAIT("FALSE")
) dcm_sp_inst (
    .CLKFX(clk160_int),
    .CLKIN(clk10m),
    .RST(1'b0),
    .LOCKED(dcm_locked),
    .CLK0(), .CLK2X(), .CLK90(), .CLK180(), .CLK270(),
    .CLKDV(), .CLKFX180(), .STATUS(), .PSCLK(), .PSEN(), .PSINCDEC(), .PSDONE()
);

// Bufor globalny
BUFG bufg_clk160 (.I(clk160_int), .O(clk160m));


spi_slave spi_slave_inst (
    .rst_n(1'b1),
    .clk_sys(clk160m),
    .rx_ready(spi_rx_ready),
    .rx_data(spi_rx_byte),
    .tx_data(spi_tx_byte),
    .sclk(spi_clk),
    .miso(spi_miso),
    .mosi(spi_mosi),
    .cs_n(spi_cs_n)
);




// SPI command state machine
localparam SPI_CMD_IDLE = 3'd0;
localparam SPI_CMD_WRITE_AMOUNT = 3'd1;
localparam SPI_CMD_WRITE = 3'd2;
localparam SPI_CMD_SET_ADDR_L = 3'd3;
localparam SPI_CMD_SET_ADDR_H = 3'd4;
localparam SPI_CMD_READ_VCOUNTER1 = 3'd5;

reg [2:0] spi_state = SPI_CMD_IDLE;

always @(posedge clk160m) begin
    vram_write_en <= 0;  // Default to no write
    spi_set_mode <= 0;

    if (spi_rx_ready) begin
        case (spi_state)
            SPI_CMD_IDLE: begin
                case (spi_rx_byte[3:0])
                    SPI_CMD_WRITE_CODE: begin // Write command
                        spi_state <= SPI_CMD_WRITE_AMOUNT;
                        // High nibble of command byte = bits [11:8] of byte count
                        spi_write_bytes_remaining[11:8] <= spi_rx_byte[7:4];
                    end
                    SPI_CMD_SET_ADDR_CODE: begin // Set address
                        spi_state <= SPI_CMD_SET_ADDR_H;
                    end
                    SPI_CMD_SET_DISPLAY_MODE_CODE: begin // Set display mode
                        spi_new_mode <= spi_rx_byte[6:4]; // Use 3 bits for mode
                        spi_set_mode <= 1;
                        spi_state <= SPI_CMD_IDLE;
                    end
                
                    SPI_CMD_READ_VCOUNTER_CODE: begin // Read vcounter
                        // Załaduj HIGH byte vcounter - będzie wysłany przy NASTĘPNYM bajcie od mastera
                        vcounter_dbuf <= vcounter; // Zatrzaśnij aktualną wartość
                        spi_tx_byte <= vcounter[11:8];
                        spi_state <= SPI_CMD_READ_VCOUNTER1;
                    end

  
                    default: begin
                        spi_state <= SPI_CMD_IDLE; // Unknown command, ignore
                    end
                endcase
            end
            SPI_CMD_WRITE_AMOUNT: begin
                // This byte = bits [7:0] of byte count
                spi_write_bytes_remaining[7:0] <= spi_rx_byte;
                spi_state <= SPI_CMD_WRITE;
            end
            SPI_CMD_WRITE: begin
                vram_write_en <= 1;
                vram_write_data <= spi_rx_byte;
                vram_write_addr <= vram_write_addr + 1;
                if (spi_write_bytes_remaining == 1) begin
                    spi_state <= SPI_CMD_IDLE;
                end
                spi_write_bytes_remaining <= spi_write_bytes_remaining - 1;
            end
            SPI_CMD_SET_ADDR_H: begin
                vram_write_addr[14:8] <= spi_rx_byte[6:0];
                spi_state <= SPI_CMD_SET_ADDR_L;
            end
            SPI_CMD_SET_ADDR_L: begin
                // Ustawiamy adres - 1, bo w SPI_CMD_WRITE następuje inkrementacja
                // w tym samym cyklu co write_en, więc VRAM widzi już zinkrementowany adres
                vram_write_addr <= {vram_write_addr[14:8], spi_rx_byte} - 1;
                spi_state <= SPI_CMD_IDLE;
            end
            SPI_CMD_READ_VCOUNTER1: begin
                // Master wysłał dummy byte, teraz ładujemy LOW byte do następnego transferu
                spi_tx_byte <= vcounter_dbuf[7:0];
                spi_state <= SPI_CMD_IDLE;
            end
            
        endcase
    end
end

endmodule
