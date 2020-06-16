----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 0.1
-- Comments:
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.NUMERIC_STD.ALL;


entity Pwm is
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;
	data_i 						: 	in 	std_logic_vector(7 downto 0); -- the number to be modulated
	pwm_o 						: 	out std_logic

  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  Pwm  :   entity  is  "true";  
end Pwm;

architecture Behavioral of Pwm is
    
begin	

process(rst_n, clk, data_i)
	constant	MAX	    :	unsigned(7 downto 0) := (others=>'1');
	variable	cntr	:	unsigned(7 downto 0);
begin

	if cntr < unsigned(data_i) then
		pwm_o <= '1';
	else
		pwm_o <= '0';
	end if;

	
    if rst_n='0' then
		cntr := (others=>'0');
		
    elsif rising_edge(clk) then
        if cntr < MAX then
            cntr := cntr+1;
		else
			cntr := (others=>'0');
        end if;
		
    end if;
end process;


end Behavioral;
