<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project is a miniaturized branch predictor loosely modeled on TAGE
(TAgged GEometric history length predictors), built for a single Tiny
Tapeout tile. It combines three predictors, arranged in priority order:

1. **Loop predictor** (2 entries) - learns the fixed trip count of small
   loops (e.g. "taken 5 times, then not-taken") and predicts confidently
   once it has seen the same trip count repeat.
2. **Tagged history table** (8 entries, 4-bit tags, 4-bit global history) -
   indexes on a hash of the branch address and recent global branch
   history, catching patterns that depend on what happened a few branches
   ago, not just this branch's own history.
3. **Bimodal base predictor** (8 entries, 2-bit saturating counters) -
   the fallback when neither of the above has learned this branch yet.

On a misprediction, the design allocates a fresh entry in the tagged
table for that branch (protecting existing useful entries rather than
evicting them outright), so the table gradually specializes to whichever
branches actually need history to predict correctly.

The design operates in a trace-replay model: each clock cycle you supply
a branch address (`pc`) and its actual outcome, the predictor
combinationally produces the prediction it would have made from its
state as of the previous cycle, and then trains itself on the outcome
you gave it. This makes it possible to measure real prediction accuracy
against arbitrary branch traces directly on fabricated silicon, and to
compare it against a plain bimodal-only predictor to see how much the
tagged history table and loop predictor actually buy you.

## How to test

Each cycle:
- Drive `ui_in[6:0]` with a 7-bit branch address and `ui_in[7]` with the
  branch's actual outcome (1 = taken, 0 = not-taken).
- Pulse `uio_in[0]` high for one cycle to mark the input as valid.
- Read the prediction off `uo_out[0]` *before* the next clock edge - it
  reflects the predictor's state from before this cycle's training.
- `uo_out[1]` tells you whether that prediction was a misprediction.

To read back cumulative statistics instead, set `uio_in[1]` high and
`uio_in[4:2]` to a register address (0 = correct count, 1 = mispredict
count, 7 = a fixed `0xA5` sanity byte) - the byte appears on `uo_out`.

Hold `uio_in[0]` low for about 40 cycles after reset before feeding real
data, since the internal tables sweep-clear themselves over that window.

A full worked example, including a cocotb test exercising an alternating
pattern, a fixed-trip-count loop, a pseudo-random LFSR sequence, and a
history-correlated pattern, is in `test/test.py`.

## External hardware

List external hardware used in your project (e.g. PMOD, LED display, etc), if any
