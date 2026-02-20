// -----------------------------------------------------------------------------
// ip_enc_gen
// -------------
// This module generates a fixed 128-bit plaintext and transmits it one byte
// at a time over a 10-bit interface. Each 8-bit data byte is prepended with a
// 2-bit "priority" tag (count[1:0]) to simulate tagged streaming data.
//
// Transmission starts automatically after reset and stops after 16 bytes.
// -----------------------------------------------------------------------------

module ip_enc_gen (
    input  logic       clk,
    input  logic       reset,
    output logic [9:0] data_out,
    output logic       req
);

    // Predefined plaintext message:
    // 0xA5A5A5A5_01234567_FEDCBA98_5A5A5A5A (128 bits)
    logic [127:0] plaintext;
    logic [3:0]   count;
    logic         active;

    always_ff @(posedge clk) begin
        if (reset) begin
            // Initialize all signals and load plaintext
            plaintext <= 128'hA5A5A5A501234567FEDCBA985A5A5A5A;
            count     <= 0;
            req       <= 0;
            data_out  <= 10'b0;
            active    <= 1; // Begin sending on reset
        end else begin
            if (active) begin
                if (count < 16) begin
                    // Send MSB first, 8 bits at a time with 2-bit priority tag
                    // Format: {priority[1:0], data[7:0]}
                    data_out <= {count[1:0], plaintext[127 - 8*count -: 8]};
                    req      <= 1;
                    count    <= count + 1;
                end else begin
                    // Transmission complete
                    req    <= 0;
                    active <= 0;
                end
            end else begin
                // Remain idle
                req <= 0;
            end
        end
    end

endmodule

