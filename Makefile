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

# # ==================================================
# # AXI wrapped MDIO master
# # ==================================================

# AXI_TOP = axi_mdio
# AXI_TB  = tb/tb_axi_mdio.cpp
# AXI_OBJ = obj_dir_axi_mdio

# AXI_SRC = src/axi_mdio.v \
#           src/mdio_master.v

# $(AXI_OBJ)/V$(AXI_TOP).mk: $(AXI_SRC) $(AXI_TB)
# 	verilator $(VERILATOR_FLAGS) \
# 		--Mdir $(AXI_OBJ) \
# 		--cc $(AXI_SRC) \
# 		--exe $(AXI_TB)

# build_axi_mdio: $(AXI_OBJ)/V$(AXI_TOP).mk
# 	make -j -C $(AXI_OBJ) -f V$(AXI_TOP).mk V$(AXI_TOP)

# run_axi_mdio: build_axi_mdio
# 	./$(AXI_OBJ)/V$(AXI_TOP)

# # ==================================================
# # FIFO
# # ==================================================

# FIFO_TOP = fifo
# FIFO_TB  = tb/tb_fifo.cpp
# FIFO_OBJ = obj_dir_fifo

# FIFO_SRC = src/fifo.v

# $(FIFO_OBJ)/V$(FIFO_TOP).mk: $(FIFO_SRC) $(FIFO_TB)
# 	verilator $(VERILATOR_FLAGS) \
# 		--Mdir $(FIFO_OBJ) \
# 		--cc $(FIFO_SRC) \
# 		--exe $(FIFO_TB)

# build_fifo: $(FIFO_OBJ)/V$(FIFO_TOP).mk
# 	make -j -C $(FIFO_OBJ) -f V$(FIFO_TOP).mk V$(FIFO_TOP)

# run_fifo: build_fifo
# 	./$(FIFO_OBJ)/V$(FIFO_TOP)

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
# Default
# ==================================================


all: run_nand

clean:
	rm -rf obj_dir_nand
	rm -f *.vcd *.o *.d *.exe

.PHONY: all \
	build_nand run_nand \
	build_axi_fifo run_axi_fifo \
	clean