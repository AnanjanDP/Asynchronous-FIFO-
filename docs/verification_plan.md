# Asynchronous FIFO Verification Plan

## 1. Test Suite Coverage Matrix

| Test ID | Scenario | Intended Bug / Failure Mode Detected | Status |
|:---|:---|:---|:---:|
| **TEST 01** | Reset & Initial Flags | Stuck-at reset fault; `rempty != 1` or `wfull != 0` on boot. | **PASS** |
| **TEST 02** | Single Write & Read | Basic single-cycle pipeline latency; CDC flag deassertion failure. | **PASS** |
| **TEST 03** | Multiple Writes & Reads | Data corruptions or ordering errors over small bursts. | **PASS** |
| **TEST 04** | Fill to Capacity | Late full-flag assertion causing false overflow. | **PASS** |
| **TEST 05** | Overflow Attempt | Missing hardware write-inhibit; memory corruption during full. | **PASS** |
| **TEST 06** | Drain to Empty | Missing hardware empty assertion; pointer stall. | **PASS** |
| **TEST 07** | Underflow Attempt | Missing hardware read-inhibit; pointer corruption during empty. | **PASS** |
| **TEST 08** | Simultaneous Read/Write | Dual-port collision, race condition during concurrent operations. | **PASS** |
| **TEST 09** | Back-to-Back Bursts | Flow-control stall bubbles; backpressure drop. | **PASS** |
| **TEST 10** | Wraparound (64 items) | Gray code reflection failure at wraparound boundary ($2^N - 1 \to 0$). | **PASS** |
| **TEST 11** | Fast Write / Slow Read (10:1) | Synchronizer lag causing overflow; FIFO filling faster than flags sync. | **PASS** |
| **TEST 12** | Slow Write / Fast Read (1:10) | Read domain thrashing on single-entry bursts; false empty flags. | **PASS** |
| **TEST 13** | Randomized Clocks & Jitter | Phase alignment vulnerabilities and dynamic ratio race hazards. | **PASS** |
| **TEST 14** | Comprehensive Data Patterns | Stuck-at bits, bus coupling cross-talk patterns (`0x00, 0xFF, 0xAA, 0x55, walking 1s`). | **PASS** |
| **TEST 15** | Mid-Traffic Asynchronous Reset | Recovery/removal race hazards; non-zero pointer lingering post-reset. | **PASS** |

---

## 2. Assertion Verification (SVA)
Defined in `assertions/async_fifo_sva.sv`:
- `a_no_write_on_full`: `wfull && winc |=> (wbin == $past(wbin))`
- `a_no_read_on_empty`: `rempty && rinc |=> (rbin == $past(rbin))`
- `a_wptr_gray_hamming`: `$onehot0(wptr ^ $past(wptr))`
- `a_rptr_gray_hamming`: `$onehot0(rptr ^ $past(rptr))`
- `a_wfull_reset`: `!wrst_n |-> (wfull == 0 && wbin == 0)`
- `a_rempty_reset`: `!rrst_n |-> (rempty == 1 && rbin == 0)`

---

## 3. Functional Coverage Plan
Defined in `coverage/fifo_coverage.sv`:
- **`cg_write_domain`**: `wfull` coverage (0/1), all write addresses `waddr` hit, wraparound transition, 4-cycle consecutive write burst.
- **`cg_read_domain`**: `rempty` coverage (0/1), all read addresses `raddr` hit, wraparound transition, 4-cycle consecutive read burst.
