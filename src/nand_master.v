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
    input wire read_status_i,

    input wire [11:0] data_cnt,

    output reg done_o,
    output reg error_o,

    // master reads from here
    input wire fifo_read_data_rd_en,
    output wire [31:0] fifo_read_data_dout,
    output wire fifo_read_data_full,
    output wire fifo_read_data_empty,

    // master write to here
    input wire fifo_write_data_wr_en,
    input wire [31:0] fifo_write_data_din,
    output wire fifo_write_data_full,
    output wire fifo_write_data_empty,

    input wire [31:0] addr_input_0,
    input wire [31:0] addr_input_1,

    output reg [7:0] status_o
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

    reg [5:0] state;
    reg [31:0] value;
    reg [7:0] bit_cnt;
    reg [2:0] addr_cnt;
    reg [2:0] addr_toggle_cnt;
    reg [7:0] addr_reg [0:7];
    reg [11:0] data_toggle_cnt;

    localparam IDLE       = 5'd0,
                CMD_PRE    = 5'd1,
                CMD_WRITE  = 5'd2,
                CMD_POST   = 5'd3,
                ADDR_PRE   = 5'd4,
                ADDR_WRITE = 5'd5,
                ADDR_POST  = 5'd6,
                WAIT_READY = 5'd7,
                READ_DATA_PRE  = 5'd8,
                READ_DATA      = 5'd9,
                READ_DATA_POST = 5'd10,
                WRITE_DATA_FETCH_FROM_FIFO = 5'd11,
                WRITE_DATA_PRE = 5'd12,
                WRITE_DATA = 5'd13,
                WRITE_DATA_POST = 5'd14,
                READ_STATUS_PRE = 5'd15,
                READ_STATUS = 5'd16,
                READ_STATUS_POST = 5'd17,
                DONE            = 5'd18;

    localparam [7:0] NAND_RESET_CMD = 8'hFF;
    localparam [7:0] READ_PARAMETER_CMD = 8'hEC;
    localparam [7:0] READ_PARAMETER_ADDR = 8'h00;
    localparam [7:0] READ_PAGE_CMD0 = 8'h00;
    localparam [7:0] READ_PAGE_CMD1 = 8'h30;
    localparam [3:0] READ_PAGE_ADDR_CYCLE = 4'd4;
    localparam [7:0] ERASE_BLOCK_CMD0 = 8'h60;
    localparam [7:0] ERASE_BLOCK_CMD1 = 8'hD0;
    localparam [3:0] ERASE_BLOCK_ADDR_CYCLE = 4'd2;
    localparam [7:0] WRITE_PAGE_CMD0 = 8'h80;
    localparam [7:0] WRITE_PAGE_CMD1 = 8'h10;
    localparam [3:0] WRITE_PAGE_ADDR_CYCLE = 4'd4;
    localparam [7:0] READ_STATUS_CMD0 = 8'h70;

    wire fifo_read_data_wr;
    wire [31:0] fifo_read_data_din;
    reg fifo_latch_into_32bit;
    reg fifo_latch_into_32bit_ack;
    reg [1:0] cmd_count; // max 3 cmd count

    // for read page
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

    assign fifo_read_data_din = {24'b0, io_i};
    assign fifo_read_data_wr = (state == READ_DATA) && (bit_cnt == 8'd0) && clk_rise && !fifo_read_data_full;

    // for write page
    wire fifo_write_data_rd_en;
    wire [31:0] fifo_write_data_dout;

    reg [31:0] write_shift_reg;
    reg [1:0] write_byte_idx;
    reg fifo_rd_req;
    reg fifo_rd_req_set;
    reg fifo_rd_req_done;
    assign fifo_write_data_rd_en = fifo_rd_req;

    fifo u_fifo_read_data (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .wr_en(fifo_write_data_wr_en),
        .rd_en(fifo_write_data_rd_en),
        .din(fifo_write_data_din),
        .dout(fifo_write_data_dout),
        .full_o(fifo_write_data_full),
        .empty_o(fifo_write_data_empty)
    );

    reg [7:0] data_to_write [0:3];
    reg fetch_already;

    localparam FIFO_IDLE       = 4'd0,
                FIFO_RECEIVE_FETCH_SIGNAL    = 4'd1,
                FIFO_DEASSERT_READ_REQUEST   = 4'd2,
                FIFO_WRITE_INTO_DATA_TO_WRITE   = 4'd3,
                FIFO_WRITE_DONE   = 4'd4;

    reg [3:0] fifo_state;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            fifo_rd_req <= 1'b0;
            fifo_rd_req_done <= 1'b0;
            write_shift_reg <= 32'b0;
            fetch_already <= 1'b0;
            fifo_state <= FIFO_IDLE;
        end else begin
            case (fifo_state)
                FIFO_IDLE: begin
                    if (fifo_rd_req_set) begin
                        fifo_state <= FIFO_RECEIVE_FETCH_SIGNAL;
                    end
                end

                FIFO_RECEIVE_FETCH_SIGNAL: begin
                    fifo_rd_req <= 1'b1;
                    fifo_state <= FIFO_DEASSERT_READ_REQUEST;
                end

                FIFO_DEASSERT_READ_REQUEST: begin
                    fifo_rd_req <= 1'b0;
                    fifo_state <= FIFO_WRITE_INTO_DATA_TO_WRITE;
                end

                FIFO_WRITE_INTO_DATA_TO_WRITE: begin
                    data_to_write[0] <= fifo_write_data_dout[7:0];
                    data_to_write[1] <= fifo_write_data_dout[15:8];
                    data_to_write[2] <= fifo_write_data_dout[23:16];
                    data_to_write[3] <= fifo_write_data_dout[31:24];
                    fifo_state <= FIFO_WRITE_DONE;
                end

                FIFO_WRITE_DONE: begin
                    if (!fifo_rd_req_set) begin
                        // the main fsm should release this signals afterwards
                        fifo_state <= FIFO_IDLE;
                    end
                end

            endcase
        end
    end

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
            done_o <= 1'b0;
            error_o <= 1'b0;
            fifo_latch_into_32bit <= 1'b0;
            cmd_count <= 2'd0;
            data_toggle_cnt <= 12'd0;
            ce_n_o <= 1'b1;
            write_shift_reg <= 32'b0;
            write_byte_idx <= 2'd0;
            fifo_rd_req_set <= 1'b0;
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
                        cmd_count <= 2'd0;
                        data_toggle_cnt <= 12'd0;
                        ce_n_o <= 1'b0;

                        if (start_i) begin
                            state <= CMD_PRE;

                            if (rst_nand_i) begin
                                bit_cnt <= 8'd4;
                            end else if (read_param_i) begin
                                bit_cnt <= 8'd4;
                            end else if (read_page_i) begin
                                bit_cnt <= 8'd4;
                                addr_cnt <= READ_PAGE_ADDR_CYCLE; // 4 cycle address on my winbond flash
                                addr_reg[0] <= addr_input_0[7:0];
                                addr_reg[1] <= addr_input_0[15:8];
                                addr_reg[2] <= addr_input_0[23:16];
                                addr_reg[3] <= addr_input_0[31:24];
                            end else if (write_page_i) begin
                                bit_cnt <= 8'd4;
                                addr_cnt <= WRITE_PAGE_ADDR_CYCLE;
                                addr_reg[0] <= addr_input_0[7:0];
                                addr_reg[1] <= addr_input_0[15:8];
                                addr_reg[2] <= addr_input_0[23:16];
                                addr_reg[3] <= addr_input_0[31:24];
                            end else if (erase_block_i) begin
                                bit_cnt <= 8'd4;
                                addr_cnt <= ERASE_BLOCK_ADDR_CYCLE;
                                addr_reg[0] <= addr_input_0[7:0];
                                addr_reg[1] <= addr_input_0[15:8];
                            end else if (read_status_i) begin
                                bit_cnt <= 8'd4;
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
                        end else if (read_page_i) begin
                            if (cmd_count == 2'd0) begin
                                io_o <= READ_PAGE_CMD0;
                            end else if (cmd_count == 2'd1) begin
                                io_o <= READ_PAGE_CMD1;
                            end
                        end else if (write_page_i) begin
                            if (cmd_count == 2'd0) begin
                                io_o <= WRITE_PAGE_CMD0;
                            end else if (cmd_count == 2'd1) begin
                                io_o <= WRITE_PAGE_CMD1;
                            end
                        end else if (erase_block_i) begin
                            if (cmd_count == 2'd0) begin
                                io_o <= ERASE_BLOCK_CMD0;
                            end else if (cmd_count == 2'd1) begin
                                io_o <= ERASE_BLOCK_CMD1;
                            end
                        end else if (read_status_i) begin
                            io_o <= READ_STATUS_CMD0;
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
                            end else if (read_page_i) begin
                                cmd_count <= cmd_count + 2'd1; // shift out second command at the second round
                                if (addr_toggle_cnt == addr_cnt - 1) begin
                                    // means previously already shifted out address
                                    state <= WAIT_READY;
                                end else begin
                                    state <= ADDR_PRE;
                                end
                            end else if (write_page_i) begin
                                cmd_count <= cmd_count + 2'd1; // shift out second command at the second round
                                if (addr_toggle_cnt == addr_cnt - 1) begin
                                    // means previously already shifted out address
                                    state <= WAIT_READY;
                                end else begin
                                    state <= ADDR_PRE;
                                end
                            end else if (erase_block_i) begin
                                cmd_count <= cmd_count + 2'd1;
                                if (addr_toggle_cnt == addr_cnt - 1) begin
                                    // means previously already shifted out address
                                    state <= WAIT_READY;
                                end else begin
                                    state <= ADDR_PRE;
                                end
                            end else if (read_status_i) begin
                                state <= WAIT_READY;
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
                                end else if (read_page_i) begin
                                    if (cmd_count == 2'd2) begin
                                        state <= WAIT_READY;
                                    end else if (cmd_count == 2'b1) begin
                                        state <= CMD_PRE;
                                    end
                                end else if (write_page_i) begin
                                    state <= WRITE_DATA_FETCH_FROM_FIFO;
                                    bit_cnt <= 8'd4;
                                end else if (erase_block_i) begin
                                    if (cmd_count == 2'd2) begin
                                        state <= WAIT_READY;
                                    end else if (cmd_count == 2'b1) begin
                                        state <= CMD_PRE;
                                    end
                                end

                            end else begin
                                addr_toggle_cnt <= addr_toggle_cnt + 1;
                                state <= ADDR_PRE;
                                bit_cnt <= 8'd4;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    WAIT_READY: begin
                        if (bit_cnt == 8'd0) begin
                            if (rb_i) begin
                                if (erase_block_i) begin
                                    state <= DONE;
                                end else if (read_status_i) begin
                                    bit_cnt <= 8'd4;
                                    state <= READ_STATUS_PRE;
                                end else begin
                                    state <= READ_DATA_PRE;
                                    bit_cnt <= 8'd4;
                                end
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
                            if (data_toggle_cnt == data_cnt - 1) begin
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

                    WRITE_DATA_FETCH_FROM_FIFO: begin
                        if (data_toggle_cnt[1:0] == 2'b0) begin
                            // fifo latch out every four cycle
                            fifo_rd_req_set <= 1'b1;
                        end
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= WRITE_DATA_PRE;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    WRITE_DATA_PRE: begin
                        fifo_rd_req_set <= 1'b0;
                        oe_o <= 1'b1; // output now
                        io_o <= data_to_write[data_toggle_cnt[1:0]];

                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= WRITE_DATA;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    WRITE_DATA: begin
                        we_n_o <= 1'b0;

                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= WRITE_DATA_POST;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    WRITE_DATA_POST: begin
                        we_n_o <= 1'b1;

                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            if (data_toggle_cnt == data_cnt - 1) begin
                                state <= DONE;
                            end else if ((data_toggle_cnt[1:0] == 2'b11) && fifo_write_data_empty) begin
                                // wait for master to transfer data in, write havent complete

                            end else begin
                                data_toggle_cnt <= data_toggle_cnt + 1;
                                state <= WRITE_DATA_FETCH_FROM_FIFO;
                                bit_cnt <= 8'd4;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    READ_STATUS_PRE: begin
                        re_n_o <= 1'b1;
                        if (bit_cnt == 8'd0) begin
                            bit_cnt <= 8'd4;
                            state <= READ_STATUS;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                        end
                    end

                    READ_STATUS: begin
                        oe_o <= 1'b0;
                        status_o <= io_i;
                        state <= READ_STATUS_POST;
                    end

                    READ_STATUS_POST: begin
                        re_n_o <= 1'b0;
                        state <= DONE;
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
 