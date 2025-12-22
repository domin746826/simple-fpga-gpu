`timescale 1ns / 1ps

`include "../timings/selected_timing.vh"




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

localparam SMALL_COUNT_TO = `SMALL_COUNT_TO;
localparam VISIBLE_AREA  = `VISIBLE_AREA;
localparam FRONT_PORCH   = `FRONT_PORCH;
localparam SYNC_PULSE    = `SYNC_PULSE;
localparam BACK_PORCH    = `BACK_PORCH;
localparam WHOLE_LINE    = `WHOLE_LINE;

localparam VISIBLE_LINES = `VISIBLE_LINES;
localparam V_FRONT_PORCH = `V_FRONT_PORCH;
localparam V_SYNC_PULSE  = `V_SYNC_PULSE;
localparam V_BACK_PORCH  = `V_BACK_PORCH;
localparam WHOLE_FRAME   = `WHOLE_FRAME;

localparam HSYNC_NEGATIVE = `HSYNC_NEGATIVE;
localparam VSYNC_NEGATIVE = `VSYNC_NEGATIVE;


reg [5:0] pixel_out;// = 6'b0;
(* keep = "true" *) reg [7:0] old_vram_byte = 8'b0; // bits [7:6] intentionally unused in pixel unpacking
reg [1:0] small_vram_index = 0;
reg [2:0] h_small = SMALL_COUNT_TO;
reg [2:0] v_small = 0;

always @(posedge clk) begin
    if (!en) begin
        current_vram_read_addr <= 0;
        h_small <= SMALL_COUNT_TO;
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
            if(h_small == SMALL_COUNT_TO) begin
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

        if(h_counter == WHOLE_LINE-4) begin
            h_small <= SMALL_COUNT_TO;
            small_vram_index <= 0;

            if(v_counter == WHOLE_FRAME-1) begin
                current_vram_read_addr <= 0;
                v_small <= 0;
            end else begin
                if(v_small == SMALL_COUNT_TO) begin
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
