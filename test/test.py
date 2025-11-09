# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge



@cocotb.test()
async def test_preset0(dut):
    dut._log.info("Start test_preset0")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0b0_00_0_0_0_0_0  # Auto mode, Preset 0, no swap
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    dut._log.info("Check preset0 initialization")

    # Use public outputs instead of internal signals
    # uo_out = tape (when swap=0)
    # uio_out = {mode[2:0], state[1:0], headpos[2:0]}
    
    tape = dut.uo_out.value
    status = dut.uio_out.value
    
    # Extract status fields
    headpos = status.to_unsigned() & 0x7          # Bits [2:0]
    state = (status.to_unsigned() >> 3) & 0x3     # Bits [4:3]
    mode = (status.to_unsigned() >> 5) & 0x7      # Bits [7:5]
    
    dut._log.info(f"Initial - Tape: {str(tape)}, Mode: {mode}, State: {state}, Head: {headpos}")
    
    assert tape == 0b11100000, f"Expected tape=0b11100000, got {str(tape)}"
    assert mode == 3, f"Expected MODE_RUN (3), got {mode}"
    assert headpos == 0, f"Expected head at position 0, got {headpos}"
    assert state == 0, f"Expected state 0, got {state}"

    # Run for cycles until HALT
    for cycle in range(20):
        await RisingEdge(dut.clk)
        
        tape = dut.uo_out.value
        status = dut.uio_out.value
        
        headpos = status.to_unsigned() & 0x7
        state = (status.to_unsigned() >> 3) & 0x3
        mode = (status.to_unsigned() >> 5) & 0x7
        
        dut._log.info(f"Cycle {cycle:2d}: Tape={str(tape)} Mode={mode} State={state} Head={headpos}")
        
        if mode == 4:  # MODE_HALT
            dut._log.info(f"Machine halted at cycle {cycle}")
            break

    # Final checks
    assert tape == 0b11110000, f"Expected final tape=0b11110000, got {str(tape)}"
    assert mode == 4, f"Expected MODE_HALT (4), got {mode}"

@cocotb.test()
async def test_preset1(dut):
    dut._log.info("Start test_preset1")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0b0_01_0_0_0_0_0  # Auto mode, Preset 1, no swap
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    dut._log.info("Check preset1 initialization")

    # Use public outputs instead of internal signals
    # uo_out = tape (when swap=0)
    # uio_out = {mode[2:0], state[1:0], headpos[2:0]}
    
    tape = dut.uo_out.value
    status = dut.uio_out.value
    
    # Extract status fields
    headpos = status.to_unsigned() & 0x7          # Bits [2:0]
    state = (status.to_unsigned() >> 3) & 0x3     # Bits [4:3]
    mode = (status.to_unsigned() >> 5) & 0x7      # Bits [7:5]
    
    dut._log.info(f"Initial - Tape: {str(tape)}, Mode: {mode}, State: {state}, Head: {headpos}")
    
    assert tape == 0b01011010, f"Expected tape=0b01011010, got {str(tape)}"
    assert mode == 3, f"Expected MODE_RUN (3), got {mode}"
    assert headpos == 0, f"Expected head at position 0, got {headpos}"
    assert state == 0, f"Expected state 0, got {state}"

    # Run for cycles until HALT
    for cycle in range(20):
        await RisingEdge(dut.clk)
        
        tape = dut.uo_out.value
        status = dut.uio_out.value
        
        headpos = status.to_unsigned() & 0x7
        state = (status.to_unsigned() >> 3) & 0x3
        mode = (status.to_unsigned() >> 5) & 0x7
        
        dut._log.info(f"Cycle {cycle:2d}: Tape={str(tape)} Mode={mode} State={state} Head={headpos}")
        
        if mode == 4:  # MODE_HALT
            dut._log.info(f"Machine halted at cycle {cycle}")
            break

    # Final checks
    assert tape == 0b10100101, f"Expected final tape=0b10100101, got {str(tape)}"
    assert mode == 4, f"Expected MODE_HALT (4), got {mode}"

