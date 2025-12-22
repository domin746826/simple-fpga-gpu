`timescale 1ns / 1ps

`include "../timings/selected_timing.vh"

// Text mode with hardcoded 16-color palette (4-bit per foreground/background)
// Palette mapping (index -> RGB):
//  0: Black        (000000)    8: Dark Gray    (555555)
//  1: Blue         (0000AA)    9: Light Blue   (5555FF)
//  2: Green        (00AA00)   10: Light Green  (55FF55)
//  3: Cyan         (00AAAA)   11: Light Cyan   (55FFFF)
//  4: Red          (AA0000)   12: Light Red    (FF5555)
//  5: Magenta      (AA00AA)   13: Light Magenta(FF55FF)
//  6: Brown/Yellow (AA5500)   14: Yellow       (FFFF55)
//  7: Light Gray   (AAAAAA)   15: White        (FFFFFF)
// Color code format: 0bFFFFBBBB (F=foreground, B=background)

module text_mode (
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
    // can_color removed - not used in text mode
    input wire clk,
    input wire [11:0] h_counter,
    input wire [11:0] v_counter
);

// Timing parameters from include
localparam VISIBLE_AREA  = `VISIBLE_AREA;
localparam WHOLE_LINE    = `WHOLE_LINE;
localparam VISIBLE_LINES = `VISIBLE_LINES;
localparam WHOLE_FRAME   = `WHOLE_FRAME;

localparam TEXT_COLS = `TEXT_COLS;
localparam TEXT_ROWS = `TEXT_ROWS;

// Text mode parameters (8x16 font)
localparam TEXT_AREA_SIZE = TEXT_COLS*TEXT_ROWS;
localparam COLOR_AREA_OFFSET = TEXT_AREA_SIZE;
localparam FONT_AREA_OFFSET = TEXT_AREA_SIZE*2;

// Prefetch timing
localparam H_PREFETCH_START = WHOLE_LINE - 9;  // start prefetch 8 cycles before line end
localparam V_LAST_LINE = WHOLE_FRAME - 1;

// Hardcoded 16-color palette (6-bit RGB: 2 bits per channel)
// Format: {R1,R0,G1,G0,B1,B0}
// Using function for ROM-style palette lookup
function [5:0] get_palette_color;
    input [3:0] index;
    begin
        case (index)
            4'd0:  get_palette_color = 6'b00_00_00; // Black
            4'd1:  get_palette_color = 6'b00_00_10; // Blue
            4'd2:  get_palette_color = 6'b00_10_00; // Green
            4'd3:  get_palette_color = 6'b00_10_10; // Cyan
            4'd4:  get_palette_color = 6'b10_00_00; // Red
            4'd5:  get_palette_color = 6'b10_00_10; // Magenta
            4'd6:  get_palette_color = 6'b10_01_00; // Orange
            4'd7:  get_palette_color = 6'b01_01_01; // Dark Gray
            4'd8:  get_palette_color = 6'b10_10_10; // Light Gray
            4'd9:  get_palette_color = 6'b01_01_11; // Light Blue
            4'd10: get_palette_color = 6'b01_11_01; // Light Green
            4'd11: get_palette_color = 6'b01_11_11; // Light Cyan
            4'd12: get_palette_color = 6'b11_01_01; // Light Red
            4'd13: get_palette_color = 6'b11_01_11; // Light Magenta
            4'd14: get_palette_color = 6'b11_11_01; // Yellow
            4'd15: get_palette_color = 6'b11_11_11; // White
        endcase
    end
endfunction

reg [7:0] h_text_pos = 0; // current rendered char x pos
reg [14:0] v_text_pos = 0; // current rendered char y pos


reg [7:0] ascii_code = 0;  // current rendered char fetched ascii code
reg [7:0] color_code = 0; // 0bffffbbbb current rendered char fetched color code

reg [2:0] font_render_cycle = 0;// current rendered char h pixel (0-7)
reg [3:0] font_v_line = 0; // current rendered char line (0-15)

reg [5:0] pixel_out;// = 6'b0;
reg [7:0] font_onerow_data = 0;
reg [7:0] color_code_dbuf = 0;

always @(posedge clk) begin
    if(!en) begin
        font_render_cycle <= 0;
        h_text_pos <= 0;
        font_onerow_data <= 0;
        color_code <= 0;
        h_text_pos <= 0;
        current_vram_read_addr <= 0;
    end else begin
        // if in visible area or in last 1 char column of vblank (prefetch)
        if((h_counter < VISIBLE_AREA || h_counter > H_PREFETCH_START) && (v_counter < VISIBLE_LINES || v_counter == V_LAST_LINE)) begin
            case (font_render_cycle)
                0: begin
                    current_vram_read_addr <= h_text_pos + v_text_pos; // address of ascii code
                end
                1: begin end
                2: begin
                    ascii_code <= vram_render_read; // fetch ascii code
                    current_vram_read_addr <= current_vram_read_addr + COLOR_AREA_OFFSET; // address of color code
                end
                3: begin end
                4: begin
                    color_code_dbuf <= vram_render_read; // fetch color code
                    current_vram_read_addr <= FONT_AREA_OFFSET + ascii_code * 16 + font_v_line; // address of font data
                end
                5: begin end
                6: begin end
                7: begin
                    font_onerow_data <= vram_render_read; // fetch font data
                    color_code <= color_code_dbuf; // buffer color code
                    h_text_pos <= h_text_pos + 1; // next character
                end
            endcase
            font_render_cycle <= font_render_cycle + 1;
        end else begin // outside visible/work area
            font_render_cycle <= 0;
            h_text_pos <= 0;
            font_onerow_data <= 0;
            color_code <= 0;
            h_text_pos <= 0;
        end


        // adding 1 below to h_counter to compensate pipeline delay of 1 cycle
        if (h_counter < VISIBLE_AREA+1 && v_counter < VISIBLE_LINES) begin // visible area, rendering font
            

            r0 <= pixel_out[4] & can_color;
            r1 <= pixel_out[5] & can_color;
            g0 <= pixel_out[2] & can_color;
            g1 <= pixel_out[3] & can_color;
            b0 <= pixel_out[0] & can_color;
            b1 <= pixel_out[1] & can_color;

        end else begin // outside visible area, output black
            r0 <= 0;
            r1 <= 0;
            g0 <= 0;
            g1 <= 0;
            b0 <= 0;
            b1 <= 0;
        end
        
        if(font_onerow_data[~font_render_cycle]) begin // foreground or background?
            pixel_out <= get_palette_color(color_code[7:4]); // foreground color from palette
        end else begin
            pixel_out <= get_palette_color(color_code[3:0]); // background color from palette
        end

        if(h_counter == WHOLE_LINE - 12) begin // update font_v_line before prefetch uses it

            if(v_counter == V_LAST_LINE) begin
                font_v_line <= 0;
                v_text_pos <= 0;
                
            end else begin
                if(font_v_line == 15) begin
                    v_text_pos <= v_text_pos + TEXT_COLS;
                end
                font_v_line <= font_v_line + 1;
            end
        end
    end
end


endmodule
