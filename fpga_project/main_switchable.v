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
    input uart_rx,
    output reg led1,
    output wire led2

);


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
reg [2:0] current_mode; 

always @(posedge clk10m) begin
    if (btn1) begin
        current_mode <= 1;
    end else if(btn2) begin
        current_mode <= 2;
    end else if(btn3) begin
        current_mode <= 0;
    end
end

reg [14:0] vram_index = 22499;
wire [7:0] rx_byte;
reg rx_we = 0;

mode_mux mux (
    .clk10m(clk10m),
    .mode(current_mode),
    .hsync(hsync_pin),
    .vsync(vsync_pin),
    .r0(r0_pin),
    .r1(r1_pin),
    .g0(g0_pin),
    .g1(g1_pin),
    .b0(b0_pin),
    .b1(b1_pin),
    .user_data_out(),
    .user_data_in(rx_byte),
    .user_we(rx_we),
    .user_addr(vram_index),
    .user_clk(clk10m)
);



wire rx_data_valid;
reg dataack_read = 1'b0;

uart_rx uart_rx_inst (
    .clk(clk10m),
    .rst(0),
    .rx(uart_rx),
    .data_ack(dataack_read),
    .data(rx_byte),
    .data_ready(rx_data_valid),
    .error()
);

assign led2 = current_mode;
reg rx_data_valid_prev = 0;

always @(posedge clk10m) begin
    rx_data_valid_prev <= rx_data_valid;
    if (rx_data_valid && !rx_data_valid_prev) begin
        dataack_read <= 1;
        rx_we <= 1;
        if (vram_index == 22499)
            vram_index <= 0;
        else
            vram_index <= vram_index + 1;

        led1 <= ~led1;
    end else begin
        // dataack_read <= 0;
        rx_we <= 0;
    end
end

endmodule