@cocotb.test()
async def test_preset2(dut):
    dut._log.info("Start test_preset2")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0b0_10_0_0_0_0_0  # Auto mode, Preset 2, no swap
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

    dut._log.info("Check preset2 initialization")

    # Use public outputs instead of internal signals
    # uo_out = tape (when swap=0)
    # uio_out = {mode[2:0], state[1:0], headpos[2:0]}
    
    tape = dut.uo_out.value
    status = dut.uio_out.value
    
    # Extract status fields
    headpos = status.to_unsigned() & 0x7          # Bits [2:0]
    state = (status.to_unsigned() >> 3) & 0x3     # Bits [4:3]
    mode = (status.to_unsigned() >> 5) & 0x7      # Bits [7:5]
    
    dut._log.info(f"Initial - Tape: {str(tape)}, Mode: {mode}, State: {state}, Head: {headpos}")
    
    assert tape == 0b10001011, f"Expected tape=0b10001011, got {str(tape)}"
    assert mode == 3, f"Expected MODE_RUN (3), got {mode}"
    assert headpos == 2, f"Expected head at position 2, got {headpos}"
    assert state == 0, f"Expected state 0, got {state}"

    # Run for cycles until HALT
    for cycle in range(40):
        await RisingEdge(dut.clk)
        
        tape = dut.uo_out.value
        status = dut.uio_out.value
        
        headpos = status.to_unsigned() & 0x7
        state = (status.to_unsigned() >> 3) & 0x3
        mode = (status.to_unsigned() >> 5) & 0x7
        
        dut._log.info(f"Cycle {cycle:2d}: Tape={str(tape)} Mode={mode} State={state} Head={headpos}")
        
        if mode == 4:  # MODE_HALT
            dut._log.info(f"Machine halted at cycle {cycle}")
            break

    # Final checks
    assert tape == 0b11110000, f"Expected final tape=0b11110000, got {str(tape)}"
    assert mode == 4, f"Expected MODE_HALT (4), got {mode}"


@cocotb.test()
async def test_custom_stt(dut):
    dut._log.info("Start test_custom_stt")

    # Set the clock period to 10 us (100 KHz)
    clock = Clock(dut.clk, 10, unit="us")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0b1_00_0_0_0_0_0  # Init STT mode, Preset 0, no swap
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 1)
    dut.rst_n.value = 1

    dut._log.info("Write custom STT")

    # Custom STT data (Busy Beaver example from german Wikipedia)
    stt_data = [
        0b0111,  # 
        0b1111,  # 
        0b1001,  # 
        0b0111,  #
        0b1010,  # 
        0b0010,  #
        0b1101,  # halt (go right until end of tape)
        0b1111   # halt (go right until end of tape)
    ]

    for i, entry in enumerate(stt_data):
        dut.ui_in.value = 1 << 7 | ((i & 0x7) << 4 | entry)
        dut._log.info(f"Writing STT entry {i}: {entry:04b}")
        await ClockCycles(dut.clk, 1)
    
    # Switch to SET TAPE
    dut.ui_in.value = 0b0_00_0_0_0_0_0  # Auto mode, Preset 3 (unused), no swap
    await ClockCycles(dut.clk, 1)

    # Set custom tape
    dut.ui_in.value = 0b00111000  
    await ClockCycles(dut.clk, 1) 


    # Set Head Position
    dut.ui_in.value = 0b000_00_001  # Head pos 1
    await ClockCycles(dut.clk, 1)
    
    tape = dut.uo_out.value
    assert tape == 0b00111000, f"Expected tape=0b00111000, got {str(tape)}"

    dut.ui_in.value = 0b01100000  # Head pos 0

    # Run for cycles until HALT
    for cycle in range(20):
        await RisingEdge(dut.clk)
        
        tape = dut.uo_out.value
        status = dut.uio_out.value
        
        headpos = status.to_unsigned() & 0x7
        state = (status.to_unsigned() >> 3) & 0x3
        mode = (status.to_unsigned() >> 5) & 0x7
        
        dut._log.info(f"Cycle {cycle:2d}: Tape={str(tape)} Mode={mode} State={state} Head={headpos}")
        
        if mode == 4:  # MODE_HALT
            dut._log.info(f"Machine halted at cycle {cycle}")
            break

    # Final checks
    assert tape == 0b01111110, f"Expected final tape=0b01111110, got {str(tape)}"
    assert mode == 4, f"Expected MODE_HALT (4), got {mode}"


