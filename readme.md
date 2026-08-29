# Parallel NAND Controller wrapped in AXI4 lite

Trying to follow ONFI 1.0 standard, winbond W29N01HVxINA datasheet as the main reference source.

## Supported operations

These are enough for all basic usage of nand flash isn't it
* Reset (0xFF)
* Read Parameter Page (0xEC)
* Page Read (0x00, 0x30)
* Page Program (0x80, 0x10)
* Block Erase (0x60, 0xD0)
* Read Status (0x70)

| Offset | Name       | Description                                              |
|--------|------------|----------------------------------------------------------|
| 0x00   | CTRL       | W: bit[0]=start, bit[3:1]=op select (000=rst,001=read_param, |
|        |            |    010=read_page,011=write_page,100=erase,101=read_status)|
| 0x04   | STATUS     | R: bit[0]=done, bit[1]=error,                            |
|        |            |    bit[5:4]=fifo_write_full/empty,                       |
|        |            |    bit[7:6]=fifo_read_full/empty,                        |
|        |            |    bit[15:8]=NAND status byte from Read Status command    |
| 0x08   | DATA_CNT   | R/W: bit[11:0]=number of bytes to tx/rx                  |
| 0x0C   | ADDR0      | R/W: bit[31:0]=first 4 address bytes                     |
| 0x10   | ADDR1      | R/W: bit[31:0]=second 4 address bytes                    |
| 0x14   | DATA       | R/W: read/write FIFO                                     |
