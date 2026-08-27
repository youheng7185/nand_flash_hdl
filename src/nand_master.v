/*



*/

module nand_master (
    input wire clk_i,
    input wire rst_n,

    input wire [7:0] io_i,
    output reg [7:0] io_o,
    output reg oe_o, // 1 for output
    
    output reg ce_n_o,

    output reg cle_o,
    output reg ale_o,
    output reg re_n_o,
    output reg we_n_o,
    input wire rb_i,

    input wire start_i,
    input wire rst_nand_i,
    input wire read_param_i,
    input wire read_page_i,
    input wire write_page_i,
    input wire erase_block_i,

    input wire [11:0] data_cnt,

    output reg done_o,
    output reg error_o,

    input wire fifo_read_data_rd_en,
    output wire [31:0] fifo_read_data_dout,
    output wire fifo_read_data_full,
    output wire fifo_read_data_empty
);

    parameter DIV = 10; // input 50mhz, output 2.5mhz

    reg [7:0] clk_divider_counter;
    reg clk_rise;
    reg clk_fall;
    reg clk_o;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider_counter <= 8'd0;
            clk_rise <= 1'b0;
            clk_fall <= 1'b0;
            clk_o <= 1'b0;
        end else begin
            // default values
            clk_rise <= 1'b0;
            clk_fall <= 1'b0;

            if (clk_divider_counter == DIV - 1) begin
                clk_divider_counter <= 8'b0;
                clk_o <= ~clk_o;
                if (!clk_o) begin
                    // clk is low previously, now high, so its rising edge
                    clk_rise <= 1'b1;
                end else begin
                    clk_fall <= 1'b1;
                end
            end else begin
                clk_divider_counter <= clk_divider_counter + 1;
            end
        end
    end

    reg [3:0] state;
    reg [31:0] value;
    reg [7:0] bit_cnt;
    reg [2:0] addr_cnt;
    reg [2:0] addr_toggle_cnt;
    reg [7:0] addr_reg [0:7];
    reg [11:0] data_toggle_cnt;

    localparam IDLE       = 4'd0,
                CMD_PRE    = 4'd1,
                CMD_WRITE  = 4'd2,
                CMD_POST   = 4'd3,
                ADDR_PRE   = 4'd4,
                ADDR_WRITE = 4'd5,
                ADDR_POST  = 4'd6,
                WAIT_READY = 4'd7,
                READ_DATA_PRE  = 4'd8,
                READ_DATA      = 4'd9,
                READ_DATA_POST = 4'd10,
                DONE            = 4'd11;

    localparam [7:0] NAND_RESET_CMD = 8'hFF;
    localparam [7:0] READ_PARAMETER_CMD = 8'hEC;
    localparam [7:0] READ_PARAMETER_ADDR = 8'h00;

    wire fifo_read_data_wr;
    reg [31:0] fifo_read_data_din;
    reg [7:0] fifo_read_data_din_temp;
    reg fifo_latch_into_32bit;
    reg fifo_latch_into_32bit_ack;

    fifo u_fifo_write_data (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .wr_en(fifo_read_data_wr),
        .rd_en(fifo_read_data_rd_en),
        .din(fifo_read_data_din),
        .dout(fifo_read_data_dout),
        .full_o(fifo_read_data_full),
        .empty_o(fifo_read_data_empty)
    );

    assign fifo_read_data_wr = (state == READ_DATA) && (bit_cnt == 8'b0) && clk_rise && !fifo_read_data_full;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cle_o <= 1'b0;
            ale_o <= 1'b0;
            we_n_o <= 1'b1;
            re_n_o <= 1'b1;
            io_o <= 8'b0;
            oe_o <= 1'b1;
            addr_cnt <= 3'b0;
            addr_toggle_cnt <= 3'b0;
            fifo_read_data_din <= 32'd0;
            done_o <= 1'b0;
            error_o <= 1'b0;
            fifo_latch_into_32bit <= 1'b0;
        end else begin
            if (clk_rise) begin
                case (state) 
                    IDLE: begin
                        cle_o <= 1'b0;
                        ale_o <= 1'b0;
                        we_n_o <= 1'b1;
                        re_n_o <= 1'b1;                    
                        io_o <= 8'b0;
                        oe_o <= 1'b0; // set as input
                        addr_cnt <= 3'b0;
                        addr_toggle_cnt <= 3'b0;

                        if (start_i) begin
                            if (rst_nand_i) begin
                                state <= CMD_PRE;
                                bit_cnt <= 8'd4;
                            end else if (read_param_i) begin
                                state <= CMD_PRE;
                                bit_cnt <= 8'd4;
                            end else if (read_page_i) begin
                                
                            end else if (write_page_i) begin
                                
                            end else if (erase_block_i) begin
                                
                            end
                        end
                    end

                    CMD_PRE: begin
                        oe_o <= 1'b1;
                        cle_o <= 1'b1;
                        if (rst_nand_i) begin
                            io_o <= NAND_RESET_CMD;
                        end else if (read_param_i) begin
                            io_o <= READ_PARAMETER_CMD;
                        end
                        
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= CMD_WRITE;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    CMD_WRITE: begin
                        we_n_o <= 1'b0;
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= CMD_POST;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    CMD_POST: begin
                        we_n_o <= 1'b1;
                        cle_o <= 1'b0;
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            if (rst_nand_i) begin
                                state <= DONE;
                            end else if (read_param_i) begin
                                addr_cnt <= 3'b1;
                                addr_reg[0] <= READ_PARAMETER_ADDR;
                                state <= ADDR_PRE;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    ADDR_PRE: begin
                        ale_o <= 1'b1;
                        io_o <= addr_reg[addr_toggle_cnt];
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= ADDR_WRITE;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    ADDR_WRITE: begin
                        we_n_o <= 1'b0;
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= ADDR_POST;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    ADDR_POST: begin
                        we_n_o <= 1'b1;
                        ale_o <= 1'b0;

                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            if (addr_toggle_cnt == addr_cnt - 1) begin
                                if (read_param_i) begin
                                    state <= WAIT_READY;
                                    bit_cnt <= 8'd4;
                                    data_toggle_cnt <= 12'd0;
                                end

                            end else begin
                                addr_toggle_cnt <= addr_toggle_cnt + 1;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    WAIT_READY: begin
                        if (bit_cnt == 8'd0) begin
                            if (rb_i) begin
                                state <= READ_DATA_PRE;
                                bit_cnt <= 8'd4;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    READ_DATA_PRE: begin
                        re_n_o <= 1'b0;
                        oe_o <= 1'b0; // input now
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= READ_DATA;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    READ_DATA: begin
                        re_n_o <= 1'b0;
                        if (bit_cnt == 8'd0) begin
                            if (!fifo_read_data_full) begin
                                //fifo_read_data_din_temp <= io_i;
                                fifo_read_data_din <= {24'b0, io_i};
                                bit_cnt <= 8'd4;
                                state <= READ_DATA_POST;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    READ_DATA_POST: begin
                        re_n_o <= 1'b1;
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            if (data_toggle_cnt == data_cnt) begin
                                state <= DONE;
                            end else begin
                                data_toggle_cnt <= data_toggle_cnt + 1;
                                state <= READ_DATA_PRE;
                                bit_cnt <= 8'd4;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    DONE: begin
                        done_o <= 1'b1;
                        if (!start_i) begin
                            done_o <= 1'b0;
                            state <= IDLE;
                        end
                    end

                    default: begin
                        $display("shouldnt run until here\n");
                    end
                endcase
            end
        end
    end

endmodule
