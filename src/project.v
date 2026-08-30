```verilog
/*
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_uwasic_onboarding_tise (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,

    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,

    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);


    // ============================================================
    // SPI PIN MAPPING
    //
    // ui_in[0] = SCLK
    // ui_in[1] = COPI
    // ui_in[2] = nCS
    // ============================================================

    wire spi_sclk;
    wire spi_copi;
    wire spi_ncs;

    assign spi_sclk = ui_in[0];
    assign spi_copi = ui_in[1];
    assign spi_ncs  = ui_in[2];


    // ============================================================
    // REGISTER CONNECTIONS
    // ============================================================

    wire [7:0] en_reg_out_7_0;
    wire [7:0] en_reg_out_15_8;

    wire [7:0] en_reg_pwm_7_0;
    wire [7:0] en_reg_pwm_15_8;

    wire [7:0] pwm_duty_cycle;


    // ============================================================
    // SPI PERIPHERAL
    // ============================================================

    spi_peripheral spi_peripheral_inst (

        .clk(clk),
        .rst_n(rst_n),

        .ncs_in(spi_ncs),
        .sclk_in(spi_sclk),
        .copi_in(spi_copi),

        .en_reg_out_7_0(en_reg_out_7_0),
        .en_reg_out_15_8(en_reg_out_15_8),

        .en_reg_pwm_7_0(en_reg_pwm_7_0),
        .en_reg_pwm_15_8(en_reg_pwm_15_8),

        .pwm_duty_cycle(pwm_duty_cycle)

    );


    // ============================================================
    // PWM PERIPHERAL
    // ============================================================

    wire [15:0] peripheral_out;

    pwm_peripheral pwm_peripheral_inst (

        .clk(clk),
        .rst_n(rst_n),

        .en_reg_out_7_0(en_reg_out_7_0),
        .en_reg_out_15_8(en_reg_out_15_8),

        .en_reg_pwm_7_0(en_reg_pwm_7_0),
        .en_reg_pwm_15_8(en_reg_pwm_15_8),

        .pwm_duty_cycle(pwm_duty_cycle),

        .out(peripheral_out)

    );


    // ============================================================
    // OUTPUT CONNECTIONS
    //
    // Lower 8 bits go to uo_out
    // Upper 8 bits go to uio_out
    // ============================================================

    assign uo_out  = peripheral_out[7:0];
    assign uio_out = peripheral_out[15:8];

    // All uio pins are configured as outputs
    assign uio_oe = 8'hFF;


    // ============================================================
    // UNUSED SIGNALS
    // ============================================================

    wire _unused;

    assign _unused = &{
        ena,
        ui_in[7:3],
        uio_in,
        1'b0
    };

endmodule
```
