# Mini-TAGE Branch Predictor — Tiny Tapeout

A miniaturized branch predictor for a single Tiny Tapeout tile: a bimodal
base predictor, a tagged history-indexed component table, and a
trip-count-learning loop predictor, wired together with a simplified
allocate-on-misprediction training policy (in the style of TAGE
predictors used in real CPUs, drastically scaled down to fit ~800
standard cells).

It runs in a trace-replay model over the pins — feed it a branch address
and its actual outcome each cycle, read the prediction back, and it
trains itself in real time. This lets prediction accuracy be measured
directly on fabricated silicon rather than only in simulation.

See [`docs/info.md`](docs/info.md) for the full architecture writeup and
testing protocol, and [`test/test.py`](test/test.py) for a working
example against several synthetic branch trace patterns.

Built and verified with Icarus Verilog + cocotb; synthesizes (generic
techmap) to ~800 cells against Tiny Tapeout's ~1000-gate 1×1 tile budget.