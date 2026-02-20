library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- =============================================================================
-- mini_router
-- -----------------------------------------------------------------------------
-- Arbitration router that accepts 10-bit data from two sources (data1 and data2).
-- Each input includes 2 bits of priority (LSBs) and 8 bits of payload (MSBs).
-- The router:
--   • Grants access based on priority
--   • Falls back to round-robin if priorities match
--   • Outputs the 8-bit data with a valid signal
-- =============================================================================

entity mini_router is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic; 
        data1    : in  std_logic_vector(9 downto 0);
        req1     : in  std_logic;
        grant1   : out std_logic;
        data2    : in  std_logic_vector(9 downto 0);
        req2     : in  std_logic;
        grant2   : out std_logic;
        data_out : out std_logic_vector(7 downto 0);
        valid    : out std_logic
    );
end entity;

architecture arch of mini_router is

    -- Extracted 2-bit priorities from data inputs
    signal priority1      : std_logic_vector(1 downto 0);
    signal priority2      : std_logic_vector(1 downto 0);

    -- Tracks which source was selected last (used for round-robin)
    signal last_selected  : std_logic := '0';

begin

    -- Extract priorities (lowest 2 bits of each data input)
    priority1 <= data1(1 downto 0);
    priority2 <= data2(1 downto 0);

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '0' then
                -- On reset: clear all control signals
                last_selected <= '0';
                data_out      <= (others => '0');
                valid         <= '0';
                grant1        <= '0';
                grant2        <= '0';

            else
                -- Defaults for each cycle
                data_out <= (others => '0');
                valid    <= '0';
                grant1   <= '0';
                grant2   <= '0';

                -- Case 1: Only source 1 is requesting
                if (req1 = '1') and (req2 = '0') then
                    data_out     <= data1(7 downto 0);
                    valid        <= '1';
                    grant1       <= '1';
                    last_selected <= '0';

                -- Case 2: Only source 2 is requesting
                elsif (req1 = '0') and (req2 = '1') then
                    data_out     <= data2(7 downto 0);
                    valid        <= '1';
                    grant2       <= '1';
                    last_selected <= '1';

                -- Case 3: Both sources are requesting    
                elsif (req1 = '1') and (req2 = '1') then
                    if unsigned(priority1) > unsigned(priority2) then
                        -- Source 1 has priority
                        data_out     <= data1(7 downto 0);
                        valid        <= '1';
                        grant1       <= '1';
                        last_selected <= '0';

                    elsif unsigned(priority1) < unsigned(priority2) then
                        -- Source 2 has priority
                        data_out     <= data2(7 downto 0);
                        valid        <= '1';
                        grant2       <= '1';
                        last_selected <= '1';

                    else  
                        -- Equal priority: use round-robin arbitration
                        if last_selected = '0' then
                            -- Alternate to source 2
                            data_out     <= data2(9 downto 2);
                            valid        <= '1';
                            grant2       <= '1';
                            last_selected <= '1';
                        else
                            -- Alternate to source 1
                            data_out     <= data1(9 downto 2);
                            valid        <= '1';
                            grant1       <= '1';
                            last_selected <= '0';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

end architecture;
