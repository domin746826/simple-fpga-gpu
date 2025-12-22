`include "timings/selected_timing.vh"

module vga_gen (
    input wire clk,
    input wire en,
    output wire vsync,
    output wire hsync,
    output wire can_color,

    output reg [11:0] h_counter = 12'b0, // 0-1904
    output reg [11:0] v_counter = 12'b0, // 0-932

    input wire [7:0] side_pixels_remove,
    input wire [7:0] bottom_pixels_remove
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


always @(posedge clk) begin
    if (!en) begin
            h_counter <= 0;
            v_counter <= 0;
    end else begin
        if(h_counter == WHOLE_LINE - 1) begin
            h_counter <= 12'b0;

            if(v_counter < WHOLE_FRAME - 1) begin
                v_counter <= v_counter + 1;
            end else begin
                v_counter <= 12'b0;
            end

        end else begin
            h_counter <= h_counter + 1;
        end
    end
end

// Line: disp -> fp -> sync -> bp

// Sync signals 
assign hsync = HSYNC_NEGATIVE ^ (h_counter >= (VISIBLE_AREA+FRONT_PORCH) && h_counter < (VISIBLE_AREA+FRONT_PORCH+SYNC_PULSE));
assign vsync = VSYNC_NEGATIVE ^ (v_counter >= (VISIBLE_LINES+V_FRONT_PORCH) && v_counter < (VISIBLE_LINES+V_FRONT_PORCH+V_SYNC_PULSE));

// Color area - centered within the fixed frame (black borders around smaller content)
assign can_color = h_counter >= side_pixels_remove && 
                   h_counter < (VISIBLE_AREA - side_pixels_remove) && 
                   v_counter < (VISIBLE_LINES - bottom_pixels_remove);

endmodule





