library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================================
-- XTEA Encryption Core (128-bit, 32 rounds)
-- -----------------------------------------------------------------------------
-- EXEC split into EXEC_A / EXEC_B so v1/v3 see the updated v0/v2, matching C.
-- =============================================================================

entity xtea_enc is
    Port (
        clk               : in  std_logic;
        reset_n           : in  std_logic;
        data_word_in      : in  std_logic_vector(31 downto 0);
        data_valid        : in  std_logic;
        full_key          : in  std_logic_vector(127 downto 0);
        ciphertext_out    : out std_logic_vector(31 downto 0);
        ciphertext_valid  : out std_logic
    );
end xtea_enc;

architecture Behavioral of xtea_enc is

    type word_array_4 is array(0 to 3) of unsigned(31 downto 0);
    signal k : word_array_4;

    type state_type is (IDLE, LOAD0, LOAD1, LOAD2, LOAD3,
                        EXEC_A, EXEC_B,
                        OUT0, OUT1, OUT2, OUT3);
    signal state : state_type := IDLE;

    signal input_buf       : std_logic_vector(127 downto 0) := (others => '0');
    signal v0, v1, v2, v3  : unsigned(31 downto 0) := (others => '0');
    signal sum             : unsigned(31 downto 0) := (others => '0');
    constant delta         : unsigned(31 downto 0) := x"9E3779B9";
    signal round_counter   : integer range 0 to 31 := 0;
    signal valid_flag      : std_logic := '0';

begin

    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state         <= IDLE;
            input_buf     <= (others => '0');
            v0 <= (others => '0'); v1 <= (others => '0');
            v2 <= (others => '0'); v3 <= (others => '0');
            sum           <= (others => '0');
            round_counter <= 0;
            valid_flag    <= '0';

        elsif rising_edge(clk) then
            valid_flag <= '0';

            case state is
                when IDLE =>
                    if data_valid = '1' then
                        input_buf(127 downto 96) <= data_word_in;
                        state <= LOAD0;
                    end if;

                when LOAD0 =>
                    if data_valid = '1' then
                        input_buf(95 downto 64) <= data_word_in;
                        state <= LOAD1;
                    end if;

                when LOAD1 =>
                    if data_valid = '1' then
                        input_buf(63 downto 32) <= data_word_in;
                        state <= LOAD2;
                    end if;

                when LOAD2 =>
                    if data_valid = '1' then
                        input_buf(31 downto 0) <= data_word_in;
                        state <= LOAD3;
                    end if;

                when LOAD3 =>
                    v0 <= unsigned(input_buf(127 downto 96));
                    v1 <= unsigned(input_buf(95 downto 64));
                    v2 <= unsigned(input_buf(63 downto 32));
                    v3 <= unsigned(input_buf(31 downto 0));
                    k(0) <= unsigned(full_key(127 downto 96));
                    k(1) <= unsigned(full_key(95 downto 64));
                    k(2) <= unsigned(full_key(63 downto 32));
                    k(3) <= unsigned(full_key(31 downto 0));
                    sum           <= (others => '0');
                    round_counter <= 0;
                    state         <= EXEC_A;

                -- Half-round 1: v0 += f(v1, sum);  v2 += f(v3, sum);  sum += delta
                when EXEC_A =>
                    v0  <= v0 + ((((v1 sll 4) xor (v1 srl 5)) + v1) xor
                                 (sum + k(to_integer(sum(1 downto 0)))));
                    v2  <= v2 + ((((v3 sll 4) xor (v3 srl 5)) + v3) xor
                                 (sum + k(to_integer(sum(1 downto 0)))));
                    sum <= sum + delta;
                    state <= EXEC_B;

                -- Half-round 2: v1 += g(v0_new, sum_new);  v3 += g(v2_new, sum_new)
                when EXEC_B =>
                    v1  <= v1 + ((((v0 sll 4) xor (v0 srl 5)) + v0) xor
                                 (sum + k(to_integer(sum(12 downto 11)))));
                    v3  <= v3 + ((((v2 sll 4) xor (v2 srl 5)) + v2) xor
                                 (sum + k(to_integer(sum(12 downto 11)))));
                    if round_counter = 31 then
                        state <= OUT0;
                    else
                        round_counter <= round_counter + 1;
                        state <= EXEC_A;
                    end if;

                -- OUT0: latch final values, OUT1-OUT3: stream words with valid
                when OUT0 =>
                    ciphertext_out <= std_logic_vector(v0);
                    valid_flag     <= '1';
                    state          <= OUT1;

                when OUT1 =>
                    ciphertext_out <= std_logic_vector(v1);
                    valid_flag     <= '1';
                    state          <= OUT2;

                when OUT2 =>
                    ciphertext_out <= std_logic_vector(v2);
                    valid_flag     <= '1';
                    state          <= OUT3;

                when OUT3 =>
                    ciphertext_out <= std_logic_vector(v3);
                    valid_flag     <= '1';
                    state          <= IDLE;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    ciphertext_valid <= valid_flag;

end Behavioral;
