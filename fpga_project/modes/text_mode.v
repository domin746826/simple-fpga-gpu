`timescale 1ns / 1ps


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
    input wire clk,
    input wire [11:0] h_counter,
    input wire [11:0] v_counter
);



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
        if((h_counter < 1440 || h_counter > 1895)&& (v_counter < 896 || v_counter == 931)) begin
            case (font_render_cycle)
                0: begin
                    current_vram_read_addr <= h_text_pos + v_text_pos; // address of ascii code
                end
                1: begin end
                2: begin
                    ascii_code <= vram_render_read; // fetch ascii code
                    current_vram_read_addr <= current_vram_read_addr + 10080; // address of color code
                end
                3: begin end
                4: begin
                    color_code_dbuf <= vram_render_read; // fetch color code
                    current_vram_read_addr <= 20160 + ascii_code * 16 + font_v_line; // address of font data
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
        if (h_counter < 1440  && v_counter < 896) begin // visible area, rendering font
            if(font_onerow_data[~font_render_cycle]) begin // foreground or background?
                pixel_out <= {color_code[6], color_code[7], color_code[5], color_code[7], color_code[4], color_code[7]}; // mapping 4 bit color to 6 bit color
            end else begin
                pixel_out <= {color_code[2], color_code[3], color_code[1], color_code[3], color_code[0], color_code[3]};
            end

            r0 <= pixel_out[4];
            r1 <= pixel_out[5];
            g0 <= pixel_out[2];
            g1 <= pixel_out[3];
            b0 <= pixel_out[0];
            b1 <= pixel_out[1];

        end else begin // outside visible area, output black
            r0 <= 0;
            r1 <= 0;
            g0 <= 0;
            g1 <= 0;
            b0 <= 0;
            b1 <= 0;
        end
        

        if(h_counter == 1860) begin // end of line

            if(v_counter == 931) begin
                font_v_line <= 0;
                v_text_pos <= 0;
                
            end else begin
                if(font_v_line == 15) begin
                    v_text_pos <= v_text_pos + 180;
                end
                font_v_line <= font_v_line + 1;
            end
        end
    end
end


endmodule
