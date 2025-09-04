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

falu_tb_path = this_path.parent / "submodules/FALU/test_template.py"
falu_spec = importlib.util.spec_from_file_location("falu_tb", falu_tb_path)
falu_tb = importlib.util.module_from_spec(falu_spec)
falu_spec.loader.exec_module(falu_tb)


@cocotb.test()
async def compare_wrapper_vs_gold(dut):
    """Testing the PWM output behavior."""

    # Create a clock with a period of 10ns = 100MHz
    clock = Clock(dut.clk, 10, "ns")
    await cocotb.start(clock.start())

    dut.ena.value = 0  # Enable PPWM, disable FALU
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Reset the designs for 100ns
    dut.rst_n.value = 0
    await Timer(100, "ns")
    dut.rst_n.value = 1
    await Timer(100, "ns")

    cocotb.start_soon(checker(dut))

    await ppwm_tb.pwm_test(dut)

    dut.ena.value = 1  # Disable PPWM, enable FALU

    await falu_tb.async_falucinator(dut)


async def check_wrapper_vs_dut_values(wrapper_value, project_value, project_name):
    """Check the wrapper output values against the dut output values."""
    assert wrapper_value == project_value, (
        f"Mismatch: wrapper={wrapper_value} {project_name}={project_value}"
    )


async def check_wrapper_vs_project_all_outputs(dut, project, project_name):
    """Wrap the checks for all outputs."""
    await check_wrapper_vs_dut_values(
        dut.heichips25_tiny_wrapper_i.uo_out.value, project.uo_out.value, project_name
    )
    await check_wrapper_vs_dut_values(
        dut.heichips25_tiny_wrapper_i.uio_out.value, project.uio_out.value, project_name
    )
    await check_wrapper_vs_dut_values(
        dut.heichips25_tiny_wrapper_i.uio_oe.value, project.uio_oe.value, project_name
    )


async def checker(dut):
    """Asynchronous checker that compares wrapper vs. standalone outputs."""
    while True:
        await RisingEdge(dut.clk)

        # Only check when ena is asserted
        if not dut.ena.value:
            await check_wrapper_vs_project_all_outputs(dut, dut.ppwm_i, "PPWM")
        else:
            await check_wrapper_vs_project_all_outputs(dut, dut.falu_i, "FALU")
            pass


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
        sources.extend(
            list(testbench_path.glob("../submodules/FALU/src/heichips25_template.sv"))
        )
        sources.extend(
            list(testbench_path.glob("../submodules/heichips25-ppwm/src/*.sv"))
        )
        sources.extend(list(testbench_path.glob("../submodules/FALU/src/*.sv")))
        defines = {"FUNCTIONAL": True, "UNIT_DELAY": "#0"}
    else:
        sources.extend(list(testbench_path.glob("../src/*")))
        sources.extend(
            list(testbench_path.glob("../submodules/heichips25-ppwm/src/*.sv"))
        )
        sources.extend(list(testbench_path.glob("../submodules/FALU/src/*.sv")))
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
