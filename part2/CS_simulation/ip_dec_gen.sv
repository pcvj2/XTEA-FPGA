// -----------------------------------------------------------------------------
// ip_dec_gen
// -------------
// This module acts as a test data generator for a decryption engine.
// It transmits a predefined 128-bit ciphertext, one byte at a time,
// over a 10-bit output interface (8-bit data + 2-bit priority).
//
// Each byte is tagged with a 2-bit rotating "priority" prefix: count[1:0].
// Transmission begins automatically upon reset and completes after 16 bytes.
// -----------------------------------------------------------------------------

module ip_dec_gen (
    input  logic       clk,
    input  logic       reset,
    output logic [9:0] data_out,
    output logic       req
);

    // Ciphertext: 0x089975E9_2555F334_CE76E4F2_4D932AB3 (128 bits)
    logic [127:0] ciphertext;

    logic [3:0]   count;    // Byte index counter (0 to 15)
    logic         active;   // Active flag: high when sending data


    always_ff @(posedge clk) begin
        if (reset) begin
            // Initialize values and load ciphertext
            ciphertext <= 128'h089975E92555F334CE76E4F24D932AB3;
            count      <= 0;
            req        <= 0;
            data_out   <= 10'b0;
            active     <= 1;    // Start sending immediately after reset
        end else if (active) begin
            if (count < 16) begin
                // Extract 8-bit chunk from MSB to LSB and add 2-bit priority prefix
                data_out <= {count[1:0], ciphertext[127 - 8*count -: 8]};
                req      <= 1;
                count    <= count + 1;
            end else begin
                // All bytes sent — deactivate
                req    <= 0;
                active <= 0;
            end
        end else begin
            // Idle state: no valid output
            req <= 0;
        end
    end

endmodule

