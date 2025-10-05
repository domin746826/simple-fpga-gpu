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

    input uart_rx,
    output reg led1,
    output wire led2

);

wire clk106_int;
wire clk106m;
wire dcm_locked;

DCM_SP #(
    .CLKFX_MULTIPLY(32),      // mnożnik
    .CLKFX_DIVIDE(3),         // dzielnik
    .CLKIN_PERIOD(100.0),     // okres wejściowego clk10m = 100 ns
    .CLK_FEEDBACK("NONE"),
    .STARTUP_WAIT("FALSE")
) dcm_sp_inst (
    .CLKFX(clk106_int),   // wygenerowany zegar ~106.67 MHz
    .CLKIN(clk10m),       // wejście 10 MHz
    .RST(1'b0),
    .LOCKED(dcm_locked),
    .CLK0(), .CLK2X(), .CLK90(), .CLK180(), .CLK270(),
    .CLKDV(), .CLKFX180(), .STATUS(), .PSCLK(), .PSEN(), .PSINCDEC(), .PSDONE()
);

// Bufor globalny
BUFG bufg_clk106 (.I(clk106_int), .O(clk106m));


wire [10:0] h_counter; // 0-1055
wire [9:0] v_counter; // 0-627

wire [8:0] h_small; // 0-288
wire [7:0] v_small; // 0-180

// reg [1:0] mode; // 0 - disabled, 1 - graphic 1440x900, 2 - text 1440x900

(* ram_style="block" *) reg [5:0] vram [0:29999]; // 30kB VRAM

wire can_color;
vga_gen vga_timing (
    .clk(clk106m),
    .en(dcm_locked),
    .vsync(vsync_pin),
    .hsync(hsync_pin),
    .can_color(can_color),
    .h_counter(h_counter),
    .v_counter(v_counter),
    .h_small(h_small),
    .v_small(v_small)
);

assign led2 = 1;

reg [16:0] vram_index_render = 17'b0;
reg [5:0] pixel_out = 6'b0;

// always @(posedge clk106m) begin
//     if (h_counter < 200 && can_color && v_counter < 150) begin
//         vram_index_render <= vram_index_render + 1;
//         pixel_out <= vram[vram_index_render];
//     end else if(v_counter > 149) begin
//         vram_index_render <= 0;
//         pixel_out <= 6'b0;
//     end else begin
//         pixel_out <= 6'b0;
//     end

// end
//
always @(posedge clk106m) begin
    if (h_small < 200 && can_color && v_small < 150) begin
        // vram_index_render <= vram_index_render + 1;
        pixel_out <= vram[v_small*200+h_small];
    end else if(v_small > 149) begin
        vram_index_render <= 0;
        pixel_out <= 6'b0;
    end else begin
        pixel_out <= 6'b0;
    end

end



// assign {r1_pin,r0_pin,g1_pin,g0_pin,b1_pin,b0_pin} = pixel_out;

assign r0_pin = can_color & pixel_out[4];
assign r1_pin = can_color & pixel_out[5];
assign g0_pin = can_color & pixel_out[2];
assign g1_pin = can_color & pixel_out[3];
assign b0_pin = can_color & pixel_out[0];
assign b1_pin = can_color & pixel_out[1];


reg [14:0] vram_index = 29999;
wire rx_data_valid;
reg dataack_read = 1'b0;
wire [7:0] rx_byte;

uart_rx uart_rx_inst (
    .clk(clk106m),
    .rst(0),
    .rx(uart_rx),
    .data_ack(dataack_read),
    .data(rx_byte),
    .data_ready(rx_data_valid),
    .error()
);


always @(posedge clk106m) begin
    if (rx_data_valid == 1) begin
        vram[vram_index] <= rx_byte[5:0];
        dataack_read <= 1;

        if (vram_index == 29999)
            vram_index <= 0;
        else
            vram_index <= vram_index + 1;
        led1 <= ~led1;
    end
end



endmodule
