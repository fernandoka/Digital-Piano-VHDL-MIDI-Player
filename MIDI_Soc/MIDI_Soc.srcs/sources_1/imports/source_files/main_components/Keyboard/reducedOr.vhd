----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 19.12.2019 19:57:49
-- Design Name: 
-- Module Name: reducedOr - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity reducedOr is
  Generic(
        WL  :   natural
  );
  Port (
        a_in                    :   in  std_logic_vector(WL-1 downto 0);
        reducedA_out            :   out std_logic        
   );
-- Attributes for debug
--       attribute   dont_touch    :   string;
--       attribute   dont_touch  of  reducedOr  :   entity  is  "true";
end reducedOr;

architecture Behavioral of reducedOr is
    signal  tmp :   std_logic_vector(WL-1 downto 0);
begin

tmp(0)<= a_in(0);
or_gen:
for i in 1 to (WL-1) generate
    tmp(i)<=a_in(i) or tmp(i-1);
end generate;

reducedA_out <= tmp(WL-1);

end Behavioral;
