`timescale 1ns / 1ps


`include "timings/selected_timing.vh"


module mode_mux (
    input clk10m,
    input wire [2:0] mode,
    
    output wire vsync,
    output wire hsync,
    output reg r0,
    output reg r1,
    output reg g0,
    output reg g1,
    output reg b0,
    output reg b1,
    output wire [11:0] vcounter,

    output wire [7:0] user_data_out,
    input wire [7:0] user_data_in,
    input wire user_we,
    input wire [14:0] user_addr,
    input wire user_clk
);


reg [2:0] mode_dbuf = 3'd1; // Initialize to text mode


wire clk106_int;
wire clk106m;
wire dcm_locked;

//*32/3 for 1440x900 @60Hz
//*29/4 for 1280x720 @60Hz
//*13/2 for 1024x768 @60Hz
//*4/1 for 800x600 @60Hz

localparam CLK_DCM_MULTIPLY = `CLK_DCM_MULTIPLY;
localparam CLK_DCM_DIVIDE = `CLK_DCM_DIVIDE;


DCM_SP #(
    .CLKFX_MULTIPLY(CLK_DCM_MULTIPLY), 
    .CLKFX_DIVIDE(CLK_DCM_DIVIDE), 
    .CLKIN_PERIOD(100.0),     // T clk10m = 100 ns
    .CLK_FEEDBACK("NONE"),
    .STARTUP_WAIT("FALSE")
) dcm_sp_inst (
    .CLKFX(clk106_int),
    .CLKIN(clk10m),
    .RST(1'b0),
    .LOCKED(dcm_locked),
    .CLK0(), .CLK2X(), .CLK90(), .CLK180(), .CLK270(),
    .CLKDV(), .CLKFX180(), .STATUS(), .PSCLK(), .PSEN(), .PSINCDEC(), .PSDONE()
);

// Bufor globalny
BUFG bufg_clk106 (.I(clk106_int), .O(clk106m));


wire [11:0] h_counter; // 0-1055
wire [11:0] v_counter; // 0-627

assign vcounter = v_counter;


wire [7:0] vram_render_read;
reg [14:0] current_vram_read_addr;




wire can_color;


vram_24k vram (
    .render_data(vram_render_read),
    .render_addr(current_vram_read_addr),
    .render_clk(clk106m),

    .user_data_in(user_data_in),
    .user_data_out(user_data_out),
    .user_we(user_we),
    .user_addr(user_addr),
    .user_clk(user_clk)
);


wire r0_mode2, r1_mode2, g0_mode2, g1_mode2, b0_mode2, b1_mode2;
reg en_mode2;
wire [14:0] current_vram_read_addr_mode2;


wire r0_mode1, r1_mode1, g0_mode1, g1_mode1, b0_mode1, b1_mode1;
reg en_mode1;
wire [14:0] current_vram_read_addr_mode1;


reg vga_timing_en;
reg [7:0] side_pixels_remove;
reg [7:0] bottom_pixels_remove;


vga_gen vga_timing (
    .clk(clk106m),
    .en(vga_timing_en),
    .vsync(vsync),
    .hsync(hsync),
    .can_color(can_color),
    .h_counter(h_counter),
    .v_counter(v_counter),
    .side_pixels_remove(side_pixels_remove),
    .bottom_pixels_remove(bottom_pixels_remove)
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

localparam WHOLE_FRAME = `WHOLE_FRAME;
localparam VISIBLE_LINES = `VISIBLE_LINES;
localparam V_FRONT_PORCH = `V_FRONT_PORCH;
localparam V_SYNC_PULSE = `V_SYNC_PULSE;

// Switch mode in the middle of vsync pulse - safest moment for monitor
localparam V_SYNC_MIDDLE = VISIBLE_LINES + V_FRONT_PORCH + (V_SYNC_PULSE / 2);

always @(posedge clk106m) begin
    // Update mode in middle of vsync pulse when monitor is blanking
    if((h_counter == 0 && v_counter == V_SYNC_MIDDLE )|| mode_dbuf != 1 || mode_dbuf != 2) begin
        mode_dbuf <= mode;
    end
end

always @(*) begin
    // VGA timing always enabled when DCM is locked - prevents monitor from losing sync
    vga_timing_en = dcm_locked;
    
    case (mode_dbuf)
        1: begin
            r0 = r0_mode1;
            r1 = r1_mode1;
            g0 = g0_mode1;
            g1 = g1_mode1;
            b0 = b0_mode1;
            b1 = b1_mode1;
            current_vram_read_addr = current_vram_read_addr_mode1;
            en_mode1 = dcm_locked;
            en_mode2 = 1'b0;
            side_pixels_remove = `SIDE_PIXELS_BLACK_TEXT;
            bottom_pixels_remove = `BOTTOM_LINES_BLACK_TEXT;
        end
        2: begin
            r0 = r0_mode2;
            r1 = r1_mode2;
            g0 = g0_mode2;
            g1 = g1_mode2;
            b0 = b0_mode2;
            b1 = b1_mode2;
            current_vram_read_addr = current_vram_read_addr_mode2;
            en_mode2 = dcm_locked;
            en_mode1 = 1'b0;
            // 200x150 @ 5x scale = 1000x750 active pixels
            // side: (1024-1000)/2 = 12, topbottom: (768-750)/2 = 9
            // side_pixels_remove = 8'd12;
            side_pixels_remove = `SIDE_PIXELS_BLACK_GRAPHIC;
            bottom_pixels_remove = `BOTTOM_LINES_BLACK_GRAPHIC;
        end
        default: begin
            r0 = 1'b0;
            r1 = 1'b0;
            g0 = 1'b0;
            g1 = 1'b0;
            b0 = 1'b0;
            b1 = 1'b0;
            current_vram_read_addr = 15'b0;
            en_mode2 = 1'b0;
            en_mode1 = 1'b0;
            vga_timing_en = 0;
            side_pixels_remove = 8'd0;
            bottom_pixels_remove = 8'd0;
        end
    endcase
end

graphic_mode_6bitcolor mode_6bitcolor (
    .clk(clk106m), // input (to module)
    .r0(r0_mode2),
    .r1(r1_mode2),
    .g0(g0_mode2),
    .g1(g1_mode2),
    .b0(b0_mode2),
    .b1(b1_mode2),
    .en(en_mode2),
    .vram_render_read(vram_render_read), // input (to module)
    .current_vram_read_addr(current_vram_read_addr_mode2),
    .can_color(can_color), // input (to module)
    .h_counter(h_counter), // input (to module)
    .v_counter(v_counter) // input (to module)
);

text_mode mode_text (
    .clk(clk106m), // input (to module)
    .r0(r0_mode1),
    .r1(r1_mode1),
    .g0(g0_mode1),
    .g1(g1_mode1),
    .b0(b0_mode1),
    .b1(b1_mode1),
    .en(en_mode1),
    .can_color(can_color), // input (to module)
    .vram_render_read(vram_render_read), // input (to module)
    .current_vram_read_addr(current_vram_read_addr_mode1),
    .h_counter(h_counter), // input (to module)
    .v_counter(v_counter) // input (to module)
);



endmodule
