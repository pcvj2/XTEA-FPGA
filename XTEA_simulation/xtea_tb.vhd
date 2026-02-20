--########################################################################################
--## Design name: xtea (duplex)                                                         ##
--## Module name: xtea_tb - Testbench                                                   ##
--## Target devices: Altera DE1-SoC (Cyclone V)                                        ##
--## Tool versions: Quartus Prime, GHDL                                                 ##
--##                                                                                    ##
--## Description: XTEA encryption/decryption core testbench. Tests multiple key/data   ##
--## pairs by:                                                                          ##
--##   1. Encrypting plaintext and comparing against known expected ciphertext          ##
--##   2. Decrypting the ciphertext and verifying it recovers the original plaintext    ##
--########################################################################################

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY xtea_tb IS
END ENTITY xtea_tb;

ARCHITECTURE tb OF xtea_tb IS

    COMPONENT xtea_top_duplex IS
        PORT(
            clk                 : IN  STD_LOGIC;
            reset_n             : IN  STD_LOGIC;
            data_word_in        : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            data_valid          : IN  STD_LOGIC;
            ciphertext_word_in  : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            ciphertext_valid    : IN  STD_LOGIC;
            key_word_in         : IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
            key_valid           : IN  STD_LOGIC;
            key_ready           : OUT STD_LOGIC;
            ciphertext_word_out : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            ciphertext_ready    : OUT STD_LOGIC;
            data_word_out       : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            data_ready          : OUT STD_LOGIC
        );
    END COMPONENT xtea_top_duplex;

    CONSTANT clk_period : TIME    := 10 ns;
    CONSTANT num_keys   : INTEGER := 3;

    SIGNAL clk                 : STD_LOGIC;
    SIGNAL reset_n             : STD_LOGIC;
    SIGNAL plaintext_in_data   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL plaintext_in_flag   : STD_LOGIC;
    SIGNAL ciphertext_in_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL ciphertext_in_flag  : STD_LOGIC;
    SIGNAL key_in_data         : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL key_in_flag         : STD_LOGIC;
    SIGNAL key_ready_flag      : STD_LOGIC;
    SIGNAL ciphertext_out_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL ciphertext_out_flag : STD_LOGIC;
    SIGNAL plaintext_out_data  : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL plaintext_out_flag  : STD_LOGIC;

    TYPE key_data_array_t IS ARRAY (0 TO num_keys-1) OF STD_LOGIC_VECTOR(127 DOWNTO 0);

    SIGNAL xtea_keys : key_data_array_t := (
        0 => x"DEADBEEF0123456789ABCDEFDEADBEEF",
        1 => x"73467723465348589734637824782378",
        2 => x"ABCDEFABCDEFABCDEFABCDEFABCDEFAB"
    );

    SIGNAL input_data : key_data_array_t := (
        0 => x"A5A5A5A501234567FEDCBA985A5A5A5A",
        1 => x"FEDCBAFEDCBAFEDCBAFEDCBAFEDCBAFE",
        2 => x"46893489237894238964623812300325"
    );

    -- Known-good expected ciphertexts (verified against reference C implementation)
    SIGNAL expected_cipher : key_data_array_t := (
        0 => x"7409807BCC3B0E759EFD53A8AEA16A76",
        1 => x"484CB4ADE7DA7886B262FE21701DF2B2",
        2 => x"5DD6C1FDAAC5F0934C20AC7E68E3D758"
    );

    SIGNAL encrypted_data : STD_LOGIC_VECTOR(127 DOWNTO 0);
    SIGNAL decrypted_data : STD_LOGIC_VECTOR(127 DOWNTO 0);

