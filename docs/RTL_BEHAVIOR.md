# Phase 1 implementation contract

The DOCX Part A remains normative. The interface is fixed at 32-bit address
and data with four byte strobes. Exact full addresses are decoded; high address
bits cannot alias the register bank. Reserved bits read as zero.

AW and W each have a separate one-entry buffer. A write commits on the edge
following the later AW/W handshake. BVALID becomes visible after that edge.
No next write address/data is accepted until the B response has been consumed.
READY outputs are registers; no bus input feeds a combinational bus output.

AR can proceed independently of writes. AR acceptance samples the register
state immediately before the rising edge; RVALID/data/response become visible
after that edge and persist until RREADY. Thus an AR accepted on a write or
completion edge sees the state from before that edge. At most one read and
one write are outstanding, and the two directions may overlap.

A valid START commits with COUNT=0, BUSY=1 and DONE=0, capturing PERIOD.
The first increment is on the following rising edge. Completion occurs on
exactly the captured PERIOD-th subsequent edge, retaining COUNT=PERIOD.
IRQ is combinational DONE && IRQ_EN.

Reset is asynchronous and dominates requests, responses and register changes.
Completion wins over a simultaneous STATUS DONE-clear. A START while BUSY
(including the completion edge) is rejected, using the state before the edge.
Rejected START does not update IRQ_EN; natural timer progress still occurs.
A legal IRQ_EN change on the completion edge takes effect with completion.
PERIOD changes never alter the active captured period.

Address/access permission checks precede strobe handling. Invalid/misaligned
and COUNT/ID writes return SLVERR even with zero strobes. Legal writable
addresses with zero strobes return OKAY without effects. START, IRQ_EN and
DONE-clear are selected only by byte strobe 0. Undefined written bits are ignored.
