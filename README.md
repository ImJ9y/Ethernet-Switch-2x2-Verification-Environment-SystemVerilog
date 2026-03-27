# Ethernet Switch (2x2) Verification Environment – SystemVerilog

## Overview
This project implements a transaction-level verification environment for a 2x2 Ethernet switch using SystemVerilog.

The environment verifies correct packet routing between two input ports (A/B) and two output ports (A/B), ensuring functional correctness of packet transmission, ordering, and data integrity.

---

## Architecture
Generator → Driver → DUT → Monitor → Checker (Scoreboard)

### Components
- **Generator**: Creates randomized packets using constraints
- **Driver**: Sends packets into the DUT using clocking blocks
- **DUT**: 2x2 Ethernet switch (routing logic)
- **Monitor**: Observes DUT outputs and reconstructs packets
- **Checker (Scoreboard)**:
  - Stores expected packets
  - Compares expected vs actual packets
  - Reports PASS / FAIL

---

## Packet Structure

Each packet contains:
- Source Address (SA)
- Destination Address (DA)
- Payload (2–5 data words)
- CRC (computed using XOR)

---

## Key Features

- Transaction-level modeling using SystemVerilog classes
- Mailbox-based communication between verification components
- Clocking blocks for timing-safe signal interaction
- Packet reconstruction from signal-level DUT outputs
- Scoreboard-based validation with deep-copy expected queues
- CRC computation and end-to-end data integrity checking
- Reset-aware simulation control

---

## Verification Flow

1. Generator creates randomized packets
2. Driver sends packets into DUT (Port A or B)
3. DUT routes packets based on destination address
4. Monitor captures output signals and reconstructs packets
5. Checker compares actual packets with expected packets

---

## Simulation Behavior
- Reset is asserted at the beginning of simulation
- Verification environment starts after reset is deasserted
- Multiple packets are generated and transmitted
- Packets are validated using the scoreboard
- Simulation ends after a fixed time

---

## How to Run

Compile and simulate using your preferred SystemVerilog simulator.

Example:
vcs -sverilog *.sv
./simv
---

## Example Output
PASS: Actual packet on PORT_A matches expected packet
PASS: Actual packet on PORT_B matches expected packet

---

## Future Improvements

- Add SystemVerilog Assertions (SVA)
- Implement functional coverage (covergroups)
- Add backpressure and stall handling scenarios
- Introduce error injection testing
- Convert environment to UVM architecture

---

## Author
**Jay Im**  
M.S. Computer Engineering – Santa Clara University  
