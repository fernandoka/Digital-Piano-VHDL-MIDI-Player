----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.12.2019 15:38:20
-- Design Name: 
-- Module Name: MIDI_Soc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision 1.8
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use WORK.MY_COMMON.ALL;

entity MIDI_Soc is
  Port (
        clk_i            : in  std_logic;
        resetn_i         : in  std_logic;
        
        -- Buttons
        btnc_i           : in  std_logic;
        btnu_i           : in  std_logic;
        btnl_i           : in  std_logic;
        btnd_i           : in  std_logic;
        
        -- 7-segment display
        disp_seg_o       : out std_logic_vector(7 downto 0);
        disp_an_o        : out std_logic_vector(7 downto 0);
        
        -- leds
        led_o            : out std_logic_vector(15 downto 0);
        
        -- Rgb leds
        rgb1_red_o     : out std_logic;
        rgb1_green_o   : out std_logic;
        rgb1_blue_o    : out std_logic;
        
        rgb2_red_o     : out std_logic;
        rgb2_green_o   : out std_logic;
        rgb2_blue_o    : out std_logic;
        
        -- BT side
        btRxD   :  in std_logic;  -- Información recibida desde el Bluethooth, conectada al TxD del chip RN-42 (G16)
        btRst_n :   out std_logic; -- Reset a baja del Bluethooth
        
        -- IIS signals
        mclkAD           : out   std_logic;
        sclkAD           : out   std_logic;
        lrckAD           : out   std_logic;

        mclkDA           : out   std_logic;
        sclkDA           : out   std_logic;
        lrckDA           : out   std_logic;
        sdti             : out   std_logic;
        
        
        -- SPI signals
        cs_n             : out std_logic;   -- slave selection
        io0              : inout std_logic;    
        io1              : in  std_logic;       


        -- DDR2 interface signals
        ddr2_addr        : out   std_logic_vector(12 downto 0);
        ddr2_ba          : out   std_logic_vector(2 downto 0);
        ddr2_ras_n       : out   std_logic;
        ddr2_cas_n       : out   std_logic;
        ddr2_we_n        : out   std_logic;
        ddr2_ck_p        : out   std_logic_vector(0 downto 0);
        ddr2_ck_n        : out   std_logic_vector(0 downto 0);
        ddr2_cke         : out   std_logic_vector(0 downto 0);
        ddr2_cs_n        : out   std_logic_vector(0 downto 0);
        ddr2_dm          : out   std_logic_vector(1 downto 0);
        ddr2_odt         : out   std_logic_vector(0 downto 0);
        ddr2_dq          : inout std_logic_vector(15 downto 0);
        ddr2_dqs_p       : inout std_logic_vector(1 downto 0);
        ddr2_dqs_n       : inout std_logic_vector(1 downto 0)
   );
-- Attributes for debug
--     attribute   dont_touch    :   string;
--     attribute   dont_touch  of  MIDI_Soc  :   entity  is  "true";
end MIDI_Soc;

architecture Behavioral of MIDI_Soc is
----------------------------------------------------------------------------------
-- CONSTANTS DECLARATIONS
---------------------------------------------------------------------------------- 
  constant FREQ             : natural := 75_000; -- Freq provided by RamCntrl component
  constant BAUDRATE_BL      : natural := 115200;
  constant FIFO_DEPTH_BL    : natural := 8;
  constant NUM_NOTES_GEN    : natural := 16;

  constant MAX_NUM_TRACKS   : natural := 6;

----------------------------------------------------------------------------------
-- COMMON USE SIGNALS
---------------------------------------------------------------------------------- 
-- Reset signals
signal reset                : std_logic;
signal reset_sync           : std_logic;
signal rst_n                : std_logic;
signal rst                  : std_logic;
signal locked               : std_logic;

-- 200 MHz buffered clock signal
signal clk_200MHz           : std_logic;

