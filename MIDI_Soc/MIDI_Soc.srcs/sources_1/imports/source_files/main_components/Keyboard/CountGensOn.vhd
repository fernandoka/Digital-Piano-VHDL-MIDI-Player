----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: CountGensOn - Behavioral
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
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;

entity CountGensOn is
  Generic(	WL	:	in	natural);
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		
		notesOnOff		:	in	std_logic_vector(WL-1 downto 0);		
		numGensOn		:	out std_logic_vector(log2(WL) downto 0)
		
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  CountGensOn  :   entity  is  "true";
end CountGensOn;

architecture Behavioral of CountGensOn is

begin

  
process(rst_n,clk,notesOnOff)
	type sum_t 	is array ( 0 to WL-1 ) of unsigned(log2(WL) downto 0);

	variable sum	:	sum_t;

begin
	
    if rst_n='0' then
		numGensOn <=(others=>'0');
        
	elsif rising_edge(clk) then
    
        sum(0) := to_unsigned(0,log2(WL)+1);
        if notesOnOff(0)='1' then
            sum(0) := to_unsigned(1,log2(WL)+1);
        end if;

        -- Pipelined sum
        for i in 1 to WL-1 loop
            sum(i) := sum(i-1);
            if notesOnOff(i)='1' then
                sum(i) := sum(i-1)+to_unsigned(1,log2(WL)+1);
            end if;
        end loop;
		
		numGensOn <= std_logic_vector(sum(WL-1));
	   
    end if;
end process;
  
end Behavioral;
