library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================================
-- xtea_top_duplex
-- -----------------------------------------------------------------------------
-- This is a top-level wrapper that interfaces with XTEA encryption and
-- decryption cores. It accepts plaintext and a key, outputs encrypted data,
-- and also receives ciphertext to produce decrypted output.
--
-- Interfaces:
-- - Key input streamed in 4x 32-bit words (key_valid asserted per word).
-- - Plaintext and ciphertext also streamed in 4x 32-bit words.
-- - Encryption and decryption are performed in parallel pipelines.
-- =============================================================================


entity xtea_top_duplex is
    Port (
        clk                 : in  std_logic;
        reset_n             : in  std_logic;
        data_word_in        : in  std_logic_vector(31 downto 0);
        data_valid          : in  std_logic;
        ciphertext_word_in  : in  std_logic_vector(31 downto 0);
        ciphertext_valid    : in  std_logic;
        key_word_in         : in  std_logic_vector(31 downto 0);
        key_valid           : in  std_logic;
        key_ready           : out std_logic;
        ciphertext_word_out : out std_logic_vector(31 downto 0);
        ciphertext_ready    : out std_logic;
        data_word_out       : out std_logic_vector(31 downto 0);
        data_ready          : out std_logic
    );
end xtea_top_duplex;

-- Component Declarations
architecture Behavioral of xtea_top_duplex is

    component xtea_enc is
        Port (
            clk              : in  std_logic;
            reset_n          : in  std_logic;
            data_word_in     : in  std_logic_vector(31 downto 0);
            data_valid       : in  std_logic;
            full_key         : in  std_logic_vector(127 downto 0);
            ciphertext_out   : out std_logic_vector(31 downto 0);
            ciphertext_valid : out std_logic
        );
    end component;

    component xtea_dec is
        Port (
            clk              : in  std_logic;
            reset_n          : in  std_logic;
            ciphertext_in    : in  std_logic_vector(31 downto 0);
            ciphertext_valid : in  std_logic;
            full_key         : in  std_logic_vector(127 downto 0);
            data_out         : out std_logic_vector(31 downto 0);
            data_valid       : out std_logic;
            data_ready       : out std_logic
        );
    end component;

    -- Key management
    type key_state_type is (KEY_IDLE, KEY_0, KEY_1, KEY_2, KEY_3);
    signal key_state : key_state_type := KEY_IDLE;
    signal full_key  : std_logic_vector(127 downto 0) := (others => '0');

    -- Plaintext buffering FSM
    type data_state_type is (DATA_IDLE, DATA_0, DATA_1, DATA_2);
    signal data_state : data_state_type := DATA_IDLE;
    signal plaintext_buf : std_logic_vector(127 downto 0) := (others => '0');
    signal plaintext_valid : std_logic := '0';

     -- Ciphertext buffering for decryption
    signal ciphertext_buf : std_logic_vector(127 downto 0) := (others => '0');
    signal ciphertext_valid_internal : std_logic := '0';
    signal cipher_valid_next : std_logic := '0';
    signal feeding_dec : std_logic := '0';
    signal dec_index   : integer range 0 to 3 := 0;

    -- Encryption FSM state and signals
    type enc_stream_state_type is (ENC_IDLE, ENC_0, ENC_1, ENC_2, ENC_3);
    signal enc_stream_state : enc_stream_state_type := ENC_IDLE;
    signal enc_input_word : std_logic_vector(31 downto 0) := (others => '0');
    signal enc_input_valid : std_logic := '0';

    -- Decryption output logic
    signal dec_out    : std_logic_vector(31 downto 0) := (others => '0');
    signal dec_valid  : std_logic := '0';
    signal dec_output_index  : integer range 0 to 3 := 0;

    -- Encryption output
    signal enc_out    : std_logic_vector(31 downto 0) := (others => '0');
    signal enc_valid  : std_logic := '0';


