`default_nettype none

module spi_peripheral (
    input  wire       clk,
    input  wire       rst_n,

    // Raw asynchronous SPI signals
    input  wire       ncs_in,
    input  wire       sclk_in,
    input  wire       copi_in,

    // Registers controlled by SPI
    output reg [7:0] en_reg_out_7_0,
    output reg [7:0] en_reg_out_15_8,
    output reg [7:0] en_reg_pwm_7_0,
    output reg [7:0] en_reg_pwm_15_8,
    output reg [7:0] pwm_duty_cycle
);

    // Valid addresses are 0x00 through 0x04
    localparam [6:0] MAX_ADDRESS = 7'h04;

    // ============================================================
    // 2-stage synchronizers for asynchronous SPI signals
    // ============================================================

    reg ncs_meta;
    reg ncs_sync;
    reg ncs_sync_d;

    reg sclk_meta;
    reg sclk_sync;
    reg sclk_sync_d;

    reg copi_meta;
    reg copi_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ncs_meta   <= 1'b1;
            ncs_sync   <= 1'b1;
            ncs_sync_d <= 1'b1;

            sclk_meta   <= 1'b0;
            sclk_sync   <= 1'b0;
            sclk_sync_d <= 1'b0;

            copi_meta <= 1'b0;
            copi_sync <= 1'b0;
        end else begin
            // Synchronize nCS
            ncs_meta   <= ncs_in;
            ncs_sync   <= ncs_meta;
            ncs_sync_d <= ncs_sync;

            // Synchronize SCLK
            sclk_meta   <= sclk_in;
            sclk_sync   <= sclk_meta;
            sclk_sync_d <= sclk_sync;

            // Synchronize COPI
            copi_meta <= copi_in;
            copi_sync <= copi_meta;
        end
    end

    // ============================================================
    // Edge detection
    // ============================================================

    wire sclk_rising = (sclk_sync == 1'b1) &&
                       (sclk_sync_d == 1'b0);

    wire ncs_rising = (ncs_sync == 1'b1) &&
                      (ncs_sync_d == 1'b0);

    // ============================================================
    // SPI transaction storage
    // Format:
    //
    // Bit 15:    R/W
    // Bits 14:8: Address
    // Bits 7:0:  Data
    //
    // SPI mode 0: capture COPI on rising edge of SCLK
    // ============================================================

    reg [15:0] shift_reg;
    reg [4:0]  bit_count;
    reg        transaction_ready;

    reg        transaction_rw;
    reg [6:0]  transaction_address;
    reg [7:0]  transaction_data;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin

            shift_reg <= 16'h0000;
            bit_count <= 5'd0;

            transaction_ready   <= 1'b0;
            transaction_rw      <= 1'b0;
            transaction_address <= 7'h00;
            transaction_data    <= 8'h00;

            // Reset all peripheral registers
            en_reg_out_7_0  <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0  <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle  <= 8'h00;

        end else begin

            // ----------------------------------------------------
            // While chip select is low, receive the transaction
            // ----------------------------------------------------
            if (!ncs_sync) begin

                // Capture data on SCLK rising edge
                if (sclk_rising && bit_count < 16) begin

                    shift_reg <= {shift_reg[14:0], copi_sync};
                    bit_count <= bit_count + 1'b1;

                    // This is the 16th bit
                    if (bit_count == 5'd15) begin
                        transaction_ready <= 1'b1;

                        // Use the completed shift value,
                        // including the COPI bit being received now.
                        transaction_rw <= shift_reg[14];

                        transaction_address <= shift_reg[13:7];

                        transaction_data <= {
                            shift_reg[6:0],
                            copi_sync
                        };
                    end
                end

            end

            // ----------------------------------------------------
            // Finalize transaction when nCS goes high
            // ----------------------------------------------------
            if (ncs_rising) begin

                if (transaction_ready) begin

                    // Only WRITE transactions update registers
                    // and only valid addresses are accepted.
                    if (transaction_rw &&
                        transaction_address <= MAX_ADDRESS) begin

                        case (transaction_address)

                            7'h00:
                                en_reg_out_7_0 <= transaction_data;

                            7'h01:
                                en_reg_out_15_8 <= transaction_data;

                            7'h02:
                                en_reg_pwm_7_0 <= transaction_data;

                            7'h03:
                                en_reg_pwm_15_8 <= transaction_data;

                            7'h04:
                                pwm_duty_cycle <= transaction_data;

                            default: begin
                                // Invalid addresses do nothing
                            end

                        endcase
                    end
                end

                // Prepare for the next transaction
                shift_reg          <= 16'h0000;
                bit_count          <= 5'd0;
                transaction_ready  <= 1'b0;
            end
        end
    end

endmodule