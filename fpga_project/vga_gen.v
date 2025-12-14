module vga_gen (
    input wire clk,
    input wire en,
    output wire vsync,
    output wire hsync,
    output wire can_color,

    output reg [10:0] h_counter = 11'b0, // 0-1904
    output reg [9:0] v_counter = 10'b0 // 0-932
);

always @(posedge clk) begin
    if (!en) begin
            h_counter <= 0;
            v_counter <= 0;
    end else begin
        if(h_counter == 1903) begin
            h_counter <= 11'b0;

            if(v_counter < 931) begin
                v_counter <= v_counter + 1;
            end else begin
                v_counter <= 10'b0;
            end

        end else begin
            h_counter <= h_counter + 1;
        end
    end

end

// disp -> fp -> sync -> bp

// move 120px to the right so graphic mode image is on the center, TODO remove it
assign hsync = ~(h_counter >= 1520 - 120 && h_counter < 1627-120);
// assign hsync = ~(h_counter >= 1520 && h_counter < 1627);

assign vsync = v_counter >= 901 && v_counter < 904;
assign can_color = h_counter < 1440 -240 && v_counter < 900;
// assign can_color = h_counter < 1440  && v_counter < 900;


endmodule
