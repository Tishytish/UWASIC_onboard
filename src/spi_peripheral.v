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

    // Two-stage synchronizers for asynchronous SPI inputs
    reg ncs_meta,  ncs_sync,  ncs_prev;
    reg sclk_meta, sclk_sync, sclk_prev;
    reg copi_meta, copi_sync;

    reg [15:0] shift_reg;

    // Only need to count 0 through 15
    reg [3:0] bit_count;

    wire sclk_rise = sclk_sync & ~sclk_prev;
    wire ncs_rise  = ncs_sync & ~ncs_prev;

    // Word including the bit currently being received
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

            shift_reg       <= 16'h0000;
            bit_count       <= 4'd0;

            en_reg_out_7_0  <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0  <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle  <= 8'h00;

        end else begin

            // Synchronize asynchronous SPI inputs
            ncs_meta  <= ncs_in;
            ncs_sync  <= ncs_meta;
            ncs_prev  <= ncs_sync;

            sclk_meta <= sclk_in;
            sclk_sync <= sclk_meta;
            sclk_prev <= sclk_sync;

            copi_meta <= copi_in;
            copi_sync <= copi_meta;

            // Reset transaction state when CS goes high
            if (ncs_rise) begin
                bit_count <= 4'd0;
                shift_reg <= 16'h0000;
            end

            // Receive SPI bits while CS is low
            if (!ncs_sync && sclk_rise) begin

                // Shift in the new bit
                shift_reg <= received_word;

                // If this is the 16th bit, process the complete word
                if (bit_count == 4'd15) begin

                    // Only perform WRITE operations
                    if (received_word[15]) begin
                        case (received_word[14:8])

                            7'h00:
                                en_reg_out_7_0 <= received_word[7:0];

                            7'h01:
                                en_reg_out_15_8 <= received_word[7:0];

                            7'h02:
                                en_reg_pwm_7_0 <= received_word[7:0];

                            7'h03:
                                en_reg_pwm_15_8 <= received_word[7:0];

                            7'h04:
                                pwm_duty_cycle <= received_word[7:0];

                            // Ignore invalid addresses
                            default: begin
                            end

                        endcase
                    end

                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end

endmodule