library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- cs_top  --  Top-level Cryptography System
-- -----------------------------------------------------------------------------
-- Integrates:
--   ip_enc_gen   - SystemVerilog plaintext traffic generator
--   ip_dec_gen   - SystemVerilog decoy traffic generator
--   mini_router  - Priority/round-robin arbitration (VHDL)
--   xtea_top_duplex - XTEA enc+dec core (VHDL)
--
-- Pipeline:
--   1. Router assembles 16 bytes (128 bits) from ip_enc_gen stream
--   2. 128-bit key sent to xtea_top_duplex once at startup
--   3. 128-bit plaintext block streamed in as 4x32-bit words
--   4. Ciphertext output buffered, then streamed into decrypt path
--   5. Decrypted 128-bit block assembled and held on decrypted_block
--
-- BUG FIXES vs original cs_top:
--  1. cipher_buffer was never populated; now captured from ciphertext_word_out
--  2. cipher_index was never incremented; now gated properly so feeding
--     starts only after 4 ciphertext words have been collected
--  3. key word mux had off-by-one (used pre-increment index)
--  4. key_word_in was incorrectly shared with data_word_in; now separate
--  5. dec_buffer never populated; now assembled from data_word_out
-- =============================================================================

entity cs_top is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;  -- active-low
        decrypted_block : out std_logic_vector(127 downto 0)
    );
end cs_top;

architecture arch of cs_top is

    -- Router <-> generators
    signal data1   : std_logic_vector(9 downto 0);
    signal req1    : std_logic;
    signal grant1  : std_logic;
    signal data2   : std_logic_vector(9 downto 0);
    signal req2    : std_logic;
    signal grant2  : std_logic;

    -- Router output
    signal router_data_out : std_logic_vector(7 downto 0);
    signal router_valid    : std_logic;

    -- 128-bit block assembly
    signal data_buffer  : std_logic_vector(127 downto 0) := (others => '0');
    signal byte_count   : integer range 0 to 15 := 0;
    signal block_ready  : std_logic := '0';
    signal block_consumed : std_logic := '0';

    -- Hardcoded 128-bit key
    constant ENC_KEY : std_logic_vector(127 downto 0) := x"DEADBEEF0123456789ABCDEFDEADBEEF";

    -- Key feeding FSM
    type key_fsm_t is (KEY_IDLE, KEY_W0, KEY_W1, KEY_W2, KEY_W3, KEY_DONE);
    signal key_state   : key_fsm_t := KEY_IDLE;
    signal key_word    : std_logic_vector(31 downto 0) := (others => '0');
    signal key_valid   : std_logic := '0';

    -- Plaintext feeding FSM
    type plain_fsm_t is (PLAIN_IDLE, PLAIN_W0, PLAIN_W1, PLAIN_W2, PLAIN_W3);
    signal plain_state    : plain_fsm_t := PLAIN_IDLE;
    signal plain_word     : std_logic_vector(31 downto 0) := (others => '0');
    signal plain_valid    : std_logic := '0';

    -- Encryption outputs
    signal ciphertext_word_out : std_logic_vector(31 downto 0);
    signal ciphertext_ready    : std_logic;

    -- Ciphertext capture buffer (4 words from enc output)
    signal cipher_buffer   : std_logic_vector(127 downto 0) := (others => '0');
    signal cipher_count    : integer range 0 to 4 := 0;
    signal cipher_full     : std_logic := '0';
    signal cipher_consumed : std_logic := '0';

    -- Ciphertext feeding FSM into dec path
    type ciph_fsm_t is (CIPH_IDLE, CIPH_W0, CIPH_W1, CIPH_W2, CIPH_W3);
    signal ciph_state  : ciph_fsm_t := CIPH_IDLE;
    signal ciph_word   : std_logic_vector(31 downto 0) := (others => '0');
    signal ciph_valid  : std_logic := '0';

    -- Decryption outputs
    signal dec_word_out : std_logic_vector(31 downto 0);
    signal dec_ready    : std_logic;

    -- Decrypted block assembly
    signal dec_buffer  : std_logic_vector(127 downto 0) := (others => '0');
    signal dec_count   : integer range 0 to 4 := 0;

    -- Active-high reset adapter for Verilog modules
    signal reset_high : std_logic;

    component ip_enc_gen
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            data_out : out std_logic_vector(9 downto 0);
            req      : out std_logic
        );
    end component;

    component ip_dec_gen
        port (
            clk      : in  std_logic;
            reset    : in  std_logic;
            data_out : out std_logic_vector(9 downto 0);
            req      : out std_logic
        );
    end component;

