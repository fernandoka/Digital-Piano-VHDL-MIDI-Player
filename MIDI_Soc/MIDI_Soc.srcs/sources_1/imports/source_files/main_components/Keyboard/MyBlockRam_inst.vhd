----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 0.1
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

use IEEE.NUMERIC_STD.ALL;

use work.my_common.all;

entity MyBlockRam_inst is
  Generic(	DEPTH	:	in	natural;
			Wl		:	in	natural
	);
  Port(
    -- Host side
    clk                     	:	in	std_logic;  
    wr		    				:	in	std_logic;
	wr_addr		              	:	in	std_logic_vector(log2(DEPTH) downto 0);
	rd_addr		              	:	in	std_logic_vector(log2(DEPTH) downto 0);
	data_in						:	in	std_logic_vector(Wl-1 downto 0);
	data_out              		:	out	std_logic_vector(Wl-1 downto 0)

  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  MyBlockRam_inst  :   entity  is  "true";  
end MyBlockRam_inst;


architecture Behavioral of MyBlockRam_inst is
	
	type   rows_t is array (0 to DEPTH-1) of std_logic_vector(Wl-1 downto 0);
	signal	mem	:	rows_t :=(others=>(others=>'0'));
	
begin	


 syncBlockRam:
  process (clk,wr,wr_addr,rd_addr)
  begin          		
	  	
	if rising_edge(clk) then
		if wr='1' then
			mem(to_integer( unsigned(wr_addr) )) <= data_in; 
		end if;
		data_out <= mem(to_integer( unsigned(rd_addr) ));
    end if;--rising_edge
  end process;
        
end Behavioral;
