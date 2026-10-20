# Clock Domain Crossing (CDC) Analysis & Physical Implementation

## 1. Fundamentals of Metastability
When a signal generated in one clock domain (`wclk`) is sampled by a flip-flop clocked by an asynchronous domain (`rclk`), setup ($t_{su}$) or hold ($t_h$) timing requirements will periodically be violated.
When violated, the flip-flop output enters a **metastable state**—a balanced, non-digital voltage level between $V_{OL}$ and $V_{OH}$ with unpredictable resolution time.

The Mean Time Between Failures (MTBF) of a 2-stage synchronizer is given by:
$$\text{MTBF} = \frac{e^{\frac{t_{res}}{\tau}}}{T_0 \cdot f_{clk} \cdot f_{data}}$$
Where:
- $t_{res}$: Settling time available to the first flop (roughly one clock period minus setup time).
- $\tau, T_0$: Silicon foundry physical process parameters.
- $f_{clk}$: Destination clock frequency.
- $f_{data}$: Asynchronous data transition rate.

A **two-flip-flop synchronizer** cascades two registers on the destination clock. The probability of the second flip-flop sampling unresolved metastability drops exponentially with $t_{res}$, bringing the MTBF from seconds or minutes to thousands of years.

---

## 2. Why Multi-Bit Binary Buses Must NEVER Cross Asynchronously
Consider a 4-bit binary counter transitioning from `0111` ($7$) to `1000` ($8$). All 4 bits toggle simultaneously.
In a physical layout:
- Wire lengths, routing layers, buffer delays, and local cross-talk introduce **routing skew**.
- The 4 bits will arrive at the destination flip-flops at slightly different times ($\Delta t$).
- If the destination clock edge arrives during $\Delta t$, it will sample intermediate, phantom values (such as `0000`, `0100`, `1111`, etc.).
- A multi-bit 2-FF synchronizer on a binary bus cannot solve this: it only synchronizes bits, not skew.

---

## 3. The Role of Gray Coding
In a Gray-coded counter:
$$\text{Hamming Distance} = 1$$
Across every counter increment, **exactly one bit changes state**.

### What happens if the single changing bit goes metastable?
- Case A: Flop 1 resolves to the *old* bit value $\to$ destination domain sees the previous count (lagging by 1 cycle, which is safe).
- Case B: Flop 1 resolves to the *new* bit value $\to$ destination domain sees the updated count.
- An intermediate or corrupt count is mathematically impossible.

---

## 4. Physical Implementation & Static Timing Constraints

In real ASIC synthesis and STA (Static Timing Analysis):
1. **Prevent Shift-Register Inference**:
   FPGAs and synthesis tools attempt to pack consecutive flip-flops without fanout into SRLs (Shift Register LUTs), which do not have hardened metastable recovery characteristics.
   We prevent this with:
   ```systemverilog
   (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_stage1;
   (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync_stage2;
   ```
2. **Timing Constraints (SDC / XDC)**:
   Never apply an unconstrained `set_false_path` across pointer synchronizers, as the physical router might allow a multi-nanosecond routing skew between bit 0 and bit $N$.
   Instead, use a **datapath-only max delay** constraint bounded by the destination clock period:
   ```tcl
   set_max_delay -from [get_cells wptr_reg*] \
                 -to   [get_cells u_sync_w2r/sync_stage1_reg*] \
                 -datapath_only [get_property -min PERIOD [get_clocks rclk]]
   ```
3. **Dedicated CDC Tooling**:
   RTL simulations assume zero-delay ideal wires and cannot model metastability or routing skew.
   In industry, formal CDC verification tools (e.g., Questa CDC, Synopsys SpyGlass CDC, Cadence Jasper CDC) are mandatory to verify:
   - Synchronizer structure correctness.
   - Gray coding convergence.
   - Reset domain crossing (RDC).