-- Component Instantiations
begin

    ENC_UNIT : xtea_enc
        port map (
            clk              => clk,
            reset_n          => reset_n,
            data_word_in     => enc_input_word,
            data_valid       => enc_input_valid,
            full_key         => full_key,
            ciphertext_out   => enc_out,
            ciphertext_valid => enc_valid
        );

    DEC_UNIT : xtea_dec
        port map (
            clk              => clk,
            reset_n          => reset_n,
            ciphertext_in    => ciphertext_buf(127 downto 96),
            ciphertext_valid => ciphertext_valid_internal,
            full_key         => full_key,
            data_out         => dec_out,
            data_valid       => dec_valid,
            data_ready       => open
        );

    -- Key Feeding FSM    
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            key_state <= KEY_IDLE;
            full_key <= (others => '0');
        elsif rising_edge(clk) then
            case key_state is
                when KEY_IDLE => if key_valid = '1' then full_key(127 downto 96) <= key_word_in; key_state <= KEY_0; end if;
                when KEY_0    => if key_valid = '1' then full_key(95 downto 64) <= key_word_in; key_state <= KEY_1; end if;
                when KEY_1    => if key_valid = '1' then full_key(63 downto 32) <= key_word_in; key_state <= KEY_2; end if;
                when KEY_2    => if key_valid = '1' then full_key(31 downto 0) <= key_word_in; key_state <= KEY_3; end if;
                when KEY_3    => key_state <= KEY_IDLE;
                when others   => key_state <= KEY_IDLE;
            end case;
        end if;
    end process;

    -- Key ready is asserted when we can accept a new key
    key_ready <= '1' when key_state = KEY_IDLE else '0';

    -- Plaintext Input FSM    
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            data_state <= DATA_IDLE;
            plaintext_buf <= (others => '0');
            plaintext_valid <= '0';
        elsif rising_edge(clk) then
            plaintext_valid <= '0';
            case data_state is
                when DATA_IDLE => if data_valid = '1' then plaintext_buf(127 downto 96) <= data_word_in; data_state <= DATA_0; end if;
                when DATA_0    => if data_valid = '1' then plaintext_buf(95 downto 64) <= data_word_in; data_state <= DATA_1; end if;
                when DATA_1    => if data_valid = '1' then plaintext_buf(63 downto 32) <= data_word_in; data_state <= DATA_2; end if;
                when DATA_2    => if data_valid = '1' then plaintext_buf(31 downto 0) <= data_word_in; plaintext_valid <= '1'; data_state <= DATA_IDLE; end if;
            end case;
        end if;
    end process;

    -- Ciphertext Input FSM (Decryption)
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            ciphertext_buf <= (others => '0');
            ciphertext_valid_internal <= '0';
            cipher_valid_next <= '0';
            feeding_dec <= '0';
            dec_index <= 0;
        elsif rising_edge(clk) then
            ciphertext_valid_internal <= cipher_valid_next;
            cipher_valid_next <= '0';

            if ciphertext_valid = '1' and feeding_dec = '0' then
                feeding_dec <= '1';
                dec_index <= 0;
            elsif feeding_dec = '1' then
                case dec_index is
                    when 0 => ciphertext_buf(127 downto 96) <= ciphertext_word_in;
                    when 1 => ciphertext_buf(95 downto 64)  <= ciphertext_word_in;
                    when 2 => ciphertext_buf(63 downto 32)  <= ciphertext_word_in;
                    when 3 =>
                        ciphertext_buf(31 downto 0) <= ciphertext_word_in;
                        feeding_dec <= '0';
                        cipher_valid_next <= '1';
                    when others => null;
                end case;
                if dec_index < 3 then
                    dec_index <= dec_index + 1;
                end if;
            end if;
        end if;
    end process;

    -- Encryption Streaming FSM
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            enc_stream_state <= ENC_IDLE;
            enc_input_valid <= '0';
            enc_input_word <= (others => '0');
        elsif rising_edge(clk) then
            enc_input_valid <= '0';
            case enc_stream_state is
                when ENC_IDLE => if plaintext_valid = '1' then enc_input_word <= plaintext_buf(127 downto 96); enc_input_valid <= '1'; enc_stream_state <= ENC_0; end if;
                when ENC_0    => enc_input_word <= plaintext_buf(95 downto 64); enc_input_valid <= '1'; enc_stream_state <= ENC_1;
                when ENC_1    => enc_input_word <= plaintext_buf(63 downto 32); enc_input_valid <= '1'; enc_stream_state <= ENC_2;
                when ENC_2    => enc_input_word <= plaintext_buf(31 downto 0); enc_input_valid <= '1'; enc_stream_state <= ENC_3;
                when ENC_3    => enc_stream_state <= ENC_IDLE;
                when others   => enc_stream_state <= ENC_IDLE;
            end case;
        end if;
    end process;

    -- Encryption output    
    ciphertext_word_out <= enc_out;
    ciphertext_ready    <= enc_valid;

    -- Decryption Output Handling
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            data_ready <= '0';
            data_word_out <= (others => '0');
            dec_output_index <= 0;
        elsif rising_edge(clk) then
            if dec_valid = '1' then
                case dec_output_index is
                    when 0 => data_word_out <= dec_out; data_ready <= '1'; dec_output_index <= 1;
                    when 1 => data_word_out <= dec_out; data_ready <= '1'; dec_output_index <= 2;
                    when 2 => data_word_out <= dec_out; data_ready <= '1'; dec_output_index <= 3;
                    when 3 => data_word_out <= dec_out; data_ready <= '1'; dec_output_index <= 0;
                    when others => dec_output_index <= 0;
                end case;
            else
                data_ready <= '0';
            end if;
        end if;
    end process;

end Behavioral;
