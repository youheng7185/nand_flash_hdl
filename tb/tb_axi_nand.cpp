#include "Vaxi_nand.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxi_nand *dut, VerilatedVcdC* tfp) {
    dut->S_AXI_ACLK = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->S_AXI_ACLK = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

// -------------------------------------------------
// AXI WRITE
// -------------------------------------------------
void axi_write(Vaxi_nand *dut, VerilatedVcdC* tfp,
               uint32_t addr, uint32_t data)
{
    // Setup write address + data
    dut->S_AXI_AWADDR  = addr;
    dut->S_AXI_AWVALID = 1;

    dut->S_AXI_WDATA  = data;
    dut->S_AXI_WSTRB  = 0xF;
    dut->S_AXI_WVALID = 1;

    dut->S_AXI_BREADY = 1;

    // Wait for AWREADY
    while (!dut->S_AXI_AWREADY)
        tick(dut, tfp);

    tick(dut, tfp);

    dut->S_AXI_AWVALID = 0;
    dut->S_AXI_WVALID  = 0;

    // Wait for BVALID
    while (!dut->S_AXI_BVALID)
        tick(dut, tfp);

    tick(dut, tfp);

    dut->S_AXI_BREADY = 0;
}

// -------------------------------------------------
// AXI READ
// -------------------------------------------------
uint32_t axi_read(Vaxi_nand *dut, VerilatedVcdC* tfp,
                  uint32_t addr)
{
    // Wait for ARREADY
    while (!dut->S_AXI_ARREADY)
        tick(dut, tfp);

    dut->S_AXI_ARADDR  = addr;
    dut->S_AXI_ARVALID = 1;
    dut->S_AXI_RREADY  = 1;

    tick(dut, tfp);
    dut->S_AXI_ARVALID = 0;

    // Wait for RVALID
    while (!dut->S_AXI_RVALID)
        tick(dut, tfp);

    uint32_t data = dut->S_AXI_RDATA;

    tick(dut, tfp);
    dut->S_AXI_RREADY = 0;

    return data;
}


void delay(Vaxi_nand *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxi_nand *dut = new Vaxi_nand;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->S_AXI_ARESETN = 0;
    dut->S_AXI_AWVALID = 0;
    dut->S_AXI_WVALID  = 0;
    dut->S_AXI_BREADY  = 0;
    dut->S_AXI_ARVALID = 0;
    dut->S_AXI_RREADY  = 0;

    // nand not busy
    dut->rb_i = 1;

    // Reset sequence
    for (int i = 0; i < 5; i++)
        tick(dut, tfp);

    dut->S_AXI_ARESETN = 1;

    for (int i = 0; i < 5; i++)
        tick(dut, tfp);

    std::cout << "Starting AXI nand test\n";

    /*
        Reset
    */
    printf("\nreset\n");
    axi_write(dut, tfp, 0x00, 0x01); // reset

    delay(dut, tfp, 500);
    axi_write(dut, tfp, 0x00, 0x00); // set start_i to 0

    /*
        Read parameters
    */
    printf("\n\npage params\n");
    axi_write(dut, tfp, 0x08, 0x04); // four data count
    axi_write(dut, tfp, 0x00, 0x03);
    delay(dut, tfp, 800);
    dut->io_i = 0xEE;
    delay(dut, tfp, 300);
    dut->io_i = 0xDA;
    delay(dut, tfp, 300);
    dut->io_i = 0x9E;
    delay(dut, tfp, 300);
    dut->io_i = 0xCA;    
    delay(dut, tfp, 800);
    
    uint32_t status = axi_read(dut, tfp, 0x04);
    printf("status: 0b%b\n", status);

    axi_write(dut, tfp, 0x00, 0x00);

    for (int i = 0; i < 4; i++) {
        uint32_t data1 = axi_read(dut, tfp, 0x14);
        printf("data: 0x%x\n", data1);
        status = axi_read(dut, tfp, 0x04);
        printf("status: 0b%b\n", status);
    }

    /*
        Page read
    */
    printf("\n\npage read\n");
    axi_write(dut, tfp, 0x08, 4);
    axi_write(dut, tfp, 0x0C, 0x44332211);
    axi_write(dut, tfp, 0x00, 0b0101);

    delay(dut, tfp, 2000);
    dut->io_i = 0xAB;
    delay(dut, tfp, 300);
    dut->io_i = 0xCD;
    delay(dut, tfp, 300);
    dut->io_i = 0xEF;
    delay(dut, tfp, 300);
    dut->io_i = 0x12; 
    delay(dut, tfp, 1000); 

    axi_write(dut, tfp, 0x00, 0x00);
    for (int i = 0; i < 4; i++) {
        uint32_t data1 = axi_read(dut, tfp, 0x14);
        printf("data: 0x%x\n", data1);
        status = axi_read(dut, tfp, 0x04);
        printf("status: 0b%b\n", status);
    }    

    /*
        Block erase
    */
    printf("\n\nBlock erase\n");
    axi_write(dut, tfp, 0x00, 0b1001);
    delay(dut, tfp, 2000);


    /*
        Page write
    */
    printf("\n\npage write\n");
    axi_write(dut, tfp, 0x00, 0x00);
    uint32_t data[4] = {0x04030201, 0x08070605, 0x40302010, 0x80706050};
    for (int i = 0; i < 4; i++) {
        axi_write(dut, tfp, 0x14, data[i]);
    }

    axi_write(dut, tfp, 0x08, 32);
    axi_write(dut, tfp, 0x0C, 0xAB123456);
    axi_write(dut, tfp, 0x00, 0b0111);

    delay(dut, tfp, 10000);

    uint32_t data2[4] = {0x40302010, 0x80706050, 0x04030201, 0x08070605};
    for (int i = 0; i < 4; i++) {
        axi_write(dut, tfp, 0x14, data2[i]);
    }    

    delay(dut, tfp, 8000);
    axi_write(dut, tfp, 0x00, 0x00);
    delay(dut, tfp, 100);

    /*
        Read status
    */
    printf("\n\nread status\n");
    axi_write(dut, tfp, 0x00, 0b1011);

    delay(dut, tfp, 300);
    dut->rb_i = 0; // fake not ready
    delay(dut, tfp, 1000);
    dut->rb_i = 1;
    dut->io_i = 0x34; // fake status
    delay(dut, tfp, 500);

    uint32_t status_read = axi_read(dut, tfp, 0x04);
    uint32_t nand_status = (status_read >> 8) & 0xFF;
    printf("status read: 0x%x\n", status_read);
    printf("nand status: 0x%x\n", nand_status);

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}