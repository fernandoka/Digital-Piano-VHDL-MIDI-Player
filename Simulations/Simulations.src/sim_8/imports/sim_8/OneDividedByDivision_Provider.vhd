----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: OneDividedByDivision_Provider - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.3
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

entity OneDividedByDivision_Provider is
  Generic(START_ADDR	:	in	natural); -- 32 bits Address of the first value of OneDividedByDivision constants stored in DDR memory 
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		readRqt					:	in	std_logic; -- One cycle high to request a read
		division				:	in	std_logic_vector(15 downto 0);
		readyValue				:	out	std_logic; -- High when the value of the last read it's ready
		OneDividedByDivision	:	out	std_logic_vector(23 downto 0); -- Value of 1/division in Q4.20
		
		--Debug
		statesOut       		:	out std_logic_vector(2 downto 0);
		 
		-- Mem arbitrator side
		dataIn       			:	in	std_logic_vector(23 downto 0); -- Value of 1/division in Q4.20
        memAckSend      		:   in 	std_logic;
		memAckResponse			:	in  std_logic;
		addr_out        		:   out std_logic_vector(24 downto 0); 
		memConstantSendRq		:   out std_logic

  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  OneDividedByDivision_Provider  :   entity  is  "true";
end OneDividedByDivision_Provider;

architecture Behavioral of OneDividedByDivision_Provider is
	
begin

fsm:
process(rst_n,clk,readRqt,memAckResponse)
    type states is (s0, s1, s2);	
	variable state	:	states;
	
	variable   constantIndex   :   unsigned(24 downto 0);
	variable   regAddr         :   unsigned(24 downto 0);
begin


    addr_out <= std_logic_vector(regAddr);

    constantIndex :=(others=>'0');
    constantIndex(15 downto 0) := unsigned(division);
    
    --Debug
    statesOut <=(others=>'0');
    if state=s0 then
        statesOut(0)<='1'; 
    end if;
    
    if state=s1 then
        statesOut(1)<='1'; 
    end if;
    
    if state=s2 then
        statesOut(2)<='1'; 
    end if;
    --
    	
	if rst_n='0' then
		state := s0;
		addr_out <=(others=>'0');
		OneDividedByDivision <=(others=>'0');
		memConstantSendRq <='0';
		readyValue <='0';
    
	elsif rising_edge(clk) then

		case state is
			when s0=>
				if readRqt='1' then
					regAddr := to_unsigned(START_ADDR,25) + constantIndex - 1;
					memConstantSendRq <='1';
					readyValue <='0';
					state := s1;
				end if;
			
			when s1 =>
                    if memAckSend='1' then
                        memConstantSendRq <='0';
                        state := s2;
                    end if;
              
                when s2 =>
                    if memAckResponse='1' then 
                        OneDividedByDivision <= dataIn;
                        readyValue <='1';
                        state := s0;
                    end if;
		  end case;
		
    end if;
end process;
  
end Behavioral;
