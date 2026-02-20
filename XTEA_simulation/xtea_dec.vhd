library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================================
-- XTEA Decryption Core (128-bit, 32 rounds)
-- -----------------------------------------------------------------------------
-- EXEC split into EXEC_A / EXEC_B mirroring enc, so the inverse operations
-- see the correctly updated values (v1_new used when undoing v0).
-- Reference C dec:
--   v1 -= g(v0, sum);      <-- EXEC_A (uses current v0)
--   sum -= delta;
--   v0 -= f(v1_new, sum);  <-- EXEC_B (uses new v1)
-- =============================================================================

entity xtea_dec is
    Port (
        clk              : in  std_logic;
        reset_n          : in  std_logic;
        ciphertext_in    : in  std_logic_vector(31 downto 0);
        ciphertext_valid : in  std_logic;
        full_key         : in  std_logic_vector(127 downto 0);
        data_out         : out std_logic_vector(31 downto 0);
        data_valid       : out std_logic
    );
end xtea_dec;

architecture Behavioral of xtea_dec is

    type word_array is array(0 to 3) of unsigned(31 downto 0);
    signal k : word_array;

    type state_type is (IDLE, LOAD0, LOAD1, LOAD2, LOAD3,
                        EXEC_A, EXEC_B,
                        OUT0, OUT1, OUT2, OUT3);
    signal state : state_type := IDLE;

    signal input_buf       : std_logic_vector(127 downto 0) := (others => '0');
    signal v0, v1, v2, v3  : unsigned(31 downto 0) := (others => '0');
    signal sum             : unsigned(31 downto 0) := (others => '0');
    constant delta         : unsigned(31 downto 0) := x"9E3779B9";
    constant SUM_START     : unsigned(31 downto 0) := x"C6EF3720";
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
            sum           <= SUM_START;
            round_counter <= 0;
            valid_flag    <= '0';

        elsif rising_edge(clk) then
            valid_flag <= '0';

            case state is
                when IDLE =>
                    if ciphertext_valid = '1' then
                        input_buf(127 downto 96) <= ciphertext_in;
                        state <= LOAD0;
                    end if;

                when LOAD0 =>
                    if ciphertext_valid = '1' then
                        input_buf(95 downto 64) <= ciphertext_in;
                        state <= LOAD1;
                    end if;

                when LOAD1 =>
                    if ciphertext_valid = '1' then
                        input_buf(63 downto 32) <= ciphertext_in;
                        state <= LOAD2;
                    end if;

                when LOAD2 =>
                    if ciphertext_valid = '1' then
                        input_buf(31 downto 0) <= ciphertext_in;
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
                    sum           <= SUM_START;
                    round_counter <= 0;
                    state         <= EXEC_A;

                -- Half-round 1: undo v1/v3 update (uses current v0/v2 and pre-decrement sum)
                when EXEC_A =>
                    v1  <= v1 - ((((v0 sll 4) xor (v0 srl 5)) + v0) xor
                                 (sum + k(to_integer(sum(12 downto 11)))));
                    v3  <= v3 - ((((v2 sll 4) xor (v2 srl 5)) + v2) xor
                                 (sum + k(to_integer(sum(12 downto 11)))));
                    sum <= sum - delta;
                    state <= EXEC_B;

                -- Half-round 2: undo v0/v2 update (uses new v1/v3 and post-decrement sum)
                when EXEC_B =>
                    v0  <= v0 - ((((v1 sll 4) xor (v1 srl 5)) + v1) xor
                                 (sum + k(to_integer(sum(1 downto 0)))));
                    v2  <= v2 - ((((v3 sll 4) xor (v3 srl 5)) + v3) xor
                                 (sum + k(to_integer(sum(1 downto 0)))));
                    if round_counter = 31 then
                        state <= OUT0;
                    else
                        round_counter <= round_counter + 1;
                        state <= EXEC_A;
                    end if;

                when OUT0 =>
                    data_out   <= std_logic_vector(v0);
                    valid_flag <= '1';
                    state      <= OUT1;

                when OUT1 =>
                    data_out   <= std_logic_vector(v1);
                    valid_flag <= '1';
                    state      <= OUT2;

                when OUT2 =>
                    data_out   <= std_logic_vector(v2);
                    valid_flag <= '1';
                    state      <= OUT3;

                when OUT3 =>
                    data_out   <= std_logic_vector(v3);
                    valid_flag <= '1';
                    state      <= IDLE;

                when others =>
                    state <= IDLE;

            end case;
        end if;
    end process;

    data_valid <= valid_flag;

end Behavioral;
