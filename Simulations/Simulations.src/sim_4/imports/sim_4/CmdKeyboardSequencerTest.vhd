----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name: CmdKeyboardSequencerTest - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity CmdKeyboardSequencerTest is
--  Port ( );
end CmdKeyboardSequencerTest;

architecture Behavioral of CmdKeyboardSequencerTest is

component CmdKeyboardSequencer is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        cen				:	in	std_logic;
		
		-- Read Tracks Side
		cmdTrack_0		:	in	std_logic_vector(9 downto 0);
		cmdTrack_1		:	in	std_logic_vector(9 downto 0);
		sendCmdRqt		:	in	std_logic_vector(1 downto 0); -- High to a add a new command to the buffer
		seq_ack			:	out std_logic_vector(1 downto 0);
		
		
		-- Debug
		statesOut		:	out	std_logic_vector(1 downto 0);
		
		--Keyboard side
		keyboard_ack	:	in	std_logic; -- Request of a new command
		emtyCmdBuffer	:	out std_logic;	
		cmdKeyboard		:	out std_logic_vector(9 downto 0)
		
  );   
end component;


    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)


    -- Señales 
    signal	clk     : std_logic := '1';      
    signal	rst_n   : std_logic := '0';
	
	signal	cmdKeyboard_out, cmdTrack_0_in, cmdTrack_1_in	:	std_logic_vector(9 downto 0);
	signal	emtyCmdBuffer_out, keyboard_ack_in, cenSeq	:	std_logic;
	signal	sendCmdRqt_in, seq_ack_out, statesOut	:	std_logic_vector(1 downto 0);
	
begin
  
clkGen:
  clk <= not clk after clkPeriod/2;
    
rstGen :
    rst_n <= 
    '1' after (50 us + 5 ns), 
    '0' after (50000 ms);



dataReadRqtGen: 
process
begin
    -- wait for rst_n
	cmdTrack_0_in <=(others=>'0');
	cmdTrack_1_in <=(others=>'0');
	sendCmdRqt_in <=(others=>'0');
	cenSeq <='0';
    keyboard_ack_in <='0';

	wait until (rst_n='1');
	
	cenSeq <='1';
	wait for (clkPeriod*5);
	
	cmdTrack_0_in <="10" & X"47";
	sendCmdRqt_in <="01"; 	
	wait until seq_ack_out(0)='1';
	
	cmdTrack_0_in <=(others=>'0');
	cmdTrack_1_in <="01" & X"47";
	sendCmdRqt_in <="10";
	
	wait until seq_ack_out(1)='1';
	
	-- Pruebo que el lastCmd si funciona
	cmdTrack_0_in <="01" & X"47";
	cmdTrack_1_in <="10" & X"48";
	sendCmdRqt_in <="11";
	
	keyboard_ack_in <='1';
	wait for (clkPeriod);
    sendCmdRqt_in <=(others=>'0');

    wait;

end process;


lala : CmdKeyboardSequencer
  Port map( 
        rst_n           => rst_n,
        clk             => clk,
        cen				=> cenSeq,
		
		-- Read Tracks Side     
		cmdTrack_0		=> cmdTrack_0_in,
		cmdTrack_1		=> cmdTrack_1_in,
		sendCmdRqt		=> sendCmdRqt_in,
		seq_ack			=> seq_ack_out,
		
		-- Debug
		statesOut		=>statesOut,
		
		--Keyboard side         
		keyboard_ack	=> keyboard_ack_in,
		emtyCmdBuffer	=> emtyCmdBuffer_out,
		cmdKeyboard		=> cmdKeyboard_out
		
  );


end Behavioral;
