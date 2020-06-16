----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: CmdKeyboardSequencer - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.7
-- Additional Comments:
--		Command format: cmd(3 downto 0) = velocity
--					 	cmd(11 downto 4) = note code
--                      cmd(12) = when high, note on	
--						cmd(13) = when high, note off
--                      cmd(14) = when high cmd from externKeyboard, when low cmd from midi parser 
--						Null command when -> cmd(9 downto 0) = (others=>'0') 
--
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;
entity CmdKeyboardSequencer is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		
		-- Cmd Inputs
		cmdIn_0		    :	in	std_logic_vector(14 downto 0);
		cmdIn_1         :	in	std_logic_vector(14 downto 0);
		sendCmdRqt		:	in	std_logic_vector(1 downto 0); -- High to a add a new command to the buffer
		seq_ack			:	out std_logic_vector(1 downto 0);
		
		--Keyboard side
		keyboard_ack	:	in	std_logic; -- Request of a new command
		aviableCmd    	:	out std_logic; -- One cycle high	
		cmdKeyboard		:	out std_logic_vector(14 downto 0)
		
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  CmdKeyboardSequencer  :   entity  is  "true";
end CmdKeyboardSequencer;

architecture Behavioral of CmdKeyboardSequencer is

begin

  
process(rst_n,clk,sendCmdRqt,keyboard_ack)
	type states is (s0, s1);	
	variable state	:	states;
	
	variable internalCe   :   std_logic;
	variable turn         :   boolean;

begin
    
    internalCe := sendCmdRqt(0) or sendCmdRqt(1);
    
	-------------------
    -- MOORE OUTPUTS --
    -------------------
    seq_ack <=(others=>'0');
    if state=s1 and keyboard_ack='1' then
        if turn then
          seq_ack(0) <='1';
        else
          seq_ack(1) <='1';
        end if;
	end if;
	
    if rst_n='0' then
        state := s0;
		turn :=true;
        aviableCmd<='0';
        cmdKeyboard<=(others=>'0');
        
	elsif rising_edge(clk) then
        aviableCmd<='0';

		case state is
		  when s0=>
            if internalCe='1' then
                if turn and sendCmdRqt(0)='1' then
                    aviableCmd<='1';
                    state :=s1;
                    cmdKeyboard <=cmdIn_0;        
                elsif not turn and sendCmdRqt(1)='1' then
                    aviableCmd<='1';
                    state :=s1;
                    cmdKeyboard <=cmdIn_1;
                else
                    turn := not turn;             
                end if;
	        end if;
	         
	      when s1=>
            if keyboard_ack='1' then
              turn := not turn;
              state :=s0;
            end if;

	   end case;
	   
    end if;
end process;
  
end Behavioral;
