#include "Vaxi_fifo.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vaxi_fifo *dut, VerilatedVcdC* tfp) {
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
void axi_write(Vaxi_fifo *dut, VerilatedVcdC* tfp,
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
uint32_t axi_read(Vaxi_fifo *dut, VerilatedVcdC* tfp,
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


void delay(Vaxi_fifo *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}

// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vaxi_fifo *dut = new Vaxi_fifo;

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
    dut->gpio_in       = 0;

    // Reset sequence
    for (int i = 0; i < 5; i++)
        tick(dut, tfp);

    dut->S_AXI_ARESETN = 1;

    for (int i = 0; i < 5; i++)
        tick(dut, tfp);

    std::cout << "Starting AXI GPIO test\n";

    // -------------------------------------------------
    // TEST 1: Write GPIO output register (r1 @ addr 0x4)
    // -------------------------------------------------
    axi_write(dut, tfp, 0x4, 0x00001234);

    assert(dut->gpio_out == 0x1234);
    std::cout << "GPIO write OK\n";

    delay(dut, tfp, 10);
    // -------------------------------------------------
    // TEST 2: Read back r1
    // -------------------------------------------------
    uint32_t r1 = axi_read(dut, tfp, 0x4);
    assert(r1 == 0x00001234);
    std::cout << "GPIO readback OK\n";

    // -------------------------------------------------
    // TEST 3: Drive gpio_in and read r0
    // r0 returns {16'b0, gpio_in}
    // -------------------------------------------------
    dut->gpio_in = 0xABCD;

    uint32_t r0 = axi_read(dut, tfp, 0x0);
    assert(r0 == 0x0000ABCD);
    std::cout << "GPIO input read OK\n";

    std::cout << "All tests PASSED\n";

    delay(dut, tfp, 10);

    axi_write(dut, tfp, 0x08, 0x1234ABCD);
    axi_write(dut, tfp, 0x08, 0x12340001);
    axi_write(dut, tfp, 0x08, 0x12340002);
    axi_write(dut, tfp, 0x08, 0x12340004);
    // delay(dut, tfp, 10);

    uint32_t fifo_out = axi_read(dut, tfp, 0x08);
    std::cout << "fifo out value: " << std::hex << fifo_out << std::endl;
    fifo_out = axi_read(dut, tfp, 0x08);
    std::cout << "fifo out value: " << std::hex << fifo_out << std::endl;
    fifo_out = axi_read(dut, tfp, 0x08);
    std::cout << "fifo out value: " << std::hex << fifo_out << std::endl;
    fifo_out = axi_read(dut, tfp, 0x08);
    std::cout << "fifo out value: " << std::hex << fifo_out << std::endl;

    delay(dut, tfp, 10);

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}