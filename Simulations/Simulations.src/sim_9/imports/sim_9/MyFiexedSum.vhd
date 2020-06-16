----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.12.2019 22:15:30
-- Design Name: 
-- Module Name: MyFiexedSum - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MyFiexedSum is
    Generic(
        WL  :   natural
    );
    Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        
        a_in               :   in  std_logic_vector(WL-1 downto 0);
        b_in               :   in  std_logic_vector(WL-1 downto 0);
        c_out              :   out  std_logic_vector(WL-1 downto 0)
    );
end MyFiexedSum;

architecture Behavioral of MyFiexedSum is
    constant    ZEROS       :   std_logic_vector(WL-2 downto 0) :=(others=>'0');    
    constant    MAX_POS_VAL :   std_logic_vector(WL downto 0) := "00" &  not ZEROS ;
    constant    MAX_NEG_VAL :   std_logic_vector(WL downto 0) := "11" &  ZEROS ;   

    signal  finalSum    :   signed(WL-1 downto 0);
    signal  auxSum      :   signed(WL downto 0);

begin
SumAndSatur:
    auxSum <= signed(a_in(WL-1) & a_in) + signed(b_in(WL-1) & b_in);
    
    finalSum <= signed(MAX_POS_VAL(WL-1 downto 0)) when auxSum > signed(MAX_POS_VAL) else
                signed(MAX_POS_VAL(WL-1 downto 0)) when auxSum > signed(MAX_POS_VAL) else
                auxSum(WL-1 downto 0);

process(rst_n,clk)
    variable reg    :   signed(WL-1 downto 0);
begin
    
    c_out <= std_logic_vector(reg);
    
    if rst_n='0' then
        reg :=(others=>'0');
    elsif rising_edge(clk) then
        reg := finalSum;
    end if;
end process;


end Behavioral;
