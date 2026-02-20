library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- XTEA Decryption Core
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

    constant DEBUG : boolean := true;

    -- Key array for 4 key words    
    type word_array is array(0 to 3) of unsigned(31 downto 0);
    signal k : word_array;

    -- FSM state declaration
    type state_type is (IDLE, LOAD0, LOAD1, LOAD2, LOAD3, EXEC, OUT0, OUT1, OUT2, OUT3);
    signal state : state_type := IDLE;

    -- Input buffer for ciphertext and output buffer for plaintext
    signal input_buf    : std_logic_vector(127 downto 0);
    signal v0, v1, v2, v3 : unsigned(31 downto 0);
    signal sum          : unsigned(31 downto 0);
    constant delta      : unsigned(31 downto 0) := x"9E3779B9";
    signal round_counter : integer range 0 to 32 := 0;

    signal output_buf   : std_logic_vector(127 downto 0);
    signal valid_flag   : std_logic := '0';

    -- Debug utility: converts std_logic_vector to hex string
    function hex_string(vec : std_logic_vector) return string is
        variable result : string(1 to vec'length / 4);
        variable nibble : std_logic_vector(3 downto 0);
        variable i : integer := 1;
    begin
        for idx in vec'high downto vec'low loop
            if ((vec'high - idx) mod 4) = 0 then
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

    -- FSM: Handles decryption flow
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state <= IDLE;
            input_buf <= (others => '0');
            v0 <= (others => '0'); v1 <= (others => '0');
            v2 <= (others => '0'); v3 <= (others => '0');
            output_buf <= (others => '0');
            valid_flag <= '0';
            round_counter <= 0;
            sum <= x"C6EF3720";

        elsif rising_edge(clk) then
            valid_flag <= '0';

            case state is

                -- Wait for first ciphertext word
                when IDLE =>
                    if ciphertext_valid = '1' then
                        input_buf(127 downto 96) <= ciphertext_in;
                        state <= LOAD0;
                    end if;

                -- Buffer remaining ciphertext words    
                when LOAD0 =>
                    input_buf(95 downto 64) <= ciphertext_in;
                    state <= LOAD1;

                when LOAD1 =>
                    input_buf(63 downto 32) <= ciphertext_in;
                    state <= LOAD2;

                when LOAD2 =>
                    input_buf(31 downto 0) <= ciphertext_in;
                    state <= LOAD3;

                -- Initialize working registers and key array    
                when LOAD3 =>
                    if DEBUG then
                        report "DEC buffered: " & hex_string(input_buf);
                    end if;
                    v0 <= unsigned(input_buf(127 downto 96));
                    v1 <= unsigned(input_buf(95 downto 64));
                    v2 <= unsigned(input_buf(63 downto 32));
                    v3 <= unsigned(input_buf(31 downto 0));
                    k(0) <= unsigned(full_key(127 downto 96));
                    k(1) <= unsigned(full_key(95 downto 64));
                    k(2) <= unsigned(full_key(63 downto 32));
                    k(3) <= unsigned(full_key(31 downto 0));
                    round_counter <= 0;
                    sum <= x"C6EF3720";
                    state <= EXEC;

                -- Execute 32 rounds of decryption    
                when EXEC =>
                    if round_counter < 32 then
                        v3 <= v3 - (((v2 sll 4) xor (v2 srl 5)) + v2) xor (sum + k(to_integer(sum(12 downto 11))));
                        v1 <= v1 - (((v0 sll 4) xor (v0 srl 5)) + v0) xor (sum + k(to_integer(sum(12 downto 11))));
                        sum <= sum - delta;
                        v2 <= v2 - (((v3 sll 4) xor (v3 srl 5)) + v3) xor (sum + k(to_integer(sum(1 downto 0))));
                        v0 <= v0 - (((v1 sll 4) xor (v1 srl 5)) + v1) xor (sum + k(to_integer(sum(1 downto 0))));
                        round_counter <= round_counter + 1;
                    else
                        -- Store decrypted result in output buffer
                        output_buf(127 downto 96) <= std_logic_vector(v0);
                        output_buf(95 downto 64)  <= std_logic_vector(v1);
                        output_buf(63 downto 32)  <= std_logic_vector(v2);
                        output_buf(31 downto 0)   <= std_logic_vector(v3);
                        state <= OUT0;
                    end if;

                -- Stream plaintext words sequentially over 4 cycles    
                when OUT0 =>
                    data_out <= output_buf(127 downto 96);
                    valid_flag <= '1';
                    state <= OUT1;

                when OUT1 =>
                    data_out <= output_buf(95 downto 64);
                    valid_flag <= '1';
                    state <= OUT2;

                when OUT2 =>
                    data_out <= output_buf(63 downto 32);
                    valid_flag <= '1';
                    state <= OUT3;

                when OUT3 =>
                    data_out <= output_buf(31 downto 0);
                    valid_flag <= '1';
                    state <= IDLE;

            end case;
        end if;
    end process;

    -- Output validity flag
    data_valid <= valid_flag;

end Behavioral;