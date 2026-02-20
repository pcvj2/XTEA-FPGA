library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ip_dec_gen is
    Port (
        clk      : in  std_logic;
        reset    : in  std_logic;
        data_out : out std_logic_vector(9 downto 0);
        req      : out std_logic
    );
end ip_dec_gen;

architecture Behavioral of ip_dec_gen is
    constant CIPHERTEXT : std_logic_vector(127 downto 0) := x"089975E92555F334CE76E4F24D932AB3";
    signal count  : integer range 0 to 16 := 0;
    signal active : std_logic := '0';
begin
    process(clk)
        variable byte_val   : std_logic_vector(7 downto 0);
        variable priority_v : std_logic_vector(1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                count    <= 0;
                req      <= '0';
                data_out <= (others => '0');
                active   <= '1';
            else
                if active = '1' then
                    if count < 16 then
                        -- Format: {payload[7:0], priority[1:0]} — priority in LSBs to match router
                        byte_val   := CIPHERTEXT(127 - 8*count downto 120 - 8*count);
                        priority_v := std_logic_vector(to_unsigned(count mod 4, 2));
                        data_out   <= byte_val & priority_v;
                        req        <= '1';
                        count      <= count + 1;
                    else
                        req    <= '0';
                        active <= '0';
                    end if;
                else
                    req <= '0';
                end if;
            end if;
        end if;
    end process;
end Behavioral;
