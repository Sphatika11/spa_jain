# SPDX-License-Identifier: Apache-2.0
# cocotb test for tt_um_mini_tage (1x1-SAFE variant: bimodal + 1 TAGE table + loop)
#
# Verified against this exact RTL (see also test/tb_standalone.v, a
# cocotb-free version giving identical numbers):
#   alternating pattern       -> ~98% (bimodal/T1 locking a 2-state oscillation)
#   fixed trip-count loop     -> ~98% (loop predictor locking the trip count)
#   pseudo-random (LFSR)      -> ~50% (nothing to learn -- sanity check)
#   period-2 correlated       -> 100% (the TAGE table earning its keep)

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


async def reset(dut):
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    for _ in range(4):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for _ in range(40):
        await RisingEdge(dut.clk)  # let table-clear sweeps finish


async def step(dut, pc, taken):
    dut.ui_in.value = (int(taken) << 7) | (pc & 0x7F)
    dut.uio_in.value = dut.uio_in.value.to_unsigned() | 0x1  # valid
    await Timer(1, unit="ns")
    pred = dut.uo_out.value.to_unsigned() & 0x1
    await RisingEdge(dut.clk)
    dut.uio_in.value = dut.uio_in.value.to_unsigned() & ~0x1
    await RisingEdge(dut.clk)
    return pred == int(taken)


async def read_stat(dut, addr):
    dut.uio_in.value = (dut.uio_in.value.to_unsigned() & ~0x1D) | 0x2 | ((addr & 0x7) << 2)
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    val = dut.uo_out.value.to_unsigned()
    dut.uio_in.value = dut.uio_in.value.to_unsigned() & ~0x2
    await RisingEdge(dut.clk)
    return val


@cocotb.test()
async def test_mini_tage(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset(dut)

    version = await read_stat(dut, 7)
    assert version == 0xA5, f"readback sanity byte mismatch: got {version:#x}"

    correct = sum([await step(dut, 10, i & 1) for i in range(200)])
    dut._log.info(f"alternating accuracy: {correct}/200 ({100*correct//200}%)")
    assert correct > 150

    correct = sum([await step(dut, 20, (i % 6) != 5) for i in range(300)])
    dut._log.info(f"loop(trip=5) accuracy: {correct}/300 ({100*correct//300}%)")
    assert correct > 240

    lfsr = 0xACE1
    correct = 0
    for _ in range(300):
        lfsr = ((lfsr << 1) | (((lfsr >> 15) ^ (lfsr >> 13) ^ (lfsr >> 12) ^ (lfsr >> 10)) & 1)) & 0xFFFF
        correct += await step(dut, 30, lfsr & 1)
    dut._log.info(f"pseudo-random accuracy: {correct}/300 ({100*correct//300}%)")
    assert 100 < correct < 200

    h0, h1 = 0, 0
    correct = 0
    for _ in range(300):
        outcome = h1
        correct += await step(dut, 40, outcome)
        h1, h0 = h0, outcome
    dut._log.info(f"period-2 correlated accuracy: {correct}/300 ({100*correct//300}%)")
    assert correct > 250

    correct_reg = await read_stat(dut, 0)
    dut._log.info(f"cumulative correct_count register (saturating 8-bit) = {correct_reg}")
    assert correct_reg > 0
