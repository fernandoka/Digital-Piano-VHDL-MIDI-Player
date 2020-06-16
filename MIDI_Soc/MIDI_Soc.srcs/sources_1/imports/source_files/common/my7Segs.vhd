----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 26.09.2019 00:17:30
-- Design Name: 
-- Module Name: bin2segNexsys4 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.1
-- Additional Comments:
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity my7Segs is
 Port ( 
        rst_n               :   in  std_logic;
        clk                 :   in  std_logic;
        bin					:	in	std_logic_vector(4 downto 0);
		seven_segs_digit	:	out	std_logic_vector(6 downto 0)	
  );
-- Attributes for debug
--      attribute   dont_touch    :   string;
--      attribute   dont_touch  of  my7Segs  :   entity  is  "true";  
end my7Segs;

architecture Behavioral of my7Segs is
	
	signal reg :   std_logic_vector(4 downto 0);
	
begin
  
    myRegister: 
    process(rst_n, clk)
    begin
        if rst_n='0' then
            reg <= (others=>'1');
        elsif rising_edge(clk) then
            reg <= bin;
        end if;
    end process myRegister;

    with reg select
      seven_segs_digit <= 
			"1000000" when "0" & X"0",
			"1111001" when "0" & X"1",
			"0100100" when "0" & X"2",
			"0110000" when "0" & X"3",
			"0011001" when "0" & X"4",
			"0010010" when "0" & X"5",
			"0000010" when "0" & X"6",
			"1011000" when "0" & X"7",
			"0000000" when "0" & X"8",
			"0010000" when "0" & X"9",
			"0001000" when "0" & X"A",
			"0000011" when "0" & X"B",
			"1000110" when "0" & X"C",
			"0100001" when "0" & X"D",
			"0000110" when "0" & X"E",
			"0001110" when "0" & X"F",
			"1111111" when others;

end Behavioral;
