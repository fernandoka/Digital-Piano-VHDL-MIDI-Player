----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: TracksCmdSequencer - Behavioral
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

entity TracksCmdSequencer is
  Generic(	WL_CMD				:	in	natural;
			NUM_TRACK_READERS	:	in	natural	
  );
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		
		-- Cmd Inputs
		tracksCmd		:	in	std_logic_vector(NUM_TRACK_READERS*WL_CMD-1 downto 0);
		sendCmdRqt		:	in	std_logic_vector(NUM_TRACK_READERS-1 downto 0);
		seq_ack			:	out std_logic_vector(NUM_TRACK_READERS-1 downto 0);
		
		-- Out side
		keyboard_ack	:	in	std_logic;
		aviableCmdRqt 	:	out std_logic; -- High until cmd takes effect	
		cmdKeyboard		:	out std_logic_vector(WL_CMD-1 downto 0)
		
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  TracksCmdSequencer  :   entity  is  "true";
end TracksCmdSequencer;

architecture Behavioral of TracksCmdSequencer is
	
	signal	orResult	:	std_logic;

begin


my_or:reducedOr
  generic map(WL=>NUM_TRACK_READERS)
  port map(a_in =>sendCmdRqt, reducedA_out =>orResult);

  
process(rst_n, clk, sendCmdRqt, keyboard_ack)
	constant	MAX_INDEX	:	natural	:= NUM_TRACK_READERS-1;
	
	type states is (s0, s1);	
	variable state	:	states;
	
	variable turn         :   natural range 0 to MAX_INDEX;

begin
    
	
    if rst_n='0' then
		state := s0;
		turn :=0;
        aviableCmdRqt <='0';
        cmdKeyboard <=(others=>'0');
        seq_ack <=(others=>'0');
        
	elsif rising_edge(clk) then
        seq_ack <=(others=>'0');

		case state is

		  when s0=>
            if orResult='1' then
				if sendCmdRqt(turn)='1' then
					cmdKeyboard <=tracksCmd((turn+1)*WL_CMD-1 downto turn*WL_CMD);
					aviableCmdRqt <='1';
					state := s1;
				else
					if turn < MAX_INDEX then
						turn := turn+1;
					else
						turn :=0;
					end if;
				end if;
	        end if;
	         
	      when s1=>
            if keyboard_ack='1' then
				aviableCmdRqt <='0';
				seq_ack(turn) <='1';
				if turn < MAX_INDEX then
					turn := turn+1;
				else
					turn :=0;
				end if;
				state := s0;
			end if;

	   end case;
	   
    end if; -- rst_n/rising_edge(clk) 
end process;
  
end Behavioral;
