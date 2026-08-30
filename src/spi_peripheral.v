
`default_nettype none

module spi_peripheral (
    input  wire       clk,
    input  wire       rst_n,

    // SPI signals
    input  wire       ncs_in,
    input  wire       sclk_in,
    input  wire       copi_in,

    // Registers controlled by SPI
    output reg [7:0]  en_reg_out_7_0,
    output reg [7:0]  en_reg_out_15_8,
    output reg [7:0]  en_reg_pwm_7_0,
    output reg [7:0]  en_reg_pwm_15_8,
    output reg [7:0]  pwm_duty_cycle
);

    // Valid register addresses: 0x00 through 0x04
    localparam [6:0] MAX_ADDRESS = 7'h04;


    // ============================================================
    // SIGNAL SYNCHRONIZATION
    //
    // SPI signals are asynchronous to clk.
    // Use two-stage synchronizers.
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

            // SPI idle state:
            // nCS = 1
            // SCLK = 0
            // COPI = 0

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
    // EDGE DETECTION
    // ============================================================

    wire sclk_rising;
    wire ncs_rising;

    assign sclk_rising = sclk_sync && !sclk_sync_d;
    assign ncs_rising  = ncs_sync && !ncs_sync_d;


    // ============================================================
    // SPI TRANSACTION STORAGE
    //
    // Transaction format:
    //
    // Bit 15:     R/W
    // Bits 14:8:  Address
    // Bits 7:0:   Data
    //
    // Total = 16 bits
    // ============================================================

    reg [15:0] shift_reg;
    reg [4:0]  bit_count;

    reg        transaction_ready;
    reg        transaction_rw;
    reg [6:0]  transaction_address;
    reg [7:0]  transaction_data;


    // ============================================================
    // MAIN SPI LOGIC
    // ============================================================

    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            // Reset SPI transaction state
            shift_reg <= 16'h0000;
            bit_count <= 5'd0;

            transaction_ready   <= 1'b0;
            transaction_rw      <= 1'b0;
            transaction_address <= 7'h00;
            transaction_data    <= 8'h00;

            // Reset all registers
            en_reg_out_7_0  <= 8'h00;
            en_reg_out_15_8 <= 8'h00;
            en_reg_pwm_7_0  <= 8'h00;
            en_reg_pwm_15_8 <= 8'h00;
            pwm_duty_cycle  <= 8'h00;

        end else begin

            // ====================================================
            // RECEIVE SPI DATA
            //
            // Only receive while nCS is LOW.
            // SPI Mode 0 samples data on SCLK rising edge.
            // ====================================================

            if (!ncs_sync) begin

                if (sclk_rising && bit_count < 16) begin

                    // Shift in the COPI bit
                    shift_reg <= {shift_reg[14:0], copi_sync};

                    // If this is bit number 16, save the transaction
                    if (bit_count == 5'd15) begin

                        transaction_ready <= 1'b1;

                        // At this point:
                        //
                        // shift_reg[14]    = R/W
                        // shift_reg[13:7] = Address
                        // shift_reg[6:0] + copi_sync = Data

                        transaction_rw <= shift_reg[14];

                        transaction_address <= shift_reg[13:7];

                        transaction_data <= {
                            shift_reg[6:0],
                            copi_sync
                        };

                    end

                    bit_count <= bit_count + 1'b1;

                end

            end


            // ====================================================
            // FINALIZE TRANSACTION
            //
            // Only update registers when nCS rises.
            // This prevents partial transactions from updating data.
            // ====================================================

            if (ncs_rising) begin

                if (transaction_ready) begin

                    // Only WRITE transactions update registers
                    if (transaction_rw &&
                        transaction_address <= MAX_ADDRESS) begin

                        case (transaction_address)

                            // Register 0x00
                            7'h00:
                                en_reg_out_7_0 <= transaction_data;

                            // Register 0x01
                            7'h01:
                                en_reg_out_15_8 <= transaction_data;

                            // Register 0x02
                            7'h02:
                                en_reg_pwm_7_0 <= transaction_data;

                            // Register 0x03
                            7'h03:
                                en_reg_pwm_15_8 <= transaction_data;

                            // Register 0x04
                            7'h04:
                                pwm_duty_cycle <= transaction_data;

                            // Invalid addresses do nothing
                            default: begin
                            end

                        endcase

                    end
                end


                // Reset transaction state for next SPI transaction
                shift_reg         <= 16'h0000;
                bit_count         <= 5'd0;
                transaction_ready <= 1'b0;

            end

        end

    end

endmodule
