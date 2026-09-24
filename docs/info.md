<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements a miniaturized TAGE-style branch predictor: a
bimodal base predictor plus one tagged, history-indexed component table,
augmented with a trip-count-learning loop predictor. It operates in a
trace-replay model -- each clock cycle you present a branch address (pc)
and its actual outcome, the predictor combinationally produces the
prediction it would have made from its state as of the previous cycle,
and then trains itself on the given outcome. This lets the predictor's
accuracy be measured directly on silicon by feeding it synthetic or
recorded branch traces.

## How to test

Drive `ui_in[6:0]` with a branch address and `ui_in[7]` with the actual
outcome, pulse `uio_in[0]` (valid) for one cycle, and read the prediction
off `uo_out[0]` before the next clock edge. Set `uio_in[1]` (readback_mode)
high and `uio_in[4:2]` to a register address to read back cumulative
accuracy counters instead. See the repository's docs/INTERFACE.md and
test/test.py for the full protocol and a worked example.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
