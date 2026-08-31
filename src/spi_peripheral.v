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

    reg [15:0] shift_reg;
    reg [4:0]  bit_count;

    wire sclk_rise = sclk_sync & ~sclk_prev;
    wire ncs_rise  = ncs_sync  & ~ncs_prev;

    // The complete received word is:
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

            shift_reg        <= 16'h0000;
            bit_count        <= 5'd0;
            en_reg_out_7_0   <= 8'h00;
            en_reg_out_15_8  <= 8'h00;
            en_reg_pwm_7_0   <= 8'h00;
            en_reg_pwm_15_8  <= 8'h00;
            pwm_duty_cycle   <= 8'h00;
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

            // A new transaction starts while CS is low. Capture exactly
            // sixteen bits on synchronized SCLK rising edges.
            if (!ncs_sync) begin
                if (sclk_rise && bit_count < 5'd16) begin
                    shift_reg <= received_word;
                    bit_count <= bit_count + 1'b1;
                end
            end

            // Commit only a complete 16-bit WRITE transaction when CS rises.
            if (ncs_rise) begin
                if (bit_count == 5'd16 && shift_reg[15]) begin
                    case (shift_reg[14:8])
                        7'h00: en_reg_out_7_0  <= shift_reg[7:0];
                        7'h01: en_reg_out_15_8 <= shift_reg[7:0];
                        7'h02: en_reg_pwm_7_0  <= shift_reg[7:0];
                        7'h03: en_reg_pwm_15_8 <= shift_reg[7:0];
                        7'h04: pwm_duty_cycle  <= shift_reg[7:0];
                        default: begin end
                    endcase
                end

                shift_reg <= 16'h0000;
                bit_count <= 5'd0;
            end
        end
    end

endmodule
