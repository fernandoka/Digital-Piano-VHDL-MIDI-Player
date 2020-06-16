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
-- Revision 0.2
-- Additional Comments:
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

use WORK.MY_COMMON.ALL;

entity bin2segNexys4 is
 Port ( 
        rst_n       : in std_logic;
        clk         : in std_logic;

        -- Right Side
        segRight_n0 : in std_logic_vector(5 downto 0);
        segRight_n1 : in std_logic_vector(5 downto 0);
        segRight_n2 : in std_logic_vector(5 downto 0);
        segRight_n3 : in std_logic_vector(5 downto 0);

        -- Left Side
        segLeft_n0 : in std_logic_vector(5 downto 0);
        segLeft_n1 : in std_logic_vector(5 downto 0);
        segLeft_n2 : in std_logic_vector(5 downto 0);
        segLeft_n3 : in std_logic_vector(5 downto 0);

        -- Out signals
        disp_seg_o     : out std_logic_vector(7 downto 0);
        disp_an_o      : out std_logic_vector(7 downto 0)
  );
-- Attributes for debug
--      attribute   dont_touch    :   string;
--      attribute   dont_touch  of  bin2segNexys4  :   entity  is  "true";  
end bin2segNexys4;

architecture Behavioral of bin2segNexys4 is

	signal currentNumber     :   std_logic_vector(5 downto 0);
	signal cnt               :   std_logic_vector(19 downto 0); -- aprox 71,52Hz of refresh rate at 75MHz of clock speed
    
begin
    disp_seg_o(7) <= currentNumber(5);
    -- Seven-Segment
    Disp: my7Segs
    port map(rst_n =>rst_n, clk=>clk, bin =>currentNumber(4 downto 0), seven_segs_digit=>disp_seg_o(6 downto 0) );
   
   clockGen: 
   process(rst_n, clk)
   begin
      if rst_n='0' then
          cnt <= (others=>'0');
      elsif rising_edge(clk) then
         cnt <= cnt + '1';
      end if;
   end process clockGen;

   -- Anode Selection
   with cnt(19 downto 17) select
      disp_an_o <=    
         "11111110" when "000",
         "11111101" when "001",
         "11111011" when "010",
         "11110111" when "011",
         "11101111" when "100",
         "11011111" when "101",
         "10111111" when "110",
         "01111111" when others;

   -- Input selection
   with cnt(19 downto 17) select
      currentNumber <=    
         segRight_n0 when "000",
         segRight_n1 when "001",
         segRight_n2 when "010",
         segRight_n3 when "011",
         segLeft_n0  when "100",
         segLeft_n1  when "101",
         segLeft_n2  when "110",
         segLeft_n3  when others;

end Behavioral;
