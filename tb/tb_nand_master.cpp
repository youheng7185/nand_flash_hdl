#include "Vnand_master.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <iostream>
#include <cassert>

vluint64_t sim_time = 0;

void tick(Vnand_master *dut, VerilatedVcdC* tfp) {
    dut->clk_i = 0;
    dut->eval();
    tfp->dump(sim_time++);

    dut->clk_i = 1;
    dut->eval();
    tfp->dump(sim_time++);
}

void delay(Vnand_master *dut, VerilatedVcdC* tfp, uint32_t count) {
    for (int i = 0; i < count; i++) {
        tick(dut, tfp);
    }
}


// -------------------------------------------------
// MAIN
// -------------------------------------------------
int main(int argc, char **argv) {

    Verilated::commandArgs(argc, argv);

    Vnand_master *dut = new Vnand_master;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    dut->trace(tfp, 99);
    tfp->open("waveform.vcd");

    // Initialize signals
    dut->rst_n = 0;

    delay(dut, tfp, 5);

    dut->rst_n = 1;

    delay(dut, tfp, 5);

    dut->rb_i = 1; // ready

    dut->rst_nand_i = 1;
    dut->start_i = 1;

    delay(dut, tfp, 300);

    dut->start_i = 0;
    
    delay(dut, tfp, 100);
    
    dut->rst_nand_i = 0;
    dut->read_param_i = 1;
    dut->start_i = 1;
    dut->data_cnt = 4;

    delay(dut, tfp, 800);
    dut->io_i = 0xEE;
    delay(dut, tfp, 300);
    dut->io_i = 0xDA;
    delay(dut, tfp, 300);
    dut->io_i = 0x9E;
    delay(dut, tfp, 300);
    dut->io_i = 0xCA;    
    delay(dut, tfp, 1000);

    dut->start_i = 0;
    delay(dut, tfp, 100);

    // read out the fifo
    dut->fifo_read_data_rd_en = 1;
    for (int i = 0; i < 4; i++) {
        tick(dut, tfp);
        std::cout << "tick out the data: " << std::hex << dut->fifo_read_data_dout << std::endl;
    }
    dut->fifo_read_data_rd_en = 0;
    std::cout << "break" << std::endl;

    delay(dut, tfp, 100);
    
    dut->read_param_i = 0;
    dut->data_cnt = 4;
    dut->read_page_i = 1;
    dut->start_i = 1;
    dut->addr_input_0 = 0x44332211;

    delay(dut, tfp, 2000);
    dut->io_i = 0xAB;
    delay(dut, tfp, 300);
    dut->io_i = 0xCD;
    delay(dut, tfp, 300);
    dut->io_i = 0xEF;
    delay(dut, tfp, 300);
    dut->io_i = 0x12; 
    delay(dut, tfp, 1000);    

    dut->start_i = 0;
    // read out the fifo
    dut->fifo_read_data_rd_en = 1;
    for (int i = 0; i < 4; i++) {
        tick(dut, tfp);
        std::cout << "tick out the data: " << std::hex << dut->fifo_read_data_dout << std::endl;
    }
    dut->fifo_read_data_rd_en = 0;
    std::cout << "break" << std::endl;
    
    delay(dut, tfp, 500); 

    dut->start_i = 1;
    dut->read_page_i = 0;
    dut->erase_block_i = 1;
    delay(dut, tfp, 1500);
    
    std::cout << "write page now" << std::endl;

    dut->start_i = 0;
    dut->erase_block_i = 0;
    delay(dut, tfp, 100);

    dut->fifo_write_data_wr_en = 1;
    uint32_t data[4] = {0x04030201, 0x08070605, 0x40302010, 0x80706050};

    for (int i = 0; i < 4; i++) {
        dut->fifo_write_data_din = data[i];
        tick(dut, tfp);
    }

    dut->fifo_write_data_wr_en = 0;
    delay(dut, tfp, 10);

    dut->start_i = 1;
    dut->write_page_i = 1;
    dut->data_cnt = 32;
    dut->addr_input_0 = 0xAB123456;

    delay(dut, tfp, 10000);

    dut->fifo_write_data_wr_en = 1;
    uint32_t data2[4] = {0x40302010, 0x80706050, 0x04030201, 0x08070605};

    for (int i = 0; i < 4; i++) {
        dut->fifo_write_data_din = data2[i];
        tick(dut, tfp);
    }

    dut->fifo_write_data_wr_en = 0;
    tick(dut, tfp);

    delay(dut, tfp, 10000);

    std::cout << "finished test\n";

    // Finish
    dut->final();
    tfp->close();
    delete dut;
    return 0;
}