begin

    reset_high <= not reset;

    ip_gen_enc : ip_enc_gen
        port map (clk => clk, reset => reset_high, data_out => data1, req => req1);

    ip_gen_dec : ip_dec_gen
        port map (clk => clk, reset => reset_high, data_out => data2, req => req2);

    router_inst : entity work.mini_router
        port map (
            clk => clk, reset => reset,
            data1 => data1, req1 => req1, grant1 => grant1,
            data2 => data2, req2 => req2, grant2 => grant2,
            data_out => router_data_out, valid => router_valid
        );

    xtea_inst : entity work.xtea_top_duplex
        port map (
            clk                 => clk,
            reset_n             => reset,
            data_word_in        => plain_word,
            data_valid          => plain_valid,
            ciphertext_word_in  => ciph_word,
            ciphertext_valid    => ciph_valid,
            key_word_in         => key_word,
            key_valid           => key_valid,
            key_ready           => open,
            ciphertext_word_out => ciphertext_word_out,
            ciphertext_ready    => ciphertext_ready,
            data_word_out       => dec_word_out,
            data_ready          => dec_ready
        );

    -- ===== Assemble 128-bit block from router bytes =====
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                byte_count    <= 0;
                data_buffer   <= (others => '0');
                block_ready   <= '0';
                block_consumed <= '0';
            else
                if block_consumed = '1' then
                    block_ready    <= '0';
                    block_consumed <= '0';
                end if;
                if router_valid = '1' and block_ready = '0' then
                    data_buffer(8*(15-byte_count)+7 downto 8*(15-byte_count)) <= router_data_out;
                    if byte_count = 15 then
                        block_ready <= '1';
                        byte_count  <= 0;
                    else
                        byte_count <= byte_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ===== FIX: Key feeding FSM - correct word sequencing =====
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                key_state <= KEY_IDLE;
                key_word  <= (others => '0');
                key_valid <= '0';
            else
                key_valid <= '0';
                case key_state is
                    when KEY_IDLE =>
                        key_word  <= ENC_KEY(127 downto 96);
                        key_valid <= '1';
                        key_state <= KEY_W0;
                    when KEY_W0 =>
                        key_word  <= ENC_KEY(95 downto 64);
                        key_valid <= '1';
                        key_state <= KEY_W1;
                    when KEY_W1 =>
                        key_word  <= ENC_KEY(63 downto 32);
                        key_valid <= '1';
                        key_state <= KEY_W2;
                    when KEY_W2 =>
                        key_word  <= ENC_KEY(31 downto 0);
                        key_valid <= '1';
                        key_state <= KEY_W3;
                    when KEY_W3 =>
                        key_state <= KEY_DONE;
                    when KEY_DONE =>
                        null; -- key sent once, stays done
                    when others =>
                        key_state <= KEY_DONE;
                end case;
            end if;
        end if;
    end process;

    -- ===== FIX: Plaintext feeding FSM (separate from key path) =====
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                plain_state <= PLAIN_IDLE;
                plain_word  <= (others => '0');
                plain_valid <= '0';
                block_consumed <= '0';
            else
                plain_valid    <= '0';
                block_consumed <= '0';
                case plain_state is
                    when PLAIN_IDLE =>
                        if block_ready = '1' then
                            plain_word  <= data_buffer(127 downto 96);
                            plain_valid <= '1';
                            plain_state <= PLAIN_W0;
                        end if;
                    when PLAIN_W0 =>
                        plain_word  <= data_buffer(95 downto 64);
                        plain_valid <= '1';
                        plain_state <= PLAIN_W1;
                    when PLAIN_W1 =>
                        plain_word  <= data_buffer(63 downto 32);
                        plain_valid <= '1';
                        plain_state <= PLAIN_W2;
                    when PLAIN_W2 =>
                        plain_word     <= data_buffer(31 downto 0);
                        plain_valid    <= '1';
                        block_consumed <= '1';
                        plain_state    <= PLAIN_W3;
                    when PLAIN_W3 =>
                        plain_state <= PLAIN_IDLE;
                    when others =>
                        plain_state <= PLAIN_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- ===== FIX: Capture ciphertext output into buffer =====
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                cipher_buffer   <= (others => '0');
                cipher_count    <= 0;
                cipher_full     <= '0';
                cipher_consumed <= '0';
            else
                if cipher_consumed = '1' then
                    cipher_full  <= '0';
                    cipher_count <= 0;
                    cipher_consumed <= '0';
                end if;
                if ciphertext_ready = '1' and cipher_full = '0' then
                    case cipher_count is
                        when 0 => cipher_buffer(127 downto 96) <= ciphertext_word_out;
                        when 1 => cipher_buffer(95 downto 64)  <= ciphertext_word_out;
                        when 2 => cipher_buffer(63 downto 32)  <= ciphertext_word_out;
                        when 3 => cipher_buffer(31 downto 0)   <= ciphertext_word_out;
                                  cipher_full <= '1';
                        when others => null;
                    end case;
                    if cipher_count < 4 then
                        cipher_count <= cipher_count + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;

    -- ===== FIX: Feed ciphertext into dec path once buffer full =====
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                ciph_state      <= CIPH_IDLE;
                ciph_word       <= (others => '0');
                ciph_valid      <= '0';
                cipher_consumed <= '0';
            else
                ciph_valid      <= '0';
                cipher_consumed <= '0';
                case ciph_state is
                    when CIPH_IDLE =>
                        if cipher_full = '1' then
                            ciph_word  <= cipher_buffer(127 downto 96);
                            ciph_valid <= '1';
                            ciph_state <= CIPH_W0;
                        end if;
                    when CIPH_W0 =>
                        ciph_word  <= cipher_buffer(95 downto 64);
                        ciph_valid <= '1';
                        ciph_state <= CIPH_W1;
                    when CIPH_W1 =>
                        ciph_word  <= cipher_buffer(63 downto 32);
                        ciph_valid <= '1';
                        ciph_state <= CIPH_W2;
                    when CIPH_W2 =>
                        ciph_word       <= cipher_buffer(31 downto 0);
                        ciph_valid      <= '1';
                        cipher_consumed <= '1';
                        ciph_state      <= CIPH_W3;
                    when CIPH_W3 =>
                        ciph_state <= CIPH_IDLE;
                    when others =>
                        ciph_state <= CIPH_IDLE;
                end case;
            end if;
        end if;
    end process;

    -- ===== FIX: Assemble decrypted block from dec output =====
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                dec_buffer <= (others => '0');
                dec_count  <= 0;
            else
                if dec_ready = '1' then
                    case dec_count is
                        when 0 => dec_buffer(127 downto 96) <= dec_word_out;
                        when 1 => dec_buffer(95 downto 64)  <= dec_word_out;
                        when 2 => dec_buffer(63 downto 32)  <= dec_word_out;
                        when 3 => dec_buffer(31 downto 0)   <= dec_word_out;
                        when others => null;
                    end case;
                    if dec_count < 4 then
                        dec_count <= dec_count + 1;
                    else
                        dec_count <= 0;
                    end if;
                end if;
            end if;
        end if;
    end process;

    decrypted_block <= dec_buffer;

end architecture;
