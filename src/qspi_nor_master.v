module qspi_nor_master (
    input wire clk_i,
    input wire rst_n,

    output reg cs_n_o,
    input wire di_i,
    output reg do_o,
    output wire spi_clk_o,

    input wire start_i,
    output reg done_o,

    input wire [7:0] instr_i,
    input wire rd_wr_i, // 1 for read, 0 for write
    input wire [4:0] dummy_cnt_i,
    input wire [1:0] data_mode_i, // 00 for not sending data, 01 to send data based on data_cnt_i
    input wire [7:0] data_cnt_i, // write 0 for 1 byte to send
    input wire data_dir_i, // data direction, 0 to read from flash, 1 to write to flash

    input wire [31:0] addr_i, // 4 byte or 3 byte addr
    
    // tx out to master
    input wire tx_fifo_rd_en,
    output wire [31:0] tx_fifo_data_dout,
    output wire tx_fifo_data_full,
    output wire tx_fifo_data_empty,

    // rx from master
    input wire rx_fifo_data_wr_en,
    input wire [31:0] rx_fifo_data_din,
    output wire rx_fifo_data_full,
    output wire rx_fifo_data_empty
);

    // parameter DIV = 10; // input 50mhz, output 2.5mhz
    parameter DIV = 2;

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

    reg fifo_data_wr_en;
    reg [31:0] fifo_data_wr;

    // master reading this, controller writes to here, NAND controller -> master
    fifo u_tx_fifo (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .wr_en(fifo_data_wr_en),
        .rd_en(tx_fifo_rd_en),
        .din(fifo_data_wr),
        .dout(tx_fifo_data_dout),
        .full_o(tx_fifo_data_full),
        .empty_o(tx_fifo_data_empty)
    );
    
    reg fifo_data_rd_en;
    reg [31:0] fifo_data_rd;

    // controller reading this, master writes to here, master -> NAND controller
    fifo u_rx_fifo (
        .clk_i(clk_i),
        .rst_n(rst_n),
        .wr_en(rx_fifo_data_wr_en),
        .rd_en(fifo_data_rd_en),
        .din(rx_fifo_data_din),
        .dout(fifo_data_rd),
        .full_o(rx_fifo_data_full),
        .empty_o(rx_fifo_data_empty)
    );

    localparam IDLE       = 5'd0,
                CS_N_ASSERT = 5'd1,
                SEND_CMD = 5'd2,
                PULL_DOWN_CS_BEFORE_DONE = 5'd3,
                DONE            = 5'd4;

    reg [4:0] state;

    reg clk_out_en;
    assign spi_clk_o = clk_o && clk_out_en;
    reg [7:0] counter_clk_rise;
    reg [7:0] counter_clk_fall;

    always @(posedge clk_i or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            clk_out_en <= 1'b0;
            cs_n_o <= 1'b1;
            counter_clk_rise <= 8'd0;
            counter_clk_fall <= 8'd0;
            done_o <= 1'b0;
        end else begin
            /*
                Write stuff to do during rising edge here
            */
            if (clk_rise) begin
                case (state) 
                    IDLE: begin
                        clk_out_en <= 1'b0;
                        cs_n_o <= 1'b1;
                        counter_clk_rise <= 8'b0;
                        done_o <= 1'b0;
                        if (start_i) begin
                            state <= CS_N_ASSERT;
                            counter_clk_rise <= 8'd2; // dont toggle clk, let cs_n stable
                        end
                    end

                    CS_N_ASSERT: begin
                        cs_n_o <= 1'b0;
                        if (counter_clk_rise == 8'd0) begin
                            state <= SEND_CMD;
                            counter_clk_rise <= 8'd0;
                            counter_clk_fall <= 8'd7;
                        end else begin
                            counter_clk_rise <= counter_clk_rise - 1;
                        end
                    end

                    DONE: begin
                        cs_n_o <= 1'b1;
                        done_o <= 1'b1;
                        if (start_i == 1'b0) begin
                            state <= IDLE;
                        end
                    end


                    default: begin
                        
                    end
                endcase
            /*
                Write stuff to do during falling edge here
            */
            end if (clk_fall) begin
                case (state) 
                    SEND_CMD: begin
                        clk_out_en <= 1'b1;
                        do_o <= instr_i[counter_clk_fall];
                        if (counter_clk_fall == 8'd0) begin
                            state <= PULL_DOWN_CS_BEFORE_DONE;
                        end else begin
                            counter_clk_fall <= counter_clk_fall - 1;
                        end
                    end
                    
                    PULL_DOWN_CS_BEFORE_DONE: begin
                        cs_n_o <= 1'b0;
                        clk_out_en <= 1'b0;
                        state <= DONE;
                    end

                    default: begin
                        
                    end
                endcase
            end
        end
    end

endmodule
