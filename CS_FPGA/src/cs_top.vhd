library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- cs_top
-- -----------------------------------------------------------------------------
-- Top-level control system integrating:
-- - Two data generators (ip_enc_gen, ip_dec_gen),
-- - A mini_router for arbitration,
-- - An XTEA duplex encrypt/decrypt unit.
--
-- The system:
-- 1. Routes bytewise data into a 128-bit buffer via the router.
-- 2. Sends the buffer to the XTEA encryption unit.
-- 3. Buffers the ciphertext.
-- 4. Sends the ciphertext to the XTEA decryption path.
-- 5. Outputs the decrypted block on completion.
-- =============================================================================

entity cs_top is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        decrypted_block : out std_logic_vector(127 downto 0)
    );
end cs_top;

architecture arch of cs_top is

    -- Signals between input generators and the router
    signal data1      : std_logic_vector(9 downto 0);
    signal req1       : std_logic;
    signal grant1     : std_logic;

    signal data2      : std_logic_vector(9 downto 0);
    signal req2       : std_logic;
    signal grant2     : std_logic;

    -- Router output
    signal router_data_out : std_logic_vector(7 downto 0);
    signal router_valid    : std_logic;

    -- 128-bit block assembly buffer
    signal data_buffer     : std_logic_vector(127 downto 0);
    signal byte_count      : integer range 0 to 15 := 0;
    signal block_ready     : std_logic := '0';
    signal block_consumed  : std_logic := '0';

    -- Encryption key feeding
    signal full_key        : std_logic_vector(127 downto 0) := x"DEADBEEF0123456789ABCDEFDEADBEEF";
    signal key_index       : integer range 0 to 3 := 0;
    signal key_valid       : std_logic := '0';
    signal key_sent        : std_logic := '0';

    -- Plaintext feeding signals
    signal data_word_mux   : std_logic_vector(31 downto 0);
    signal data_word_in    : std_logic_vector(31 downto 0);
    signal data_valid      : std_logic := '0';
    signal data_index      : integer range 0 to 3 := 0;
    signal feeding_data    : std_logic := '0';
    signal feeding_counter : integer range 0 to 3 := 0;

    -- Encryption output from XTEA
    signal ciphertext_word_out : std_logic_vector(31 downto 0);
    signal ciphertext_ready    : std_logic;

    -- Ciphertext buffering for decryption
    signal cipher_buffer       : std_logic_vector(127 downto 0);
    signal cipher_index        : integer range 0 to 3 := 0;

    -- Ciphertext feeding for decryption
    signal feeding_ciphertext : std_logic := '0';
    signal decrypt_index      : integer range 0 to 3 := 0;
    signal ciphertext_valid   : std_logic := '0';
    signal ciphertext_word_in : std_logic_vector(31 downto 0) := (others => '0');

    -- Decryption output
    signal data_word_out : std_logic_vector(31 downto 0);
    signal data_ready    : std_logic;
    signal dec_buffer    : std_logic_vector(127 downto 0) := (others => '0');
    signal dec_index     : integer range 0 to 3 := 0;

    -- Adapter signal for active-high reset needed by Verilog modules
    signal reset_active_high : std_logic;


     -- Component declarations

    component ip_enc_gen
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            data_out  : out std_logic_vector(9 downto 0);
            req       : out std_logic
        );
    end component;

    component ip_dec_gen
        port (
            clk       : in  std_logic;
            reset     : in  std_logic;
            data_out  : out std_logic_vector(9 downto 0);
            req       : out std_logic
        );
    end component;

