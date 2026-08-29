module axi_nand #(
    parameter C_AXI_ADDR_WIDTH = 6,
    localparam C_AXI_DATA_WIDTH = 32,
    parameter [0:0] OPT_LOWPOWER = 0
) (
    input  wire                         S_AXI_ACLK,
    input  wire                         S_AXI_ARESETN,

    input  wire                         S_AXI_AWVALID,
    output wire                         S_AXI_AWREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0]  S_AXI_AWADDR,
    input  wire [2:0]                   S_AXI_AWPROT,

    input  wire                         S_AXI_WVALID,
    output wire                         S_AXI_WREADY,
    input  wire [C_AXI_DATA_WIDTH-1:0]  S_AXI_WDATA,
    input  wire [C_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,

    output wire                         S_AXI_BVALID,
    input  wire                         S_AXI_BREADY,
    output wire [1:0]                   S_AXI_BRESP,

    input  wire                         S_AXI_ARVALID,
    output wire                         S_AXI_ARREADY,
    input  wire [C_AXI_ADDR_WIDTH-1:0]  S_AXI_ARADDR,
    input  wire [2:0]                   S_AXI_ARPROT,

    output wire                         S_AXI_RVALID,
    input  wire                         S_AXI_RREADY,
    output wire [C_AXI_DATA_WIDTH-1:0]  S_AXI_RDATA,
    output wire [1:0]                   S_AXI_RRESP,

    // NAND physical pins
    input  wire [7:0]  io_i,
    output wire [7:0]  io_o,
    output wire        oe_o,
    output wire        ce_n_o,
    output wire        cle_o,
    output wire        ale_o,
    output wire        re_n_o,
    output wire        we_n_o,
    input  wire        rb_i
);

    localparam ADDRLSB = 2;

    // -------------------------------------------------------------------------
    // Register addresses (word addressed, drop bottom 2 bits)
    // 0x00 CTRL
    // 0x04 STATUS
    // 0x08 DATA_CNT
    // 0x0C ADDR0
    // 0x10 ADDR1
    // 0x14 DATA FIFO
    // -------------------------------------------------------------------------
    localparam ADDR_CTRL     = 4'd0,  // 0x00 >> 2
               ADDR_STATUS   = 4'd1,  // 0x04 >> 2
               ADDR_DATA_CNT = 4'd2,  // 0x08 >> 2
               ADDR_ADDR0    = 4'd3,  // 0x0C >> 2
               ADDR_ADDR1    = 4'd4,  // 0x10 >> 2
               ADDR_DATA     = 4'd5;  // 0x14 >> 2

    wire i_reset = !S_AXI_ARESETN;

    // -------------------------------------------------------------------------
    // AXI write channel
    // -------------------------------------------------------------------------
    reg                          aw_latched;
    reg  [C_AXI_ADDR_WIDTH-1:0] aw_addr_lat;
    reg                          w_latched;
    reg  [C_AXI_DATA_WIDTH-1:0] w_data_lat;
    reg  [C_AXI_DATA_WIDTH/8-1:0] w_strb_lat;
    reg                          axil_awready;
    reg                          axil_wready_r;
    reg                          axil_bvalid;

    wire axil_write_ready = aw_latched && w_latched;
    wire [C_AXI_ADDR_WIDTH-ADDRLSB-1:0] awskd_addr;
    wire [C_AXI_DATA_WIDTH-1:0]          wskd_data;
    wire [C_AXI_DATA_WIDTH/8-1:0]        wskd_strb;

    assign awskd_addr = aw_addr_lat[C_AXI_ADDR_WIDTH-1:ADDRLSB];
    assign wskd_data  = w_data_lat;
    assign wskd_strb  = w_strb_lat;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            aw_latched  <= 0;
            aw_addr_lat <= 0;
        end else if (S_AXI_AWVALID && S_AXI_AWREADY) begin
            aw_addr_lat <= S_AXI_AWADDR;
            aw_latched  <= 1;
        end else if (axil_write_ready) begin
            aw_latched  <= 0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axil_awready <= 0;
        else
            axil_awready <= !aw_latched && !S_AXI_AWREADY;
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            w_latched  <= 0;
            w_data_lat <= 0;
            w_strb_lat <= 0;
        end else if (S_AXI_WVALID && S_AXI_WREADY) begin
            w_data_lat <= S_AXI_WDATA;
            w_strb_lat <= S_AXI_WSTRB;
            w_latched  <= 1;
        end else if (axil_write_ready) begin
            w_latched  <= 0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN)
            axil_wready_r <= 0;
        else
            axil_wready_r <= !w_latched && !S_AXI_WREADY;
    end

    always @(posedge S_AXI_ACLK) begin
        if (i_reset)
            axil_bvalid <= 0;
        else if (axil_write_ready)
            axil_bvalid <= 1;
        else if (S_AXI_BREADY)
            axil_bvalid <= 0;
    end

    assign S_AXI_AWREADY = axil_awready;
    assign S_AXI_WREADY  = axil_wready_r;
    assign S_AXI_BVALID  = axil_bvalid;
    assign S_AXI_BRESP   = 2'b00;

    // -------------------------------------------------------------------------
    // AXI read channel
    // -------------------------------------------------------------------------
    wire [C_AXI_ADDR_WIDTH-ADDRLSB-1:0] arskd_addr;
    assign arskd_addr = S_AXI_ARADDR[C_AXI_ADDR_WIDTH-1:ADDRLSB];

    wire axil_read_ready = S_AXI_ARVALID && S_AXI_ARREADY;

    reg axil_arready_r;
    reg axil_read_valid;
    reg [C_AXI_DATA_WIDTH-1:0] axil_read_data;

    reg fifo_rd_en_r;
    reg fifo_rd_pending;
    reg fifo_read_in_progress;

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            fifo_rd_en_r          <= 1'b0;
            fifo_rd_pending       <= 1'b0;
            fifo_read_in_progress <= 1'b0;
        end else begin
            fifo_rd_en_r    <= 1'b0;
            fifo_rd_pending <= fifo_rd_en_r;

            if (axil_read_ready && (arskd_addr == ADDR_DATA) && !fifo_read_data_empty) begin
                fifo_rd_en_r          <= 1'b1;
                fifo_read_in_progress <= 1'b1;
            end

            if (fifo_rd_pending) begin
                fifo_read_in_progress <= 1'b0;
            end
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axil_arready_r <= 1'b0;
        end else begin
            axil_arready_r <= !S_AXI_RVALID && !fifo_read_in_progress;
            if (S_AXI_ARVALID && axil_arready_r)
                axil_arready_r <= 1'b0;
        end
    end

    always @(posedge S_AXI_ACLK) begin
        if (!S_AXI_ARESETN) begin
            axil_read_valid <= 1'b0;
            axil_read_data  <= 32'b0;
        end else if (fifo_rd_pending) begin
            axil_read_valid <= 1'b1;
            axil_read_data  <= fifo_read_data_dout;
        end else if (axil_read_ready && (arskd_addr != ADDR_DATA)) begin
            axil_read_valid <= 1'b1;
            case (arskd_addr)
                ADDR_CTRL: axil_read_data <= 32'b0; // CTRL is write-only
                ADDR_STATUS: axil_read_data <= {
                    16'b0,
                    nand_status,            // [15:8] NAND status byte
                    fifo_read_data_empty,   // [7]
                    fifo_read_data_full,    // [6]
                    fifo_write_data_empty,  // [5]
                    fifo_write_data_full,   // [4]
                    2'b0,                   // [3:2] reserved
                    nand_error,             // [1]
                    nand_done               // [0]
                };
                ADDR_DATA_CNT: axil_read_data <= reg_data_cnt;
                ADDR_ADDR0:    axil_read_data <= reg_addr0;
                ADDR_ADDR1:    axil_read_data <= reg_addr1;
                default:       axil_read_data <= 32'b0;
            endcase
        end else if (axil_read_valid && S_AXI_RREADY) begin
            axil_read_valid <= 1'b0;
        end
    end

    assign S_AXI_ARREADY = axil_arready_r;
    assign S_AXI_RVALID  = axil_read_valid;
    assign S_AXI_RDATA   = axil_read_data;
    assign S_AXI_RRESP   = 2'b00;

    // -------------------------------------------------------------------------
    // Registers
    // -------------------------------------------------------------------------
    reg        ctrl_start;
    reg [2:0]  ctrl_op;
    reg [31:0] reg_data_cnt;
    reg [31:0] reg_addr0;
    reg [31:0] reg_addr1;

    wire        nand_done;
    wire        nand_error;
    wire [7:0]  nand_status;

    // write FIFO (AXI master → NAND)
    reg         fifo_write_wr_en;
    reg  [31:0] fifo_write_din;
    wire        fifo_write_data_full;
    wire        fifo_write_data_empty;

    // read FIFO (NAND → AXI master)
    wire        fifo_read_rd_en;
    wire [31:0] fifo_read_data_dout;
    wire        fifo_read_data_full;
    wire        fifo_read_data_empty;

    assign fifo_read_rd_en = fifo_rd_en_r;

    always @(posedge S_AXI_ACLK) begin
        if (i_reset) begin
            ctrl_start      <= 1'b0;
            ctrl_op         <= 3'd0;
            reg_data_cnt    <= 32'd0;
            reg_addr0       <= 32'd0;
            reg_addr1       <= 32'd0;
            fifo_write_wr_en <= 1'b0;
            fifo_write_din  <= 32'd0;
        end else begin
            // ctrl_start       <= 1'b0;  // self clear
            fifo_write_wr_en <= 1'b0;  // self clear

            if (axil_write_ready) begin
                case (awskd_addr)
                    ADDR_CTRL: begin
                        ctrl_start <= wskd_data[0];
                        ctrl_op    <= wskd_data[3:1];
                    end
                    ADDR_DATA_CNT: reg_data_cnt <= wskd_data;
                    ADDR_ADDR0:    reg_addr0    <= wskd_data;
                    ADDR_ADDR1:    reg_addr1    <= wskd_data;
                    ADDR_DATA: begin
                        if (!fifo_write_data_full) begin
                            fifo_write_wr_en <= 1'b1;
                            fifo_write_din   <= wskd_data;
                        end
                    end
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // nand_master instance
    // -------------------------------------------------------------------------
    nand_master u_nand_master (
        .clk_i                  (S_AXI_ACLK),
        .rst_n                  (S_AXI_ARESETN),

        .io_i                   (io_i),
        .io_o                   (io_o),
        .oe_o                   (oe_o),
        .ce_n_o                 (ce_n_o),
        .cle_o                  (cle_o),
        .ale_o                  (ale_o),
        .re_n_o                 (re_n_o),
        .we_n_o                 (we_n_o),
        .rb_i                   (rb_i),

        .start_i                (ctrl_start),
        .rst_nand_i             (ctrl_op == 3'd0),
        .read_param_i           (ctrl_op == 3'd1),
        .read_page_i            (ctrl_op == 3'd2),
        .write_page_i           (ctrl_op == 3'd3),
        .erase_block_i          (ctrl_op == 3'd4),
        .read_status_i          (ctrl_op == 3'd5),

        .data_cnt               (reg_data_cnt[11:0]),

        .done_o                 (nand_done),
        .error_o                (nand_error),
        .status_o               (nand_status),

        .addr_input_0           (reg_addr0),
        .addr_input_1           (reg_addr1),

        .fifo_read_data_rd_en   (fifo_read_rd_en),
        .fifo_read_data_dout    (fifo_read_data_dout),
        .fifo_read_data_full    (fifo_read_data_full),
        .fifo_read_data_empty   (fifo_read_data_empty),

        .fifo_write_data_wr_en  (fifo_write_wr_en),
        .fifo_write_data_din    (fifo_write_din),
        .fifo_write_data_full   (fifo_write_data_full),
        .fifo_write_data_empty  (fifo_write_data_empty)
    );

    // -------------------------------------------------------------------------
    // Unused signal tie-off for linting
    // -------------------------------------------------------------------------
    wire unused;
    assign unused = &{1'b0, S_AXI_AWPROT, S_AXI_ARPROT,
                      S_AXI_ARADDR[ADDRLSB-1:0],
                      S_AXI_AWADDR[ADDRLSB-1:0]};

endmodule