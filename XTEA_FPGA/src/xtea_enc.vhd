library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library std;
use std.textio.all;

-- XTEA encryption core: accepts 128-bit plaintext and 128-bit key
-- Outputs 128-bit ciphertext in 32-bit chunks with valid signalling
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

    -- Key words storage
    type word_array_4 is array(0 to 3) of unsigned(31 downto 0);
    signal k : word_array_4;

    -- FSM state declaration
    type state_type is (IDLE, LOAD0, LOAD1, LOAD2, LOAD3, EXEC, OUT0, OUT1, OUT2, OUT3);
    signal state : state_type := IDLE;

    -- Input and output buffers
    signal input_buf   : std_logic_vector(127 downto 0);
    signal v0, v1, v2, v3 : unsigned(31 downto 0);
    signal sum            : unsigned(31 downto 0) := (others => '0');
    constant delta        : unsigned(31 downto 0) := x"9E3779B9";
    signal round_counter  : integer range 0 to 32 := 0;

    -- Internal variables for encryption
    signal cipher_buf     : std_logic_vector(127 downto 0);
    signal out_counter    : integer range 0 to 3 := 0;
    signal valid_flag     : std_logic := '0';

    -- Converts a std_logic_vector to a readable hex string for debugging
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

    -- FSM: Handles plaintext loading, encryption rounds, and ciphertext output
    process(clk, reset_n)
        variable l : line;
    begin
        if reset_n = '0' then
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
        elsif rising_edge(clk) then
            valid_flag <= '0';

            case state is
                -- Wait for first word of 128-bit plaintext
                when IDLE =>
                    if data_valid = '1' then
                        input_buf(127 downto 96) <= data_word_in;
                        state <= LOAD0;
                    end if;

                when LOAD0 =>
                -- Load next 3 words of plaintext into buffer
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

                -- Transfer plaintext and key into internal registers    
                when LOAD3 =>
                    v0 <= unsigned(input_buf(127 downto 96));
                    v1 <= unsigned(input_buf(95 downto 64));
                    v2 <= unsigned(input_buf(63 downto 32));
                    v3 <= unsigned(input_buf(31 downto 0));
                    k(0) <= unsigned(full_key(127 downto 96));
                    k(1) <= unsigned(full_key(95 downto 64));
                    k(2) <= unsigned(full_key(63 downto 32));
                    k(3) <= unsigned(full_key(31 downto 0));
                    sum <= (others => '0');
                    round_counter <= 0;
                    state <= EXEC;

                -- Perform 32 rounds of XTEA encryption    
                when EXEC =>
                    if round_counter < 32 then
                        -- First pair of values
                        v0 <= v0 + (((v1 sll 4) xor (v1 srl 5)) + v1) xor (sum + k(to_integer(sum(1 downto 0))));
                        v2 <= v2 + (((v3 sll 4) xor (v3 srl 5)) + v3) xor (sum + k(to_integer(sum(1 downto 0))));
                        sum <= sum + delta;
                        -- Second pair of values
                        v1 <= v1 + (((v0 sll 4) xor (v0 srl 5)) + v0) xor (sum + k(to_integer(sum(12 downto 11))));
                        v3 <= v3 + (((v2 sll 4) xor (v2 srl 5)) + v2) xor (sum + k(to_integer(sum(12 downto 11))));
                        round_counter <= round_counter + 1;
                    else
                        -- Store encrypted values in output buffer
                        cipher_buf(127 downto 96) <= std_logic_vector(v0);
                        cipher_buf(95 downto 64)  <= std_logic_vector(v1);
                        cipher_buf(63 downto 32)  <= std_logic_vector(v2);
                        cipher_buf(31 downto 0)   <= std_logic_vector(v3);
                        out_counter <= 0;

                        -- Optional debug output    
                        if DEBUG then
                            write(l, string'("Encrypted result: " & hex_string(cipher_buf)));
                            writeline(output, l);
                        end if;

                        state <= OUT0;
                    end if;

                -- Output ciphertext one word at a time over 4 cycles    
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

    -- Output valid flag
    ciphertext_valid <= valid_flag;

end Behavioral;
