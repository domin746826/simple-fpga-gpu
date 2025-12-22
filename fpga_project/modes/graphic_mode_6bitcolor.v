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

module graphic_mode_6bitcolor (
    output reg r0,
    output reg r1,
    output reg g0,
    output reg g1,
    output reg b0,
    output reg b1,
    input wire en,
    input wire [7:0] vram_render_read,
    output reg [14:0] current_vram_read_addr = 0,
    input wire can_color,
    input wire clk,
    input wire [11:0] h_counter,
    input wire [11:0] v_counter
);



// 1440x900 @60Hz timing parameters
localparam small_count_to = 5;
localparam whole_line = 1904;
localparam whole_frame = 932;

// localparam small_count_to = 3;
// localparam whole_line = 1056;
// localparam whole_frame = 628;

reg [5:0] pixel_out;// = 6'b0;
reg [7:0] old_vram_byte = 8'b0;
reg [1:0] small_vram_index = 0;
reg [2:0] h_small = small_count_to;
reg [2:0] v_small = 0;

always @(posedge clk) begin
    if (!en) begin
        current_vram_read_addr <= 0;
        h_small <= small_count_to;
        v_small <= 0;
        small_vram_index <= 0;
        r0 <= 0;
        r1 <= 0;
        g0 <= 0;
        g1 <= 0;
        b0 <= 0;
        b1 <= 0;
    end else begin
        if (can_color) begin
            if(h_small == small_count_to) begin
                h_small <= 0;
                case (small_vram_index)
                    0: begin
                        current_vram_read_addr <= current_vram_read_addr + 1;
                        old_vram_byte <= vram_render_read;
                    end
                    1: begin
                        current_vram_read_addr <= current_vram_read_addr + 1;
                        old_vram_byte <= vram_render_read;
                    end
                    2: begin
                        current_vram_read_addr <= current_vram_read_addr + 1;
                        old_vram_byte <= vram_render_read;
                    end
                    3: begin
                    end
                endcase
                small_vram_index <= small_vram_index + 1;
                r0 <= pixel_out[4];
                r1 <= pixel_out[5];
                g0 <= pixel_out[2];
                g1 <= pixel_out[3];
                b0 <= pixel_out[0];
                b1 <= pixel_out[1];

            end else begin
                h_small <= h_small + 1;
            end
        end else begin
            r0 <= 0;
            r1 <= 0;
            g0 <= 0;
            g1 <= 0;
            b0 <= 0;
            b1 <= 0;
        end

        if(h_counter == whole_line-4) begin
            h_small <= small_count_to;
            small_vram_index <= 0;

            if(v_counter == whole_frame-1) begin
                current_vram_read_addr <= 0;
                v_small <= 0;
            end else begin
                if(v_small == small_count_to) begin
                    v_small <= 0;
                end else begin
                    v_small <= v_small + 1;
                    current_vram_read_addr <= current_vram_read_addr - 150;
                end
            end
        end
    end
end

// unpack 4 pixels from 3 bytes
always @(*) begin
case (small_vram_index)
    0: begin
        pixel_out = {vram_render_read[7:2]};
    end
    1: begin
        pixel_out = {old_vram_byte[1:0], vram_render_read[7:4]};
    end
    2: begin
        pixel_out = {old_vram_byte[3:0], vram_render_read[7:6]};
    end
    3: begin
        pixel_out = {old_vram_byte[5:0]};
    end
endcase
end


endmodule
