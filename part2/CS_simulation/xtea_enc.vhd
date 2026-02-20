library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library std;
use std.textio.all;

-- =============================================================================
-- XTEA Encryption Module
-- -----------------------------------------------------------------------------
-- Encrypts 128-bit plaintext input using a 128-bit key over 32 rounds of XTEA.
-- Inputs are streamed in 32-bit words. Outputs encrypted 128-bit data
-- in 4 x 32-bit chunks with valid signalling.
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

    constant DEBUG : boolean := true;

    -- Key array: 4 x 32-bit unsigned integers
    type word_array_4 is array(0 to 3) of unsigned(31 downto 0);
    signal k : word_array_4;

    -- FSM states
    type state_type is (IDLE, FEED, EXEC, OUT0, OUT1, OUT2, OUT3);
    signal state : state_type := IDLE;

    -- Internal registers
    signal input_buf   : std_logic_vector(127 downto 0);
    signal v0, v1, v2, v3 : unsigned(31 downto 0);
    signal sum            : unsigned(31 downto 0) := (others => '0');
    constant delta        : unsigned(31 downto 0) := x"9E3779B9";
    signal round_counter  : integer range 0 to 32 := 0;

    signal cipher_buf     : std_logic_vector(127 downto 0);
    signal out_counter    : integer range 0 to 3 := 0;
    signal valid_flag     : std_logic := '0';

    signal word_index     : integer range 0 to 3 := 0;

    -- 2002 utility: converts binary vector to hex string
    function hex_string(vec : std_logic_vector) return string is
        variable result : string(1 to vec'length / 4);
        variable nibble : std_logic_vector(3 downto 0);
        variable i : integer := 1;
    begin
        for idx in vec'left downto vec'right loop
            if ((idx - vec'right) mod 4 = 3) then
                nibble := vec(idx downto idx - 3);
                case nibble is
                    when "0000" => result(i) := '0';
                    when "0001" => result(i) := '1';
                    when "0010" => result(i) := '2';
                    when "0011" => result(i) := '3';
                    when "0100" => result(i) := '4';
                    when "0101" => result(i) := '5';
                    when "0110" => result(i) := '6';
                    when "0111" => result(i) := '7';
                    when "1000" => result(i) := '8';
                    when "1001" => result(i) := '9';
                    when "1010" => result(i) := 'A';
                    when "1011" => result(i) := 'B';
                    when "1100" => result(i) := 'C';
                    when "1101" => result(i) := 'D';
                    when "1110" => result(i) := 'E';
                    when "1111" => result(i) := 'F';
                    when others => result(i) := '?';
                end case;
                i := i + 1;
            end if;
        end loop;
        return result;
    end function;

begin

    -- Main FSM process
    process(clk, reset_n)
        variable l : line;
    begin
        if reset_n = '0' then
            -- Reset state
            state <= IDLE;
            input_buf <= (others => '0');
            v0 <= (others => '0');
            v1 <= (others => '0');
            v2 <= (others => '0');
            v3 <= (others => '0');
            sum <= (others => '0');
            round_counter <= 0;
            cipher_buf <= (others => '0');
            valid_flag <= '0';
            out_counter <= 0;
            word_index <= 0;

        elsif rising_edge(clk) then
            valid_flag <= '0';

            case state is

                -- Wait for first data word
                when IDLE =>
                    if data_valid = '1' then
                        word_index <= 0;
                        state <= FEED;
                    end if;

                -- Load 128-bit plaintext in 4 x 32-bit chunks    
                when FEED =>
                    if data_valid = '1' then
                        case word_index is
                            when 0 => input_buf(127 downto 96) <= data_word_in;
                            when 1 => input_buf(95 downto 64)  <= data_word_in;
                            when 2 => input_buf(63 downto 32)  <= data_word_in;
                            when 3 =>
                                input_buf(31 downto 0) <= data_word_in;
                                v0 <= unsigned(input_buf(127 downto 96));
                                v1 <= unsigned(input_buf(95 downto 64));
                                v2 <= unsigned(input_buf(63 downto 32));
                                v3 <= unsigned(data_word_in);
                                k(0) <= unsigned(full_key(127 downto 96));
                                k(1) <= unsigned(full_key(95 downto 64));
                                k(2) <= unsigned(full_key(63 downto 32));
                                k(3) <= unsigned(full_key(31 downto 0));
                                sum <= (others => '0');
                                round_counter <= 0;
                                state <= EXEC;
                        end case;

                        if word_index < 3 then
                            word_index <= word_index + 1;
                        else
                            word_index <= 0;
                        end if;
                    end if;

                when EXEC =>
                    -- Perform 32 rounds of encryption
                    if round_counter < 32 then
                        v0 <= v0 + (((v1 sll 4) xor (v1 srl 5)) + v1) xor (sum + k(to_integer(sum(1 downto 0))));
                        v2 <= v2 + (((v3 sll 4) xor (v3 srl 5)) + v3) xor (sum + k(to_integer(sum(1 downto 0))));
                        sum <= sum + delta;
                        v1 <= v1 + (((v0 sll 4) xor (v0 srl 5)) + v0) xor (sum + k(to_integer(sum(12 downto 11))));
                        v3 <= v3 + (((v2 sll 4) xor (v2 srl 5)) + v2) xor (sum + k(to_integer(sum(12 downto 11))));
                        round_counter <= round_counter + 1;
                    else
                        -- Store encrypted result
                        cipher_buf(127 downto 96) <= std_logic_vector(v0);
                        cipher_buf(95 downto 64)  <= std_logic_vector(v1);
                        cipher_buf(63 downto 32)  <= std_logic_vector(v2);
                        cipher_buf(31 downto 0)   <= std_logic_vector(v3);
                        out_counter <= 0;

                        if DEBUG then
                            write(l, string'("Encrypted result: " & hex_string(cipher_buf)));
                            writeline(output, l);
                        end if;

                        state <= OUT0;
                    end if;

                -- Stream encrypted output over 4 cycles    
                when OUT0 =>
                    ciphertext_out <= cipher_buf(127 downto 96);
                    valid_flag <= '1';
                    state <= OUT1;

                when OUT1 =>
                    ciphertext_out <= cipher_buf(95 downto 64);
                    valid_flag <= '1';
                    state <= OUT2;

                when OUT2 =>
                    ciphertext_out <= cipher_buf(63 downto 32);
                    valid_flag <= '1';
                    state <= OUT3;

                when OUT3 =>
                    ciphertext_out <= cipher_buf(31 downto 0);
                    valid_flag <= '1';
                    state <= IDLE;

                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

    -- Assign output valid signal
    ciphertext_valid <= valid_flag;

end Behavioral;
