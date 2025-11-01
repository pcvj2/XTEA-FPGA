library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;


entity cs_tb is
end entity;

architecture sim of cs_tb is

    -- Clock and reset
    signal clk_tb   : std_logic := '0';
    signal reset_tb : std_logic := '0';

    -- Output to monitor
    signal decrypted_block_tb : std_logic_vector(127 downto 0);

    -- Component under test
    component cs_top
        port (
            clk             : in  std_logic;
            reset           : in  std_logic;
            decrypted_block : out std_logic_vector(127 downto 0)
        );
    end component;

begin

    -- Instantiate Unit Under Test
    uut: cs_top
        port map (
            clk             => clk_tb,
            reset           => reset_tb,
            decrypted_block => decrypted_block_tb
        );

    -- Clock generation
    clk_process: process
    begin
        while true loop
            clk_tb <= '0';
            wait for 5 ns;
            clk_tb <= '1';
            wait for 5 ns;
        end loop;
    end process;

    -- Stimulus and monitoring process
    stim_proc: process
        variable L : line;
    begin
        -- Apply reset
        reset_tb <= '0';
        wait for 20 ns;
        reset_tb <= '1';

        -- Let the system run long enough for key + encryption + decryption
        wait for 1800 ns;

        -- Print the final decrypted block
        write(L, string'("Decrypted Block: "));
        for i in decrypted_block_tb'range loop
            if i mod 4 = 3 then
                write(L, character'(' '));
            end if;
            write(L, std_logic'image(decrypted_block_tb(i)));
        end loop;
        writeline(output, L);

        -- Stop simulation
        report "Simulation finished.";
        wait;
    end process;

end architecture;
