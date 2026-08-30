# Makefile for MDIO Verilator testbench

VERILATOR_FLAGS = -Wall --trace \
    -Wno-fatal \
    -Wno-UNUSED \
    -Wno-UNDRIVEN \
    -Wno-PINMISSING

# ==================================================
# Original nand master
# ==================================================

nand_TOP = nand_master
nand_TB  = tb/tb_nand_master.cpp
nand_OBJ = obj_dir_nand

nand_SRC = src/nand_master.v \
			src/fifo.v

$(nand_OBJ)/V$(nand_TOP).mk: $(nand_SRC) $(nand_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(nand_OBJ) \
		--cc $(nand_SRC) \
		--exe $(nand_TB)

build_nand: $(nand_OBJ)/V$(nand_TOP).mk
	make -j -C $(nand_OBJ) -f V$(nand_TOP).mk V$(nand_TOP)

run_nand: build_nand
	./$(nand_OBJ)/V$(nand_TOP)

# ==================================================
# AXI_NAND
# ==================================================

AXI_NAND_TOP = axi_nand
AXI_NAND_TB  = tb/tb_axi_nand.cpp
AXI_NAND_OBJ = obj_dir_axi_nand

AXI_NAND_SRC = src/axi_nand.v \
				src/nand_master.v \
				src/fifo.v

$(AXI_NAND_OBJ)/V$(AXI_NAND_TOP).mk: $(AXI_NAND_SRC) $(AXI_NAND_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(AXI_NAND_OBJ) \
		--cc $(AXI_NAND_SRC) \
		--exe $(AXI_NAND_TB)

build_axi_nand: $(AXI_NAND_OBJ)/V$(AXI_NAND_TOP).mk
	make -j -C $(AXI_NAND_OBJ) -f V$(AXI_NAND_TOP).mk V$(AXI_NAND_TOP)

run_axi_nand: build_axi_nand
	./$(AXI_NAND_OBJ)/V$(AXI_NAND_TOP)

# ==================================================
# AXI_FIFO
# ==================================================

AXI_FIFO_TOP = axi_fifo
AXI_FIFO_TB  = tb/tb_axi_fifo.cpp
AXI_FIFO_OBJ = obj_dir_axi_fifo

AXI_FIFO_SRC = src/axi_fifo.v \
				src/fifo.v

$(AXI_FIFO_OBJ)/V$(AXI_FIFO_TOP).mk: $(AXI_FIFO_SRC) $(AXI_FIFO_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(AXI_FIFO_OBJ) \
		--cc $(AXI_FIFO_SRC) \
		--exe $(AXI_FIFO_TB)

build_axi_fifo: $(AXI_FIFO_OBJ)/V$(AXI_FIFO_TOP).mk
	make -j -C $(AXI_FIFO_OBJ) -f V$(AXI_FIFO_TOP).mk V$(AXI_FIFO_TOP)

run_axi_fifo: build_axi_fifo
	./$(AXI_FIFO_OBJ)/V$(AXI_FIFO_TOP)

# ==================================================
# qspi nor master
# ==================================================

nor_TOP = qspi_nor_master
nor_TB  = tb/tb_qspi_nor_master.cpp
nor_OBJ = obj_dir_qspi_nor

nor_SRC = src/qspi_nor_master.v \
		  src/fifo.v

$(nor_OBJ)/V$(nor_TOP).mk: $(nor_SRC) $(nor_TB)
	verilator $(VERILATOR_FLAGS) \
		--Mdir $(nor_OBJ) \
		--cc $(nor_SRC) \
		--exe $(nor_TB)

build_nor: $(nor_OBJ)/V$(nor_TOP).mk
	make -j -C $(nor_OBJ) -f V$(nor_TOP).mk V$(nor_TOP)

run_nor: build_nor
	./$(nor_OBJ)/V$(nor_TOP)

# ==================================================
# Default
# ==================================================

all: run_nand

clean:
	rm -rf obj_dir_nand obj_dir_axi_fifo obj_dir_qspi_nor
	rm -f *.vcd *.o *.d *.exe

.PHONY: all \
	build_nand run_nand \
	build_axi_fifo run_axi_fifo \
	build_axi_nand run_axi_nand \
	build_nor run_nor \
	clean