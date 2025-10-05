module vga_gen (
    input wire clk,
    input wire en,
    output wire vsync,
    output wire hsync,
    output wire can_color,

    output reg [10:0] h_counter = 11'b0, // 0-1055
    output reg [9:0] v_counter = 10'b0, // 0-627

    output reg [8:0] h_small = 9'b0, // 0-288
    output reg [7:0] v_small = 8'b0 // 0-180
);


reg [3:0] h_div = 4'b0;
reg [3:0] v_div = 4'b0;

always @(posedge clk) begin
    if (!en) begin
            h_counter <= 0;
            v_counter <= 0;
            h_small <= 0;
            v_small <= 0;
            h_div <= 0;
            v_div <= 0;
    end else begin
        if(h_counter == 1904) begin
            h_counter <= 11'b0;
            h_small <= 0;
            h_div <= 0;

            if(v_counter < 932) begin
                v_counter <= v_counter + 1;
                if(v_div >= 5) begin
                    v_div <= 0;
                    v_small <= v_small + 1;
                end else begin
                    v_div <= v_div + 1;
                end
            end else begin
                v_counter <= 10'b0;
                v_small <= 0;
                v_div <= 0;
            end

        end else begin
            h_counter <= h_counter + 1;
            if(h_div >= 5) begin
                h_div <= 0;
                h_small <= h_small + 1;
            end else begin
                h_div <= h_div + 1;
            end

        end
    end

end

// disp -> fp -> sync -> bp

assign hsync = ~(h_counter >= 1520 - 120 && h_counter < 1627-120); // move 120px to the right so graphic mode image is on the center, TODO remove it
assign vsync = v_counter >= 901 && v_counter < 904;
assign can_color = h_counter < 1440 && v_counter < 900;


endmodule
