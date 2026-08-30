```python
# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb

from cocotb.clock import Clock
from cocotb.triggers import (
    RisingEdge,
    FallingEdge,
    ClockCycles
)

from cocotb.types import LogicArray


# ============================================================
# SPI HELPER FUNCTIONS
# ============================================================

async def await_half_sclk(dut):
    """
    Wait for half of the SPI clock period.

    The system clock is 10 MHz = 100 ns period.
    This waits approximately 5 us.
    """

    start_time = cocotb.utils.get_sim_time(units="ns")

    while True:

        await ClockCycles(dut.clk, 1)

        if (
            start_time + 100 * 100 * 0.5
            < cocotb.utils.get_sim_time(units="ns")
        ):
            break


def ui_in_logicarray(ncs, bit, sclk):
    """
    Create ui_in.

    ui_in[2] = nCS
    ui_in[1] = COPI
    ui_in[0] = SCLK
    """

    return LogicArray(f"00000{ncs}{bit}{sclk}")


async def send_spi_transaction(dut, r_w, address, data):
    """
    Send a complete 16-bit SPI transaction.

    Transaction format:

        1 bit  = R/W
        7 bits = Address
        8 bits = Data

    SPI Mode 0:
        - COPI changes while SCLK is LOW
        - COPI is sampled on SCLK rising edge
    """

    # Convert LogicArray to integer if needed
    if isinstance(data, LogicArray):
        data_int = int(data)
    else:
        data_int = data


    # Validate inputs
    if address < 0 or address > 127:
        raise ValueError("Address must be between 0 and 127")

    if data_int < 0 or data_int > 255:
        raise ValueError("Data must be between 0 and 255")


    # First byte = R/W + 7-bit address
    first_byte = (int(r_w) << 7) | address


    # ============================================================
    # START TRANSACTION
    # ============================================================

    ncs = 0
    sclk = 0
    bit = 0

    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)

    # Give synchronizers time to recognize nCS LOW
    await ClockCycles(dut.clk, 5)


    # ============================================================
    # SEND R/W + ADDRESS
    # ============================================================

    for i in range(8):

        bit = (first_byte >> (7 - i)) & 0x1

        # SCLK LOW: set data
        sclk = 0
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)

        await await_half_sclk(dut)

        # SCLK HIGH: SPI peripheral samples data
        sclk = 1
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)

        await await_half_sclk(dut)


    # ============================================================
    # SEND DATA
    # ============================================================

    for i in range(8):

        bit = (data_int >> (7 - i)) & 0x1

        # SCLK LOW: set data
        sclk = 0
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)

        await await_half_sclk(dut)

        # SCLK HIGH: SPI peripheral samples data
        sclk = 1
        dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)

        await await_half_sclk(dut)


    # ============================================================
    # END TRANSACTION
    # ============================================================

    sclk = 0
    ncs = 1
    bit = 0

    dut.ui_in.value = ui_in_logicarray(ncs, bit, sclk)

    # Allow synchronizer + transaction finalization
    await ClockCycles(dut.clk, 600)


# ============================================================
# RESET HELPER
# ============================================================

async def reset_dut(dut):
    """
    Reset the design.
    """

    dut.ena.value = 1

    # SPI idle state:
    # nCS = 1
    # COPI = 0
    # SCLK = 0

    dut.ui_in.value = ui_in_logicarray(1, 0, 0)

    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 10)


# ============================================================
# SECTION 6 TEST — SPI
# ============================================================

@cocotb.test()
async def test_spi(dut):

    dut._log.info("==============================")
    dut._log.info("STARTING SPI TEST")
    dut._log.info("==============================")


    # Start 10 MHz system clock
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())


    # Reset DUT
    await reset_dut(dut)


    # ========================================================
    # TEST REGISTER 0x00
    # ========================================================

    dut._log.info("Writing 0xF0 to address 0x00")

    await send_spi_transaction(
        dut,
        1,
        0x00,
        0xF0
    )

    assert int(dut.uo_out.value) == 0xF0, (
        f"Expected 0xF0, got {dut.uo_out.value}"
    )


    # ========================================================
    # TEST REGISTER 0x01
    # ========================================================

    dut._log.info("Writing 0xCC to address 0x01")

    await send_spi_transaction(
        dut,
        1,
        0x01,
        0xCC
    )

    assert int(dut.uio_out.value) == 0xCC, (
        f"Expected 0xCC, got {dut.uio_out.value}"
    )


    # ========================================================
    # INVALID ADDRESS
    # ========================================================

    dut._log.info("Testing invalid address 0x30")

    await send_spi_transaction(
        dut,
        1,
        0x30,
        0xAA
    )

    # Output should remain unchanged
    assert int(dut.uo_out.value) == 0xF0, (
        "Invalid address changed uo_out"
    )


    # ========================================================
    # READ TRANSACTION
    # ========================================================

    dut._log.info("Testing read transaction")

    await send_spi_transaction(
        dut,
        0,
        0x00,
        0xBE
    )

    # Read should NOT modify register
    assert int(dut.uo_out.value) == 0xF0, (
        "Read transaction modified uo_out"
    )


    dut._log.info("==============================")
    dut._log.info("SPI TEST PASSED")
    dut._log.info("==============================")


# ============================================================
# SECTION 7 TEST — PWM FREQUENCY
# ============================================================

@cocotb.test()
async def test_pwm_freq(dut):

    dut._log.info("==============================")
    dut._log.info("STARTING PWM FREQUENCY TEST")
    dut._log.info("==============================")


    # Start 10 MHz clock
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())


    # Reset DUT
    await reset_dut(dut)


    # ========================================================
    # CONFIGURE PWM
    #
    # Register 0x00:
    # Enable output bit 0
    # ========================================================

    await send_spi_transaction(
        dut,
        1,
        0x00,
        0x01
    )


    # Register 0x02:
    # Enable PWM on bit 0

    await send_spi_transaction(
        dut,
        1,
        0x02,
        0x01
    )


    # Register 0x04:
    # Set approximately 50% duty cycle

    await send_spi_transaction(
        dut,
        1,
        0x04,
        0x80
    )


    # Give PWM time to run
    await ClockCycles(dut.clk, 1000)


    # ========================================================
    # MEASURE PERIOD
    # ========================================================

    # First rising edge
    await RisingEdge(dut.uo_out[0])

    rising_time_1 = cocotb.utils.get_sim_time(
        units="ns"
    )


    # Second rising edge
    await RisingEdge(dut.uo_out[0])

    rising_time_2 = cocotb.utils.get_sim_time(
        units="ns"
    )


    # Calculate period
    period_ns = rising_time_2 - rising_time_1


    # Frequency = 1 / period
    frequency_hz = 1_000_000_000 / period_ns


    dut._log.info(
        f"PWM Period: {period_ns} ns"
    )

    dut._log.info(
        f"PWM Frequency: {frequency_hz:.2f} Hz"
    )


    # Required:
    # 3000 Hz ± 1%
    #
    # Acceptable:
    # 2970 Hz to 3030 Hz

    assert 2970 <= frequency_hz <= 3030, (
        f"Frequency {frequency_hz:.2f} Hz "
        "is outside the allowed range"
    )


    dut._log.info("==============================")
    dut._log.info("PWM FREQUENCY TEST PASSED")
    dut._log.info("==============================")


# ============================================================
# SECTION 7 TEST — PWM DUTY CYCLE
# ============================================================

@cocotb.test()
async def test_pwm_duty(dut):

    dut._log.info("==============================")
    dut._log.info("STARTING PWM DUTY CYCLE TEST")
    dut._log.info("==============================")


    # Start 10 MHz clock
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())


    # Reset DUT
    await reset_dut(dut)


    # ========================================================
    # ENABLE OUTPUT BIT 0
    # ========================================================

    await send_spi_transaction(
        dut,
        1,
        0x00,
        0x01
    )


    # ========================================================
    # ENABLE PWM ON BIT 0
    # ========================================================

    await send_spi_transaction(
        dut,
        1,
        0x02,
        0x01
    )


    # ========================================================
    # TEST 0% DUTY CYCLE
    #
    # pwm_duty_cycle = 0x00
    # Output should always be LOW
    # ========================================================

    dut._log.info("Testing 0% duty cycle")

    await send_spi_transaction(
        dut,
        1,
        0x04,
        0x00
    )


    # Wait longer than one PWM period
    await ClockCycles(dut.clk, 5000)


    assert int(dut.uo_out[0].value) == 0, (
        "Expected PWM output LOW at 0% duty cycle"
    )


    dut._log.info("0% DUTY CYCLE PASSED")


    # ========================================================
    # TEST 50% DUTY CYCLE
    #
    # 0x80 = 128
    # 128 / 256 = 50%
    # ========================================================

    dut._log.info("Testing 50% duty cycle")

    await send_spi_transaction(
        dut,
        1,
        0x04,
        0x80
    )


    # Wait for beginning of PWM HIGH period
    await RisingEdge(dut.uo_out[0])

    rising_time = cocotb.utils.get_sim_time(
        units="ns"
    )


    # Wait for PWM to go LOW
    await FallingEdge(dut.uo_out[0])

    falling_time = cocotb.utils.get_sim_time(
        units="ns"
    )


    # Wait for next PWM cycle
    await RisingEdge(dut.uo_out[0])

    next_rising_time = cocotb.utils.get_sim_time(
        units="ns"
    )


    # Calculate high time
    high_time = falling_time - rising_time


    # Calculate complete period
    period = next_rising_time - rising_time


    # Calculate duty cycle percentage
    duty_cycle_percent = (
        high_time / period
    ) * 100


    dut._log.info(
        f"High time: {high_time} ns"
    )

    dut._log.info(
        f"Period: {period} ns"
    )

    dut._log.info(
        f"Measured duty cycle: "
        f"{duty_cycle_percent:.2f}%"
    )


    # Required:
    # 50% ± 1%

    assert 49 <= duty_cycle_percent <= 51, (
        f"Expected approximately 50%, "
        f"got {duty_cycle_percent:.2f}%"
    )


    dut._log.info("50% DUTY CYCLE PASSED")


    # ========================================================
    # TEST 100% DUTY CYCLE
    #
    # 0xFF = always HIGH
    # ========================================================

    dut._log.info("Testing 100% duty cycle")

    await send_spi_transaction(
        dut,
        1,
        0x04,
        0xFF
    )


    # Wait longer than one complete PWM period
    await ClockCycles(dut.clk, 5000)


    assert int(dut.uo_out[0].value) == 1, (
        "Expected PWM output HIGH at 100% duty cycle"
    )


    dut._log.info("100% DUTY CYCLE PASSED")


    dut._log.info("==============================")
    dut._log.info("PWM DUTY CYCLE TEST PASSED")
    dut._log.info("==============================")
```
