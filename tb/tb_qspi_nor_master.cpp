#include "Vqspi_nor_master.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vqspi_nor_master *dut, VerilatedVcdC* tfp) {
    dut->clk_i = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->clk_i = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vqspi_nor_master *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}


// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vqspi_nor_master *dut = new Vqspi_nor_master;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->rst_n = 0;

    delay(dut, tfp, 5);

    dut->rst_n = 1;

    delay(dut, tfp, 5);

    dut->instr_i = 0x06;
    dut->start_i = 1;

    delay(dut, tfp, 100);


    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}
