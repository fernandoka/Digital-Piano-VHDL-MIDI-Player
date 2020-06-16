----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name: TestTrackSequencer - Behavioral
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

entity TestTrackSequencer is
--  Port ( );
end TestTrackSequencer;

use work.my_common.all;

architecture Behavioral of TestTrackSequencer is

    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)


    -- Señales 
    signal clk     : std_logic := '1';      
    signal rst_n   : std_logic := '0';
    signal allTracks   :    std_logic_vector(2*15-1 downto 0);
    
    signal  sendCmdRqt, seq_ack :   std_logic_vector(1 downto 0);
    signal  keyboard_ack, aviableCmdRqt :   std_logic;
    signal  cmdKeyboard :   std_logic_vector(14 downto 0);

begin
  
clkGen:
  clk <= not clk after clkPeriod/2;
    
rstGen :
    rst_n <= 
    '1' after (50 us + 5 ns), 
    '0' after (50000 ms);

test: 
process
begin
    allTracks(2*15-1 downto 15) <="111" & X"000";
    allTracks(14 downto 0) <="000" & X"FFF";
    sendCmdRqt<="00";
    keyboard_ack<='0';
         
	wait until (rst_n='1' and clk='1');
	wait for (clkPeriod*5);
    
    sendCmdRqt<="11";
    
    wait for (clkPeriod*10);

    keyboard_ack<='1';
    wait for (clkPeriod);
    keyboard_ack<='0';
    
    if seq_ack(0)='1' then
        sendCmdRqt<="10";
    else
        sendCmdRqt<="01";
    end if;
    
    wait for (clkPeriod*10);
        
    keyboard_ack<='1';
    wait for (clkPeriod);
    keyboard_ack<='0';

    sendCmdRqt<="00";
    
    wait;
        
end process;


SequencerCMD: TracksCmdSequencer
  generic map(WL_CMD => 15, NUM_TRACK_READERS => 2)
  port map( 
        rst_n           => rst_n,
        clk             => clk,
        
        -- Cmd Inputs   
        tracksCmd       => allTracks,
        sendCmdRqt      => sendCmdRqt,
        seq_ack         => seq_ack,
    
        -- Out side     
        keyboard_ack    => keyboard_ack,
        aviableCmdRqt   => aviableCmdRqt,
        cmdKeyboard     => cmdKeyboard
  );

end Behavioral;
