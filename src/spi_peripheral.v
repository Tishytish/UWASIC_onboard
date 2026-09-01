`default_nettype none

module spi_peripheral (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ncs_in,
    input  wire       sclk_in,
    input  wire       copi_in,

    output reg [7:0]  en_reg_out_7_0,
    output reg [7:0]  en_reg_out_15_8,
    output reg [7:0]  en_reg_pwm_7_0,
    output reg [7:0]  en_reg_pwm_15_8,
    output reg [7:0]  pwm_duty_cycle
);

    // Two-stage synchronizers for asynchronous SPI inputs.
    reg ncs_meta,  ncs_sync,  ncs_prev;
    reg sclk_meta, sclk_sync, sclk_prev;
    reg copi_meta, copi_sync;

    // Only 15 stored bits are needed because the current COPI bit
    // completes the 16-bit received word.
    reg [14:0] shift_reg;

    // Count from 0 to 15 only.
    reg [3:0] bit_count;

    wire sclk_rise = sclk_sync & ~sclk_prev;
    wire ncs_rise  = ncs_sync  & ~ncs_prev;

    // Complete received word:
    // {R/W, address[6:0], data[7:0]}
    wire [15:0] received_word = {shift_reg[14:0], copi_sync};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ncs_meta  <= 1'b1;
            ncs_sync  <= 1'b1;
            ncs_prev  <= 1'b1;

            sclk_meta <= 1'b0;
            sclk_sync <= 1'b0;
            sclk_prev <= 1'b0;

            copi_meta <= 1'b0;
            copi_sync <= 1'b0;

            shift_reg       <= 15'h0000;
            bit_count       <= 4'd0;

            en_reg_out_7_0  <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0  <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle  <= 8'h00;

        end else begin

            // Synchronize inputs and retain one delayed synchronized copy
            // for edge detection.
            ncs_meta  <= ncs_in;
            ncs_sync  <= ncs_meta;
            ncs_prev  <= ncs_sync;

            sclk_meta <= sclk_in;
            sclk_sync <= sclk_meta;
            sclk_prev <= sclk_sync;

            copi_meta <= copi_in;
            copi_sync <= copi_meta;

            // Capture SPI bits while CS is low.
            if (!ncs_sync && sclk_rise) begin

                // The 16th bit completes the transaction.
                if (bit_count == 4'd15) begin

                    // Commit a complete 16-bit WRITE transaction.
                    if (received_word[15]) begin
                        case (received_word[14:8])
                            7'h00: en_reg_out_7_0  <= received_word[7:0];
                            7'h01: en_reg_out_15_8 <= received_word[7:0];
                            7'h02: en_reg_pwm_7_0  <= received_word[7:0];
                            7'h03: en_reg_pwm_15_8 <= received_word[7:0];
                            7'h04: pwm_duty_cycle  <= received_word[7:0];
                            default: begin end
                        endcase
                    end

                end else begin
                    // Store the received bits and continue counting.
                    shift_reg <= received_word[14:0];
                    bit_count <= bit_count + 1'b1;
                end
            end

            // Reset transaction state when CS rises.
            if (ncs_rise) begin
                shift_reg <= 15'h0000;
                bit_count <= 4'd0;
            end
        end
    end

endmodule