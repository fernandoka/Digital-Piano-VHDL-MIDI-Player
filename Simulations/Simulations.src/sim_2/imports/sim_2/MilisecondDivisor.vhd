----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: MilisecondDivisor - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.2
-- Additional Comments:
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MilisecondDivisor is
  Generic(FREQ : in natural);-- Frequency in Khz
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		cen				:	in	std_logic;
		Tc				:	out std_logic
		
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  MilisecondDivisor  :   entity  is  "true";
end MilisecondDivisor;

architecture Behavioral of MilisecondDivisor is

begin

counter:
process(rst_n,clk,cen)
	variable cntr	:	natural range 0 to FREQ-1;
begin
	
	Tc <='0';
	if cntr=FREQ-1 then
		Tc <='1';
    end if;
	
	if rst_n='0' then
		cntr := 0;
		
    elsif rising_edge(clk) then
		if cen='1' then
		  if cntr < FREQ-1 then
		      cntr := cntr+1;
		  else
		      cntr := 0;
		  end if;
		elsif cntr/=0 then
            cntr := 0;
        end if;
        
    end if;
end process;
  
end Behavioral;