begin

    -- Convert active-low to active-high reset for Verilog IP
    reset_active_high <= not reset;

    -- IP generator instantiations
    ip_gen_enc: ip_enc_gen
        port map (
            clk => clk,
            reset => reset_active_high,
            data_out => data1,
            req => req1
        );

    ip_gen_dec: ip_dec_gen
        port map (
            clk => clk,
            reset => reset_active_high,
            data_out => data2,
            req => req2
        );

    -- Instantiate round-robin priority router
    router_inst: entity work.mini_router
        port map (
            clk      => clk,
            reset    => reset,
            data1    => data1,
            req1     => req1,
            grant1   => grant1,
            data2    => data2,
            req2     => req2,
            grant2   => grant2,
            data_out => router_data_out,
            valid    => router_valid
        );

    -- ========== Assemble 128-bit block from router input ==========    
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                byte_count <= 0;
                data_buffer <= (others => '0');
                block_ready <= '0';
                block_consumed <= '0';
            elsif router_valid = '1' and block_ready = '0' then
                data_buffer(8*(15 - byte_count) + 7 downto 8*(15 - byte_count)) <= router_data_out;
                if byte_count = 15 then
                    block_ready <= '1';
                    byte_count  <= 0;
                else
                    byte_count <= byte_count + 1;
                end if;
            elsif block_consumed = '1' then
                block_ready <= '0';
                block_consumed <= '0';
            end if;
        end if;
    end process;

    -- ========== Feed 128-bit key into encryption ==========
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                key_index <= 0;
                key_valid <= '0';
                key_sent  <= '0';
            elsif key_sent = '0' then
                key_valid <= '1';
                if key_index < 3 then
                    key_index <= key_index + 1;
                else
                    key_valid <= '0';
                    key_sent <= '1';
                end if;
            end if;
        end if;
    end process;

    -- ========== Feed plaintext block into encryption ==========
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                data_valid       <= '0';
                data_index       <= 0;
                feeding_data     <= '0';
                feeding_counter  <= 0;
            elsif block_ready = '1' and feeding_data = '0' then
                feeding_data <= '1';
                feeding_counter <= 0;
            elsif feeding_data = '1' then
                data_valid <= '1';
                if feeding_counter < 3 then
                    feeding_counter <= feeding_counter + 1;
                else
                    feeding_data <= '0';
                    block_consumed <= '1';
                end if;
            else
                data_valid <= '0';
            end if;
        end if;
    end process;


    -- ========== Multiplexer for key and data feeding ==========
    data_word_mux <=
        full_key(127 downto 96) when key_valid = '1' and key_index = 0 else
        full_key(95 downto 64)  when key_valid = '1' and key_index = 1 else
        full_key(63 downto 32)  when key_valid = '1' and key_index = 2 else
        full_key(31 downto 0)   when key_valid = '1' and key_index = 3 else
        data_buffer(127 downto 96) when data_valid = '1' and feeding_counter = 0 else
        data_buffer(95 downto 64)  when data_valid = '1' and feeding_counter = 1 else
        data_buffer(63 downto 32)  when data_valid = '1' and feeding_counter = 2 else
        data_buffer(31 downto 0)   when data_valid = '1' and feeding_counter = 3 else
        (others => '0');

    data_word_in <= data_word_mux;


    -- ========== Feed encrypted ciphertext into decryption path ==========        
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                feeding_ciphertext <= '0';
                decrypt_index      <= 0;
                ciphertext_valid   <= '0';
            elsif cipher_index = 0 and feeding_ciphertext = '0' then
                feeding_ciphertext <= '1';
                decrypt_index <= 0;
            elsif feeding_ciphertext = '1' then
                ciphertext_valid <= '1';
                case decrypt_index is
                    when 0 => ciphertext_word_in <= cipher_buffer(127 downto 96);
                    when 1 => ciphertext_word_in <= cipher_buffer(95 downto 64);
                    when 2 => ciphertext_word_in <= cipher_buffer(63 downto 32);
                    when 3 =>
                        ciphertext_word_in <= cipher_buffer(31 downto 0);
                        feeding_ciphertext <= '0';
                    when others => null;
                end case;
                if decrypt_index < 3 then
                    decrypt_index <= decrypt_index + 1;
                end if;
            else
                ciphertext_valid <= '0';
            end if;
        end if;
    end process;

    -- Output final decrypted block
    decrypted_block <= dec_buffer;

     -- ========== Instantiate XTEA duplex encryption/decryption ==========
    xtea_inst: entity work.xtea_top_duplex
        port map (
            clk                 => clk,
            reset_n             => reset,
            data_word_in        => data_word_in,
            data_valid          => data_valid,
            ciphertext_word_in  => ciphertext_word_in,
            ciphertext_valid    => ciphertext_valid,
            key_word_in         => data_word_in,
            key_valid           => key_valid,
            key_ready           => open,
            ciphertext_word_out => ciphertext_word_out,
            ciphertext_ready    => ciphertext_ready,
            data_word_out       => data_word_out,
            data_ready          => data_ready
        );

end architecture;