-- 7 segs
signal segRight_n0,segRight_n1,segRight_n2,segRight_n3  : std_logic_vector(5 downto 0);
signal segLeft_n0,segLeft_n1,segLeft_n2, segLeft_n3     : std_logic_vector(5 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS FOR BUTTONS
---------------------------------------------------------------------------------- 
-- BTNC
signal  sysStartButton      : std_logic;
-- BTNU
signal  playSongButton      : std_logic;
-- BTNL
signal  reverbOnOffButton   : std_logic;
-- BNTD
signal  externInterface     : std_logic;

----------------------------------------------------------------------------------
-- SIGNALS FOR RAM CNTRL
----------------------------------------------------------------------------------
signal  rdWr    :   std_logic;
signal  ui_clk  :   std_logic;

-- Buffers and signals to manage the read request commands
signal  inCmdReadBuffer_0     	:	std_logic_vector(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1+24 downto 0); -- For midi parser component 
signal  wrRqtReadBuffer_0     	:	std_logic; 
signal  fullCmdReadBuffer_0		:	std_logic;

signal  inCmdReadBuffer_1     	:	std_logic_vector(25+log2(NUM_NOTES_GEN) downto 0); -- For KeyboardCntrl component
signal  wrRqtReadBuffer_1       :   std_logic;
signal  fullCmdReadBuffer_1     :   std_logic;

-- Buffers and signals to manage the read response commands
signal	rdRqtReadBuffer_0		     :  std_logic;
signal	outCmdReadBuffer_0		     :  std_logic_vector(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1+127 downto 0); -- Cmd response buffer for Midi parser component
signal	emptyResponseRdBuffer_0	     :  std_logic;
 
signal	rdRqtReadBuffer_1		     :	std_logic;
signal	outCmdReadBuffer_1		     :	std_logic_vector(15+log2(NUM_NOTES_GEN) downto 0);	-- Cmd response buffer for KeyboardCntrl component
signal	emptyResponseRdBuffer_1	     :	std_logic;	

-- Buffer and signals to manage the writes commands
signal    inCmdWriteBuffer      :    std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
signal    wrRqtWriteBuffer      :    std_logic;
signal    fullCmdWriteBuffer    :    std_logic;
signal    writeWorking          :    std_logic; -- High when the RamCntrl is executing some write command, low when no writes 

----------------------------------------------------------------------------------
-- SIGNALS FOR MAIN CONTROLLER
----------------------------------------------------------------------------------
signal  muxControlSignals       :   std_logic;
signal  cen                     :   std_logic_vector(1 downto 0);
signal  mainControllerStatus    :   std_logic_vector(4 downto 0);
signal  externInterfaceStatus   :   std_logic;
signal  playSong                :   std_logic;
signal  reverbOnOff_interface   :   std_logic;
signal  reverbOnOff             :   std_logic;
signal  reverbStatus            :   std_logic;

----------------------------------------------------------------------------------
-- SIGNALS FOR SETUP
----------------------------------------------------------------------------------
signal iniSetup                 :   std_logic;
signal finSetup                 :   std_logic;
signal setupCen                 :   std_logic;

signal setupAddr                :   std_logic_vector(22 downto 0);
signal wrRqtWriteBuffer_Setup   :   std_logic;
signal inCmdWriteBuffer_Setup   :   std_logic_vector(41 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS FOR EXTERN INTERFACE CMD RECEIVER COMPONENT
----------------------------------------------------------------------------------
signal  loadMidiFile_interface      :   std_logic;
signal  finishFileReception         :   std_logic;
signal  wrRqtWriteBuffer_interface  :   std_logic;
signal  playSong_interface          :   std_logic;
signal  inCmdWriteBuffer_interface  :   std_logic_vector(41 downto 0);
signal  keyboardCmd_interface       :   std_logic_vector(14 downto 0);

--------------------------------------------------------------------
-- CMD KEYBOARD SEQUENCER 
--------------------------------------------------------------------
signal  sequencerAck, sendCmdRqt    :   std_logic_vector(1 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS FOR MIDI PARSER
----------------------------------------------------------------------------------
signal  readMidifileRqt, OnOff    :   std_logic;
signal  OnOffSong, fileOk         :   std_logic;
signal  cmdMidiParser             :   std_logic_vector(14 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS FOR KEYBOARD
----------------------------------------------------------------------------------
signal	  aviableCmd	        :	std_logic;
signal    cmdKeyboard           :   std_logic_vector(14 downto 0);
signal    keyboard_ack          :   std_logic;
signal    numGensOn             :   std_logic_vector(15 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS FOR I2S COMPONENTS
----------------------------------------------------------------------------------
signal sampleRqt        :   std_logic;
signal mclk,sclk,lrck   :   std_logic;
signal sampleOut        :   std_logic_vector(23 downto 0);

----------------------------------------------------------------------------------
-- DEBUG SIGNALS
----------------------------------------------------------------------------------  


begin

----------------------------------------------------------------------------------
-- 200MHz CLOCK GENERATOR
--------------------------------------------------------------------------------
Inst_ClkGen: ClkGen
port map (clk_100MHz_i   => clk_i,
          clk_200MHz_o   => clk_200MHz,
          resetn        => resetn_i,
          locked       => locked
          );

----------------------------------------------------------------------------------
-- RESET SYNCRONIZER
----------------------------------------------------------------------------------
resetSyncronizer : synchronizer
generic map ( STAGES => 2, INIT => '0' )
port map ( rst_n => resetn_i, clk => clk_200MHz, x => '1', xSync => reset_sync );

-- Assign reset signals conditioned by the PLL lock
rst <= (not reset_sync) or (not locked);
rst_n <= not rst;

------------------------------------------------------------------------
-- MEMORY CONTROLLER
------------------------------------------------------------------------
Ram: RamCntrl
   generic map( NUM_NOTES_GEN=>NUM_NOTES_GEN, MAX_NUM_TRACKS=> MAX_NUM_TRACKS)
   port map(                    					
      -- Common                 
      clk_200MHz_i				=> clk_200MHz,
      rst_n      				=> rst_n,
      ui_clk_o    				=> ui_clk,
      
      -- Ram Cntrl Interface
	  rdWr						=> rdWr,  -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     	=> inCmdReadBuffer_0, -- For midi parser component 
	  wrRqtReadBuffer_0     	=> wrRqtReadBuffer_0, 
	  fullCmdReadBuffer_0		=> fullCmdReadBuffer_0, 
								 
	  inCmdReadBuffer_1     	=> inCmdReadBuffer_1, -- For KeyboardCntrl component
      wrRqtReadBuffer_1         => wrRqtReadBuffer_1, 
      fullCmdReadBuffer_1       => fullCmdReadBuffer_1, 
      
      -- Buffers and signals to manage the read response commands
      rdRqtReadBuffer_0            => rdRqtReadBuffer_0,
      outCmdReadBuffer_0           => outCmdReadBuffer_0,-- Cmd response buffer for Midi parser component
      emptyResponseRdBuffer_0      => emptyResponseRdBuffer_0,
                                
      rdRqtReadBuffer_1            => rdRqtReadBuffer_1,
      outCmdReadBuffer_1           => outCmdReadBuffer_1,
      emptyResponseRdBuffer_1      => emptyResponseRdBuffer_1,

      -- Buffer and signals to manage the writes commands
      inCmdWriteBuffer            => inCmdWriteBuffer,-- For setup component and store midi file from BL component
      wrRqtWriteBuffer            => wrRqtWriteBuffer,
      fullCmdWriteBuffer          => fullCmdWriteBuffer,
      writeWorking                => writeWorking, 
		
      -- DDR2 interface
      ddr2_addr            => ddr2_addr,
      ddr2_ba              => ddr2_ba,
      ddr2_ras_n           => ddr2_ras_n,
      ddr2_cas_n           => ddr2_cas_n,
      ddr2_we_n            => ddr2_we_n,
      ddr2_ck_p            => ddr2_ck_p,
      ddr2_ck_n            => ddr2_ck_n,
      ddr2_cke             => ddr2_cke,
      ddr2_cs_n            => ddr2_cs_n,
      ddr2_dm              => ddr2_dm,
      ddr2_odt             => ddr2_odt,
      ddr2_dq              => ddr2_dq,
      ddr2_dqs_p           => ddr2_dqs_p,
      ddr2_dqs_n           => ddr2_dqs_n
   );

-------------------------------------
-- BUTTONS SYNC DEB AND EDGE DETECTOR
-------------------------------------
  
buttonsSignalProcessing: ButtonsSyncDebRiseEdge
  generic map(	FREQ =>FREQ)
  port map(
    -- Host side
    rst_n      => rst_n,
    clk        => ui_clk,
    btnc_i     => btnc_i,
    btnu_i     => btnu_i,
	btnl_i	   => btnl_i,
	btnd_i     => btnd_i,
	
	xRise_btnc => sysStartButton,
	xRise_btnu => playSongButton,
	xRise_btnl => reverbOnOffButton,
	xRise_btnd => externInterface
	
  );

----------------------------------------------------------------------------------
-- SEVEN SEGMENT DISPLAY AND LEDS
----------------------------------------------------------------------------------
RegbLedController: RgbLed
  generic map(FREQ => FREQ)
  port map(
    -- Host side
    rst_n                   	=> rst_n,
    clk                     	=> ui_clk,
	fileOk 						=> fileOk,
	externInterfaceStatus       => externInterfaceStatus,
	playSong                    => playSong,
	mainControllerStatus		=> mainControllerStatus,
								
	-- LD16 PWM output signals  
	pwm1_red_o 					=> rgb1_red_o,
	pwm1_green_o 				=> rgb1_green_o,
	pwm1_blue_o 				=> rgb1_blue_o,
								
	-- LD17 PWM output signals	
	pwm2_red_o 					=> rgb2_red_o,
	pwm2_green_o 				=> rgb2_green_o,
	pwm2_blue_o 				=> rgb2_blue_o
	
  );



     
sSegs : bin2segNexys4 
    port map (         
        rst_n      => rst_n,
        clk        => ui_clk,
         
        -- Right Side
        segRight_n0 => segRight_n0,
        segRight_n1 => segRight_n1,
        segRight_n2 => segRight_n2,
        segRight_n3 => segRight_n3,
    
        -- Left Side
        segLeft_n0 => segLeft_n0,
        segLeft_n1 => segLeft_n1,
        segLeft_n2 => segLeft_n2,
        segLeft_n3 => segLeft_n3,
    
        -- Out signals
        disp_seg_o => disp_seg_o, 
        disp_an_o  => disp_an_o
     );


    -- Right Side
    segRight_n0 <= "10" & inCmdWriteBuffer(3 downto 0) when muxControlSignals='0' else "10" & cmdKeyboard(3 downto 0);
    segRight_n1 <= "10" & inCmdWriteBuffer(7 downto 4) when muxControlSignals='0' else "10" & cmdKeyboard(7 downto 4);
    segRight_n2 <=  "10" & inCmdWriteBuffer(11 downto 8) when muxControlSignals='0' else "10" & cmdKeyboard(11 downto 8);
    segRight_n3 <=  "10" & inCmdWriteBuffer(15 downto 12) when muxControlSignals='0' else "100" & cmdKeyboard(14 downto 12);

    -- Left Side
    segLeft_n0 <= "10" & inCmdWriteBuffer(19 downto 16) when muxControlSignals='0' else "10" & numGensOn(3 downto 0); 
    segLeft_n1 <= "10" & inCmdWriteBuffer(23 downto 20) when muxControlSignals='0' else "10" & numGensOn(7 downto 4);
    segLeft_n2 <= "10" & inCmdWriteBuffer(27 downto 24) when muxControlSignals='0' else "10" & numGensOn(11 downto 8);
    segLeft_n3 <= "10" & inCmdWriteBuffer(31 downto 28) when muxControlSignals='0' else "10" & numGensOn(15 downto 12);   
    
    
    led_o(13 downto 10) <=(others=>'0');
    
----------------------------------------------------------------------------------
-- MAIN CONTROLLER COMPONENT
---------------------------------------------------------------------------------- 
-- Multiplexor for RamCntrl write buffer
inCmdWriteBuffer <= inCmdWriteBuffer_Setup when finSetup='0' else inCmdWriteBuffer_interface;
wrRqtWriteBuffer <= wrRqtWriteBuffer_Setup when finSetup='0' else wrRqtWriteBuffer_interface;


led_o(4 downto 0) <=mainControllerStatus;
led_o(14) <= reverbStatus;


playSong <= playSongButton or playSong_interface;
reverbOnOff <= reverbOnOffButton or reverbOnOff_interface;

ControllerComponent: MainController
  port map(
    clk   				   => ui_clk,
    rst_n                  => rst_n,
                         
    -- For RGBLed          
    currentState           => mainControllerStatus,
                         
    -- Buttons             
    sysStart               => sysStartButton,
    playSong               => playSong,
    loadMidiFile           => loadMidiFile_interface,
    reverbOnOff            => reverbOnOff,
    externInterface        => externInterface,
                         
    -- For MidiParser      
    OnOffSong              => OnOffSong,
    readMidifileRqt        => readMidifileRqt,
                         
    -- For Setup Component 
    finSetup               => finSetup,
    iniSetup               => iniSetup,
    
    -- ExternInterfaceCmdReceiver
    finishFileReception    => finishFileReception,
    externInterfaceStatus  => externInterfaceStatus,
    
    -- For KeyboardCntrl
    reverbStatus           => reverbStatus,
                         
    -- Enable and Control  
    cenComponents          => cen,
    muxControlSignals      => muxControlSignals,
    memRdWr                => rdWr 

      
    );
    
----------------------------------------------------------------------------------
-- SETUP COMPONENT, FILL THE MEMORY WITH SAMPLES, CONSTANTS AND MIDI EXAMPLE FILE
---------------------------------------------------------------------------------- 
SetupComponent: MySetup
  port map(
        clk         => ui_clk,
        rst_n       => rst_n,      
       
	   ini          => iniSetup,
       fin          => finSetup,    
      
      -- Mem
      memWrWorking  => writeWorking,
      fullFifo      => fullCmdWriteBuffer,
      wrMemCMD      => wrRqtWriteBuffer_Setup,
      memCmd        => inCmdWriteBuffer_Setup,
      
      -- SPI signals
      cs_n          => cs_n,   
      io0           => io0,
      io1           => io1

  );
  
----------------------------------------------------------------------------------
-- LOAD MIDI FILE BT COMPONENT
----------------------------------------------------------------------------------
-- Reset of the Bluethooth pmod device
btRst_n <= rst_n;

InterfaceCommunicationComponent: ExternInterfaceCmdReceiver -- 5820392 2B Addr, since this addres (including it), midi file data starts, for 11640784 
    generic map( START_ADDR=> 5754856, -- 5754856 2B Addr, since this addres (including it), midi file data starts, for 11509712 
                 FREQ=> FREQ,
                 BAUDRATE=> BAUDRATE_BL,
                 FIFO_DEPTH=> FIFO_DEPTH_BL ) 
    port map(
    -- Host side
    rst_n                       => rst_n,  
    clk                         => ui_clk,
                                
    -- Common use               
    externInterfaceStatus        => externInterfaceStatus,

    
    -- Ctrl signals for File Reception
    loadMidiFile                 => loadMidiFile_interface,
    finishFileReception          => finishFileReception,
    memIsFull                    => led_o(15),
    
    -- For keyboard CMDs
    sequencerAck                => sequencerAck(0),
    aviableCmd                  => sendCmdRqt(0),
    keyboardCmd                 => keyboardCmd_interface,
    
    -- Play/stop song
    playSong                    => playSong_interface,
    
    -- Enable/Disable reverb effect
    reverbOnOff                 => reverbOnOff_interface,
    
    -- BT side
    btRxD                       => btRxD,

    -- Mem side
    memRdWr                     => rdWr,
    memWrWorking                => writeWorking,
    wrMemCMD                    => wrRqtWriteBuffer_interface,
    memCmd                      => inCmdWriteBuffer_interface
  
 
);  

--------------------------------------------------------------------
-- CMD KEYBOARD SEQUENCER 
--------------------------------------------------------------------
CmdSequencer: CmdKeyboardSequencer
port map( 
    rst_n                 => rst_n,           
    clk                   => ui_clk,
    
    -- Read Tracks Side   
    cmdIn_0               => keyboardCmd_interface,
    cmdIn_1               => cmdMidiParser,
    sendCmdRqt            => sendCmdRqt,
    seq_ack               => sequencerAck,
    
    --Keyboard side       
    keyboard_ack          => keyboard_ack,
    aviableCmd            => aviableCmd,
    cmdKeyboard           => cmdKeyboard
);


---------------------------------------------------------------------------------------
-- MIDI PARSER COMPONENT, READ A MIDI FILE AND SEND KEYBOARD CMDs TO KEYBOARD COMPONENT
---------------------------------------------------------------------------------------
my_midiParser: MidiParser
  generic map(MAX_NUM_TRACKS=> MAX_NUM_TRACKS)
  port map( 
        rst_n           			=> rst_n,
        clk             			=> ui_clk,
		cen							=> cen(0),
		readMidifileRqt				=> readMidifileRqt,
									
		fileOk						=> fileOk,
		OnOff						=> OnOffSong,

        -- Keyboard side
		keyboard_ack	             => sequencerAck(1),
        aviableCmd                   => sendCmdRqt(1),
        cmdKeyboard                  => cmdMidiParser,
        
		-- Debug                    
		statesOut_MidiCntrl			=> led_o(9 downto 5),

        -- Mem side                 
		mem_emptyBuffer				=> emptyResponseRdBuffer_0,
        mem_CmdReadResponse    		=> outCmdReadBuffer_0,
        mem_fullBuffer         		=> fullCmdReadBuffer_0,
        mem_CmdReadRequest		    => inCmdReadBuffer_0,
		mem_readResponseBuffer		=> rdRqtReadBuffer_0,
        mem_writeReciveBuffer     	=> wrRqtReadBuffer_0
  );

-----------------------------------------------------------------------------------------
-- KEYBOARD CONTROLLER COMPONENT, READ KEYBOARD CMDs TO TURN ON/OFF THE NOTES
-----------------------------------------------------------------------------------------
my_KeyboardCntrl: KeyboardCntrl
  generic map( NUM_NOTES_GEN => NUM_NOTES_GEN)
  port map( 
      rst_n                       => rst_n,
      clk                         => ui_clk,
      cen                         => cen(1),
      midiParserOnOff             => OnOffSong,
      externInterfaceStatus       => externInterfaceStatus,
      aviableCmd                  => aviableCmd,
      cmdKeyboard                 => cmdKeyboard,
      keyboard_ack                => keyboard_ack,
      
      -- For Reverb component
      reverbStatus                => reverbStatus,

      
      --IIS side                  
      sampleRqt                   => sampleRqt,
      sampleOut                   => sampleOut,
	  
     --Keybaord Info                      
      numGensOn                   => numGensOn(log2(NUM_NOTES_GEN) downto 0),
	 
      -- Mem side                 
      mem_emptyBuffer             => emptyResponseRdBuffer_1,
      mem_CmdReadResponse         => outCmdReadBuffer_1,
      mem_fullBuffer              => fullCmdReadBuffer_1,
      mem_CmdReadRequest          => inCmdReadBuffer_1,
      mem_readResponseBuffer      => rdRqtReadBuffer_1,
      mem_writeReciveBuffer       => wrRqtReadBuffer_1

);

-----------------------------------------------------------------------------------------
-- I2S INTERFACE
-----------------------------------------------------------------------------------------    
    mclkAD <= mclk;
    sclkAD <= sclk;
    lrckAD <= lrck;
    
    mclkDA <= mclk;
    sclkDA <= sclk;
    lrckDA <= lrck;

    
--- 24 bit audio --
codecInterface : iisInterface_75Mhz
     generic map( WIDTH =>24 ) 
     port map( 
        rst_n => rst_n, clk => ui_clk, 
        leftChannel => open, inSample => open, inSampleRdy => open, outSample =>sampleOut , outSampleRqt => sampleRqt,
        mclk => mclk, sclk => sclk, lrck => lrck, sdti => sdti, sdto => '0'
     );


end Behavioral;
