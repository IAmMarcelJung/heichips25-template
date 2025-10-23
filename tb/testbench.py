# SPDX-FileCopyrightText: © 2025 Marcel Jung
# SPDX-License-Identifier: Apache-2.0

import os
import sys
from pathlib import Path
import importlib.util

import cocotb
from cocotb.clock import Clock
from cocotb.runner import get_runner
from cocotb.triggers import Timer, RisingEdge

# ------------------------------
# Import the testbenches of the wrapped projects
# ------------------------------

this_path = Path(__file__).resolve().parent

ppwm_tb_path = this_path.parent / "submodules/heichips25-ppwm/tb/testbench.py"
ppwm_spec = importlib.util.spec_from_file_location("ppwm_tb", ppwm_tb_path)
ppwm_tb = importlib.util.module_from_spec(ppwm_spec)
ppwm_spec.loader.exec_module(ppwm_tb)

falu_tb_path = this_path.parent / "submodules/FALU/tb/test_falu.py"
falu_spec = importlib.util.spec_from_file_location("falu_tb", falu_tb_path)
falu_tb = importlib.util.module_from_spec(falu_spec)
falu_spec.loader.exec_module(falu_tb)

PPWM_HIGH = 7
PPWM_LOW = 4
FALU_HIGH = 3
FALU_LOW = 0
PPWM_RANGE = slice(PPWM_HIGH, PPWM_LOW)
FALU_RANGE = slice(FALU_HIGH, FALU_LOW)

@cocotb.test()
async def compare_wrapper_vs_gold(dut):
    """Testing the PWM output behavior."""

    # Create a clock with a period of 10ns = 100MHz
    clock = Clock(dut.clk, 10, "ns")
    await cocotb.start(clock.start())

    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Reset the designs for 200ns
    dut.rst_n.value = 0
    await Timer(200, "ns")

    gl = os.getenv("GL", False)

    # The projects are not instantiated separately for the gatelevel simulation,
    # so don't compare the output for a gatelevel simulation
    if not gl:
        cocotb.start_soon(checker(dut))

    await ppwm_tb.pwm_test(dut)

    # Reset the designs for 100ns
    dut.rst_n.value = 0
    await Timer(100, "ns")

    await falu_tb.async_falucinator(dut)


async def check_wrapper_vs_dut_values(wrapper_value, project_value, project_name):
    """Check the wrapper output values against the dut output values."""
    assert wrapper_value == project_value, (
        f"Mismatch: wrapper={wrapper_value} {project_name}={project_value}"
    )


def _slice_if_range_given(signal_value, bit_range: slice | None):
    """Slice the signal if both high and low are provided."""
    if bit_range is not None:
        return signal_value[bit_range.start:bit_range.stop]
    return signal_value


async def check_wrapper_vs_project_all_outputs(dut, project, project_name, bit_range=None):
    """Check all wrapper outputs against project outputs, optionally sliced [high:low]."""

    signal_pairs = [
        ("uo_out",  dut.heichips25_tiny_wrapper_i.uo_out.value,  project.uo_out.value),
        ("uio_out", dut.heichips25_tiny_wrapper_i.uio_out.value, project.uio_out.value),
        ("uio_oe",  dut.heichips25_tiny_wrapper_i.uio_oe.value,  project.uio_oe.value),
    ]

    for name, dut_sig, proj_sig in signal_pairs:
        dut_val = _slice_if_range_given(dut_sig, bit_range)
        proj_val = _slice_if_range_given(proj_sig, bit_range)
        await check_wrapper_vs_dut_values(dut_val, proj_val, f"{project_name}.{name}")


async def checker(dut):
    """Asynchronous checker that compares wrapper vs. standalone outputs."""
    while True:
        await RisingEdge(dut.clk)
        bit_range_project_0 = slice(PPWM_RANGE)
        bit_range_project_1 = slice(FALU_RANGE)

        await check_wrapper_vs_project_all_outputs(dut, dut.ppwm_i, "PPWM",
                                                   bit_range_project_0)
        await check_wrapper_vs_project_all_outputs(dut, dut.falu_i, "FALU",
                                                   bit_range_project_1)


if __name__ == "__main__":
    sim = os.getenv("SIM", "icarus")
    pdk_root = os.getenv("PDK_ROOT", "~/.ciel")
    pdk = os.getenv("PDK", "ihp-sg13g2")
    scl = os.getenv("SCL", "sg13g2_stdcell")
    gl = os.getenv("GL", False)

    testbench_path = Path(__file__).resolve().parent
    sources = []
    defines = {}

    MACRO_NL = testbench_path / "../macro/nl/heichips25_tiny_wrapper.nl.v"

    if gl:
        if not MACRO_NL.exists():
            print(
                f"The macro netlist {MACRO_NL} does not exist. Did you implement the macro?"
            )
            sys.exit(0)

        sources.append(
            Path(pdk_root).expanduser()
            / pdk
            / "libs.ref"
            / scl
            / "verilog"
            / f"{scl}.v"
        )
        sources.append(MACRO_NL)
        sources.extend(testbench_path.glob("testbench.sv"))
        defines = {"FUNCTIONAL": True, "UNIT_DELAY": "#1", "GL": True}
    else:
        sources.extend(list(testbench_path.glob("../src/*")))
        sources.extend(
            list(testbench_path.glob("../submodules/heichips25-ppwm/src/*.sv"))
        )
        sources.extend(
            list(testbench_path.glob("../submodules/FALU/src/heichips25_falu.sv"))
        )
        sources.extend(testbench_path.glob("testbench.sv"))
        defines = {"RTL": True}

    hdl_toplevel = "testbench"

    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        defines=defines,
        timescale=["1ns", "1ps"],
        waves=True,
        build_args=["--trace", "--trace-fst", "--trace-structs"]
        if sim == "verilator"
        else ["-gno-specify"],
    )
    trace_file = ""

    if gl:
        trace_file = f"{hdl_toplevel}_gl.fst"
    else:
        trace_file = f"{hdl_toplevel}.fst"

    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module="testbench",
        timescale=["1ns", "1ps"],
        waves=True,
        plusargs=["--trace-file", trace_file] if sim == "verilator" else [],
    )

    if gl:
        print(
            "\033[93mWARNING: No checks are performed, please check the waveforms manually!\033[0m"
        )
