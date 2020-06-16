----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name: MyKeyBoardTest - Behavioral
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

entity MyKeyBoardTest is
--  Port ( );
end MyKeyBoardTest;

architecture Behavioral of MyKeyBoardTest is

component CmdKeyboardSequencer is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		
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

component KeyboardCntrl is
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;
        cen             			:   in  std_logic;
		emtyCmdKeyboardBuffer		:	in std_logic;	
		cmdKeyboard					:	in std_logic_vector(9 downto 0);
		keyboard_ack				:	out	std_logic;
			
        --IIS side	
        sampleRqt       			:   in  std_logic;
        sampleOut       			:   out std_logic_vector(15 downto 0);
        
        --Debug
        regStartAddr               : out	   std_logic_vector(25 downto 0);  
        regSustainStartOffsetAddr  : out    std_logic_vector(25 downto 0);
        regSustainEndOffsetAddr    : out    std_logic_vector(25 downto 0);
        regMaxSamples              : out    std_logic_vector(25 downto 0);
        regStepVal                 : out    std_logic_vector(63 downto 0);
        regSustainStepStart        : out    std_logic_vector(63 downto 0);
        regSustainStepEnd          : out    std_logic_vector(63 downto 0);
        notesOnOff				   : out    std_logic_vector(15 downto 0);

        --
        
        -- Mem side
		mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(15+4 downto 0); -- mem_CmdReadResponse(19 downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(25+4 downto 0); -- mem_CmdReadRequest(29 downto 26)= note gen index, mem_CmdReadRequest(25 downto 0) = sample addr
		mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  my_Keyboard  :   entity  is  "true";
    
end component;


    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)


    -- Señales 
    signal	clk     : std_logic := '1';      
    signal	rst_n   : std_logic := '0';
	
	-- Keyboard cmd sequencer
	signal	cmdKeyboard_out, cmdTrack_0_in, cmdTrack_1_in	:	std_logic_vector(9 downto 0);
	signal	emtyCmdBuffer_out, keyboard_ack_in 	:	std_logic;
	signal	sendCmdRqt_in, seq_ack_out, statesOut	:	std_logic_vector(1 downto 0);
	
	-- my_Keyboard
	signal	regStartAddr                :	std_logic_vector(25 downto 0);  
    signal    regSustainStartOffsetAddr  :    std_logic_vector(25 downto 0);
    signal    regSustainEndOffsetAddr    :    std_logic_vector(25 downto 0);
    signal    regMaxSamples              :    std_logic_vector(25 downto 0);
    signal    regStepVal                 :    std_logic_vector(63 downto 0);
    signal    regSustainStepStart        :    std_logic_vector(63 downto 0);
    signal    regSustainStepEnd          :    std_logic_vector(63 downto 0);
    signal    notesOnOff			     :	std_logic_vector(15 downto 0);

--    signal sampleRqt				:   std_logic;
--    signal sampleOut                :   std_logic_vector(15 downto 0);
                                        
                                        
--    signal mem_emptyBuffer          :   std_logic;
--    signal mem_CmdReadResponse      :   std_logic_vector(15+4 downto 0);
--    signal mem_fullBuffer           :   std_logic; 
--    signal mem_CmdReadRequest       :   std_logic_vector(25+4 downto 0);
--    signal mem_readResponseBuffer   :   std_logic;
--    signal mem_writeReciveBuffer    :   std_logic;
    
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

	wait until (rst_n='1');
	
	wait for (clkPeriod*5);
	
	--Testing diferents notes turn on
    sendCmdRqt_in <= "11"; 	
    cmdTrack_0_in <= "10" & X"50";
    cmdTrack_1_in <= "10" & X"47";
    
    wait until seq_ack_out="01" or seq_ack_out="10";
        sendCmdRqt_in <= not seq_ack_out;

    wait until seq_ack_out="01" or seq_ack_out="10";
        sendCmdRqt_in <= "00";    
    
    wait for (clkPeriod*5);
    
    --Testing diferents notes turn off
    sendCmdRqt_in <= "11";     
    cmdTrack_0_in <= "01" & X"50";
    cmdTrack_1_in <= "01" & X"47";
    
    wait until seq_ack_out="01" or seq_ack_out="10";
        sendCmdRqt_in <= not seq_ack_out;
    
    wait until seq_ack_out="01" or seq_ack_out="10";
        sendCmdRqt_in <= "00";        

    wait for (clkPeriod*5);

    --Testing same note turn on
    sendCmdRqt_in <= "11";     
    cmdTrack_0_in <= "10" & X"51";
    cmdTrack_1_in <= "10" & X"51";
    
    wait until seq_ack_out="01" or seq_ack_out="10";
        sendCmdRqt_in <= not seq_ack_out;
    
    wait until seq_ack_out="01" or seq_ack_out="10";
        sendCmdRqt_in <= "00";


    wait for (clkPeriod*5);
    wait for (clkPeriod*5);

    wait until sendCmdRqt_in="00";
        assert(notesOnOff(0)='1');
        report "Third example fails, only flag 0 should be on" severity error;
    wait for (clkPeriod*5);

    
    
    wait;

end process;


lala : CmdKeyboardSequencer
  Port map( 
        rst_n           => rst_n,
        clk             => clk,
		
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

cucu: KeyboardCntrl
  port map( 
        rst_n           			=> rst_n,
        clk             			=> clk,
        cen             			=> '1',
		emtyCmdKeyboardBuffer		=> emtyCmdBuffer_out,
		cmdKeyboard					=> cmdKeyboard_out,
		keyboard_ack				=> keyboard_ack_in,
									
        --IIS side	                
        sampleRqt       			=> '0',
        sampleOut       			=> open,
		
		--Debug
		regStartAddr               => regStartAddr             ,
        regSustainStartOffsetAddr  => regSustainStartOffsetAddr,
        regSustainEndOffsetAddr    => regSustainEndOffsetAddr  ,
        regMaxSamples              => regMaxSamples            ,
        regStepVal                 => regStepVal               ,
        regSustainStepStart        => regSustainStepStart      ,
        regSustainStepEnd          => regSustainStepEnd        ,
        notesOnOff                 => notesOnOff,
		--
		
        -- Mem side                 
		mem_emptyBuffer				=> '0',
        mem_CmdReadResponse    		=> (others=>'0'),
        mem_fullBuffer         		=> '0',
        mem_CmdReadRequest		    => open,
		mem_readResponseBuffer		=> open,
        mem_writeReciveBuffer     	=> open 
		
  );
end Behavioral;