BEGIN

    DUT : xtea_top_duplex
    PORT MAP(
        clk                 => clk,
        reset_n             => reset_n,
        data_word_in        => plaintext_in_data,
        data_valid          => plaintext_in_flag,
        ciphertext_word_in  => ciphertext_in_data,
        ciphertext_valid    => ciphertext_in_flag,
        key_word_in         => key_in_data,
        key_valid           => key_in_flag,
        key_ready           => key_ready_flag,
        ciphertext_word_out => ciphertext_out_data,
        ciphertext_ready    => ciphertext_out_flag,
        data_word_out       => plaintext_out_data,
        data_ready          => plaintext_out_flag
    );

    clk_proc : PROCESS
    BEGIN
        clk <= '1'; WAIT FOR clk_period/2;
        clk <= '0'; WAIT FOR clk_period/2;
    END PROCESS clk_proc;

    stim_proc : PROCESS
        VARIABLE fail_flag    : STD_LOGIC;
        VARIABLE fail_counter : INTEGER;

        PROCEDURE reset_dut IS
        BEGIN
            reset_n            <= '0';
            plaintext_in_flag  <= '0';
            plaintext_in_data  <= (OTHERS => '0');
            ciphertext_in_flag <= '0';
            ciphertext_in_data <= (OTHERS => '0');
            key_in_flag        <= '0';
            key_in_data        <= (OTHERS => '0');
            WAIT FOR clk_period*2;
            reset_n <= '1';
            WAIT FOR clk_period;
        END PROCEDURE reset_dut;

    BEGIN
        reset_dut;
        fail_flag    := '0';
        fail_counter := 0;
        encrypted_data <= (OTHERS => '0');
        decrypted_data <= (OTHERS => '0');

        FOR i IN 0 TO num_keys-1 LOOP
            -- Send key
            WAIT UNTIL FALLING_EDGE(clk);
            key_in_flag <= '1';
            key_in_data <= xtea_keys(i)(127 DOWNTO 96); WAIT FOR clk_period;
            key_in_data <= xtea_keys(i)(95 DOWNTO 64);  WAIT FOR clk_period;
            key_in_data <= xtea_keys(i)(63 DOWNTO 32);  WAIT FOR clk_period;
            key_in_data <= xtea_keys(i)(31 DOWNTO 0);   WAIT FOR clk_period;
            key_in_flag <= '0';
            key_in_data <= (OTHERS => '0');
            WAIT UNTIL key_ready_flag = '1';

            -- Send plaintext
            WAIT UNTIL FALLING_EDGE(clk);
            plaintext_in_flag <= '1';
            plaintext_in_data <= input_data(i)(127 DOWNTO 96); WAIT FOR clk_period;
            plaintext_in_data <= input_data(i)(95 DOWNTO 64);  WAIT FOR clk_period;
            plaintext_in_data <= input_data(i)(63 DOWNTO 32);  WAIT FOR clk_period;
            plaintext_in_data <= input_data(i)(31 DOWNTO 0);   WAIT FOR clk_period;
            plaintext_in_flag <= '0';
            plaintext_in_data <= (OTHERS => '0');

            -- Capture ciphertext
            WAIT UNTIL ciphertext_out_flag = '1';
            WAIT UNTIL FALLING_EDGE(clk);
            encrypted_data(127 DOWNTO 96) <= ciphertext_out_data; WAIT FOR clk_period;
            encrypted_data(95 DOWNTO 64)  <= ciphertext_out_data; WAIT FOR clk_period;
            encrypted_data(63 DOWNTO 32)  <= ciphertext_out_data; WAIT FOR clk_period;
            encrypted_data(31 DOWNTO 0)   <= ciphertext_out_data; WAIT FOR clk_period;

            -- Check ciphertext against known expected value
            WAIT FOR clk_period;
            IF encrypted_data = expected_cipher(i) THEN
                REPORT "NOTE: Key/data pair " & INTEGER'IMAGE(i+1) & " encryption correct" SEVERITY NOTE;
            ELSE
                REPORT "ERROR: Key/data pair " & INTEGER'IMAGE(i+1) & " encryption FAILED" SEVERITY ERROR;
                fail_flag    := '1';
                fail_counter := fail_counter + 1;
            END IF;

            -- Send ciphertext to decrypter
            WAIT UNTIL FALLING_EDGE(clk);
            ciphertext_in_flag <= '1';
            ciphertext_in_data <= encrypted_data(127 DOWNTO 96); WAIT FOR clk_period;
            ciphertext_in_data <= encrypted_data(95 DOWNTO 64);  WAIT FOR clk_period;
            ciphertext_in_data <= encrypted_data(63 DOWNTO 32);  WAIT FOR clk_period;
            ciphertext_in_data <= encrypted_data(31 DOWNTO 0);   WAIT FOR clk_period;
            ciphertext_in_flag <= '0';
            ciphertext_in_data <= (OTHERS => '0');

            -- Capture decrypted output
            WAIT UNTIL plaintext_out_flag = '1';
            WAIT UNTIL FALLING_EDGE(clk);
            decrypted_data(127 DOWNTO 96) <= plaintext_out_data; WAIT FOR clk_period;
            decrypted_data(95 DOWNTO 64)  <= plaintext_out_data; WAIT FOR clk_period;
            decrypted_data(63 DOWNTO 32)  <= plaintext_out_data; WAIT FOR clk_period;
            decrypted_data(31 DOWNTO 0)   <= plaintext_out_data; WAIT FOR clk_period;

            -- Check round-trip
            WAIT FOR clk_period;
            IF decrypted_data = input_data(i) THEN
                REPORT "NOTE: Key/data pair " & INTEGER'IMAGE(i+1) & " round-trip correct" SEVERITY NOTE;
            ELSE
                REPORT "ERROR: Key/data pair " & INTEGER'IMAGE(i+1) & " round-trip FAILED" SEVERITY ERROR;
                fail_flag    := '1';
                fail_counter := fail_counter + 1;
            END IF;

        END LOOP;

        IF fail_flag = '0' THEN
            REPORT "NOTE: All tests passed" SEVERITY NOTE;
        ELSE
            REPORT "ERROR: " & INTEGER'IMAGE(fail_counter) & " tests failed" SEVERITY ERROR;
        END IF;

        WAIT;
    END PROCESS stim_proc;

END tb;
