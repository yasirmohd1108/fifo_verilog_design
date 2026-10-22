
# Synchronous FWFT FIFO (Verilog HDL)
## Overview

This repository contains my Verilog implementation of a **First-Word Fall-Through (FWFT) Synchronous FIFO**. 

I built this project to learn how synchronous FIFOs work and how to remove the 1-cycle read latency present in standard FIFOs. In a standard FIFO, you have to assert `rd_en` and wait for the next clock cycle to read `dout`. In an FWFT FIFO, the first written word falls through to `dout` combinationally as soon as `empty` goes low, making data instantly available to downstream logic.

---

## Features

* **First-Word Fall-Through (FWFT):** Immediate data availability on `dout` when `empty = 0`.
* **Parameterized Design:** You can easily change `DATA_WIDTH` (default: 8) and `DEPTH` (default: 16).
* **Automatic Pointer Width:** Uses `$clog2(DEPTH)` so pointer sizes adjust automatically.
* **X-State Free Simulation:** Initialized registers and memory in an `initial` block to eliminate red `$X$` (unknown state) lines in Vivado simulation.
* **Self-Checking Testbench:** Included a testbench with automated `pass_count` / `fail_count` monitoring.

---

## Block Diagram

```text
               +---------------------------------------------------+
               |                     TOP_FIFO                      |
               |                                                   |
in_valid ----->| +----------+   data   +----------+   data   +---+ |
data_in_top -->| | MODULE_A |--------->|   FIFO   |--------->| B | |---> data_out_top
               | |(Producer)|          |  (FWFT)  |          |   | |
               | +----------+          +----------+          +---+ |
               |      ^                     ^                  ^   |
               |      | wr_en          empty|                  |   |
               |      +---------------------+                  |   |
out_ready ---->|-----------------------------------------------+   |
               +---------------------------------------------------+
```

### Modules Breakdown

* **`FIFO.v`**: The main FIFO logic containing memory array, read/write pointers, count logic, and `empty`/`full` flags.
* **`MODULE_A.v`**: Producer module that sends data to the FIFO when `in_valid` is high and FIFO is not `full`.
* **`MODULE_B.v`**: Consumer module that pops data from the FIFO when `out_ready` is high and FIFO is not `empty`.
* **`TOP_FIFO.v`**: Top-level wrapper connecting Producer, FIFO, and Consumer.
* **`tb_FIFO.v`**: Self-checking testbench to verify reset, write/read operations, and flag assertions.

---

## Signal Description

| Signal | Dir | Width | Function |
| :--- | :--- | :--- | :--- |
| `clk` | Input | 1 | Clock |
| `rst` | Input | 1 | Synchronous Active-High Reset |
| `wr_en` | Input | 1 | Write Enable |
| `rd_en` | Input | 1 | Read Enable |
| `din` | Input | `DATA_WIDTH` | Input Data |
| `dout` | Output | `DATA_WIDTH` | Output Data (FWFT) |
| `empty` | Output | 1 | High when FIFO has no elements |
| `full` | Output | 1 | High when FIFO is full |

---

## Simulation & Waveform Verification

The design was simulated in **Xilinx Vivado Behavioral Simulator**.

### Key Observations:
1. **At $0\text{ ns}$:** Reset forces pointers to `0`, `empty` to `1`, and `dout` to `0`.
2. **On Write ($20\text{ ns}$):** Data `8'hAA` is written. `empty` drops to `0` and `dout` immediately shows `8'hAA` without waiting for a read clock cycle.
3. **On Read ($40\text{ ns}$):** Read enable pops the data, and `empty` returns to `1`.
4. **Testbench Output:** All tasks passed cleanly with zero failures (`pass_count = 4`, `fail_count = 0`).

---

## What I Learned
* Understanding the difference between Standard vs FWFT FIFOs.
* Writing self-checking testbenches using tasks and counters.
* Debugging state propagation and initializing variables properly to prevent simulation $X$-states.
