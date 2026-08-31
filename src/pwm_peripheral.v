/*
 * Copyright (c) 2024 Damir Gazizullin
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module pwm_peripheral (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] en_reg_out_7_0,
    input  wire [7:0] en_reg_out_15_8,
    input  wire [7:0] en_reg_pwm_7_0,
    input  wire [7:0] en_reg_pwm_15_8,
    input  wire [7:0] pwm_duty_cycle,
    output wire [15:0] out
);

    // 10 MHz / (13 * 256) = 3004.8077 Hz.
    reg [3:0] clk_counter;
    reg [7:0] pwm_counter;

    wire pwm_signal;
    assign pwm_signal = (pwm_duty_cycle == 8'hFF) ? 1'b1 :
                        (pwm_counter < pwm_duty_cycle);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_counter <= 4'd0;
            pwm_counter <= 8'd0;
        end else if (clk_counter == 4'd12) begin
            clk_counter <= 4'd0;
            pwm_counter <= pwm_counter + 1'b1;
        end else begin
            clk_counter <= clk_counter + 1'b1;
        end
    end

    // Vectorized implementation: replace 16 separate conditional assignments
    // with bitwise masking. This substantially reduces synthesized cell usage.
    assign out[7:0]  = en_reg_out_7_0  &
                       (en_reg_pwm_7_0  ? {8{pwm_signal}} : 8'hFF);

    assign out[15:8] = en_reg_out_15_8 &
                       (en_reg_pwm_15_8 ? {8{pwm_signal}} : 8'hFF);

endmodule
