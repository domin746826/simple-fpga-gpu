module vram_24k (
    output reg [7:0] render_data,
    input wire [14:0] render_addr,
    input wire render_clk,

    input wire [7:0] user_data_in,
    output reg [7:0] user_data_out,
    input wire user_we,
    input wire [14:0] user_addr,
    input wire user_clk
);

(* ram_style="block" *) reg [7:0] mem [24575:0];

initial begin
    $readmemh("../vram_init.hex", mem);
end

always @(posedge render_clk) begin
    render_data <= mem[render_addr];
end

always @(posedge user_clk) begin
    user_data_out <= mem[user_addr];
    if(user_we) begin
        mem[user_addr] <=user_data_in;
    end
end

endmodule
