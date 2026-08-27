module fifo (
    input wire clk_i,
    input wire rst_n,
    input wire wr_en,
    input wire rd_en,
    input wire [31:0] din,
    output reg [31:0] dout,
    output wire full_o,
    output wire empty_o
);

    // depth set 64, so total 256 bytes fifo

    reg [5:0] wptr;
    reg [5:0] rptr;

    reg [31:0] fifo_mem [64];

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            wptr <= 0;
        end else begin
            if (wr_en && !full_o) begin
                fifo_mem[wptr] <= din;
                wptr <= wptr + 1;
            end
        end
    end

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            rptr <= 0;
        end else begin
            if (rd_en & !empty_o) begin
                dout <= fifo_mem[rptr];
                rptr <= rptr + 1;
            end
        end
    end

    assign full_o = (wptr + 1) == rptr;
    assign empty_o = wptr == rptr;

endmodule
