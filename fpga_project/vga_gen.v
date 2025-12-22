module vga_gen (
    input wire clk,
    input wire en,
    output wire vsync,
    output wire hsync,
    output wire can_color,

    output reg [11:0] h_counter = 12'b0, // 0-1904
    output reg [11:0] v_counter = 12'b0, // 0-932

    input wire [7:0] side_pixels_remove,
    input wire [7:0] topbottom_pixels_remove
);


// 800x600 @60Hz timing parameters
// localparam SIDE_PIXELS_REMOVE = 0;
// localparam VISIBLE_AREA = 800; // 1200
// localparam FRONT_PORCH = 40;
// localparam SYNC_PULSE = 128;
// localparam BACK_PORCH = 88;
// localparam WHOLE_LINE = VISIBLE_AREA + FRONT_PORCH + SYNC_PULSE + BACK_PORCH; // 1056

// localparam VISIBLE_LINES = 600; // 600 + 1 + 4 + 23
// localparam V_FRONT_PORCH = 1;
// localparam V_SYNC_PULSE = 4;
// localparam V_BACK_PORCH = 23;
// localparam WHOLE_FRAME = VISIBLE_LINES + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 628

// localparam HSYNC_NEGATIVE = 0;
// localparam VSYNC_NEGATIVE = 0;


// 1440x900 @60Hz timing parameters
localparam SIDE_PIXELS_REMOVE = 120;
localparam VISIBLE_AREA = 1440; // 1200
localparam FRONT_PORCH = 80;
localparam SYNC_PULSE = 152;
localparam BACK_PORCH = 232;
localparam WHOLE_LINE = VISIBLE_AREA + FRONT_PORCH + SYNC_PULSE + BACK_PORCH; // 1904

localparam VISIBLE_LINES = 900; // 900 + 3 + 4 + 25
localparam V_FRONT_PORCH = 1;
localparam V_SYNC_PULSE = 3;
localparam V_BACK_PORCH = 28;
localparam WHOLE_FRAME = VISIBLE_LINES + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH; // 932

localparam HSYNC_NEGATIVE = 1;
localparam VSYNC_NEGATIVE = 0;

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


assign hsync = HSYNC_NEGATIVE ^ (h_counter >= (VISIBLE_AREA+FRONT_PORCH-side_pixels_remove) && h_counter < (VISIBLE_AREA+FRONT_PORCH+SYNC_PULSE-side_pixels_remove));
assign vsync = VSYNC_NEGATIVE ^ (v_counter >= (VISIBLE_LINES+V_FRONT_PORCH-topbottom_pixels_remove) && v_counter < (VISIBLE_LINES+V_FRONT_PORCH+V_SYNC_PULSE-topbottom_pixels_remove));
assign can_color = h_counter < VISIBLE_AREA-2*side_pixels_remove && v_counter < VISIBLE_LINES - 2*topbottom_pixels_remove;

endmodule





