----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name: FullMidiParserTest_NoCMD - Behavioral
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

entity FullMidiParserTest_NoCMD is
--  Port ( );
end FullMidiParserTest_NoCMD;

use work.my_common.all;

architecture Behavioral of FullMidiParserTest_NoCMD is

    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)


    -- Señales 
    signal	clk     : std_logic := '1';      
    signal	rst_n   : std_logic := '0';

    -- RamCntrl
    signal  rdWr    :   std_logic;
    
    -- Buffers and signals to manage the read request commands
    signal  inCmdReadBuffer_0     	:	std_logic_vector(26 downto 0); -- For midi parser component 
    signal  wrRqtReadBuffer_0     	:	std_logic; 
    signal  fullCmdReadBuffer_0		:	std_logic;
    
--    signal  inCmdReadBuffer_1     	:	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
--    signal  wrRqtReadBuffer_1       :    std_logic;
--    signal  fullCmdReadBuffer_1     :    std_logic;

    -- Buffers and signals to manage the read response commands
    signal	rdRqtReadBuffer_0		:	std_logic;
    signal	outCmdReadBuffer_0		:	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
    signal	emptyResponseRdBuffer_0	:	std_logic;

--    signal	rdRqtReadBuffer_1		:	std_logic;
--    signal	outCmdReadBuffer_1		:	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
--    signal	emptyResponseRdBuffer_1	:	std_logic;	 
    
--    -- Buffer and signals to manage the writes commands
--    signal    inCmdWriteBuffer   :    std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
--    signal    wrRqtWriteBuffer   :    std_logic;
--    signal    fullCmdWriteBuffer, emptyCmdWriteBufferOut :    std_logic;
--    signal    writeWorking       :    std_logic; -- High when the RamCntrl is executing some write command, low when no writes 
    
    -- Midi parser
    signal  cen, readMidifileRqt, fileOk, OnOff     :   std_logic;
    signal  notesOn                                 :   std_logic_vector(87 downto 0);
    
    -- Only Test
    signal memOut_addr           :   std_logic_vector(25 downto 0);
    signal memOut_cen            :   std_logic;
    signal memOut_rd             :   std_logic;
    signal memOut_wr             :   std_logic;
    signal memOut_ack            :   std_logic;
    signal memOut_data_in        :   std_logic_vector(15 downto 0);
    signal memOut_data_out       :   std_logic_vector(127 downto 0);
    
    signal statesOut_ODBD       :	std_logic_vector(2 downto 0);
    
    signal statesOut_MidiCntrl  :    std_logic_vector(4 downto 0);
    
    signal regAuxHeader         :    std_logic_vector(31 downto 0);
    signal cntrOutHeader        :    std_logic_vector(2 downto 0);
    signal statesOutHeader      :    std_logic_vector(7 downto 0);
    
    signal regAuxOut_0          :    std_logic_vector(31 downto 0);
    signal regAddrOut_0         :    std_logic_vector(26 downto 0);
    signal statesOut_0          :    std_logic_vector(8 downto 0);
    signal runningStatusOut_0   :    std_logic_vector(7 downto 0);
    signal dataBytesOut_0       :	 std_logic_vector(15 downto 0);	    
    signal regWaitOut_0         :    std_logic_vector(17 downto 0);
                                    
    signal regAuxOut_1          :    std_logic_vector(31 downto 0); 
    signal regAddrOut_1         :    std_logic_vector(26 downto 0); 
    signal statesOut_1          :    std_logic_vector(8 downto 0); 
    signal runningStatusOut_1   :    std_logic_vector(7 downto 0);  
    signal dataBytesOut_1       :    std_logic_vector(15 downto 0); 
    signal regWaitOut_1         :    std_logic_vector(17 downto 0);        
    
    --
    
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
    
    rdWr <='0'; --Write mode
    cen <='1';
	readMidifileRqt <='0';
	-- Buffers and signals to manage the read request commands
--    inCmdReadBuffer_1         <= (others=>'0');
--    wrRqtReadBuffer_1            <= '0';
    
--    -- Buffers and signals to manage the read response commands     
--    rdRqtReadBuffer_1            <= '0';

--    -- Buffer and signals to manage the writes commands
--    inCmdWriteBuffer            <= (others=>'0');
--    wrRqtWriteBuffer            <= '0';
    
	wait until (rst_n='1' and clk='1');
    rdWr <='1'; -- Read mode
    cen <='0';
    
	wait for (clkPeriod*5);
	
	readMidifileRqt <='1';
    wait for (clkPeriod);
	readMidifileRqt <='0';
	    
    wait;

end process;

Ram: RamCntrl
   generic map(CACHE_SIZE => 2)
   port map(                    
         -- Only for Test       
        clk   					=> clk,
        
		memOut_addr		=> memOut_addr,
        memOut_cen      => memOut_cen,
        memOut_rd       => memOut_rd,
        memOut_wr       => memOut_wr,
        memOut_ack        => memOut_ack,
        memOut_data_in  => memOut_data_in,
        memOut_data_out    => memOut_data_out,
                  
        --                      
								
								
      -- Common                 
      clk_200MHz_i				=> '1',
      rst_n      				=> rst_n,
      ui_clk_o    				=> open,

      -- Ram Cntrl Interface
	  rdWr						=> rdWr,  -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     	=> inCmdReadBuffer_0, -- For midi parser component 
	  wrRqtReadBuffer_0     	=> wrRqtReadBuffer_0, 
	  fullCmdReadBuffer_0		=> fullCmdReadBuffer_0, 
								 
	  inCmdReadBuffer_1     	=> (others=>'0'), --inCmdReadBuffer_1, -- For KeyboardCntrl component
      wrRqtReadBuffer_1         => '0', --wrRqtReadBuffer_1, 
      fullCmdReadBuffer_1       => open, --fullCmdReadBuffer_1, 
      
      -- Buffers and signals to manage the read response commands
      rdRqtReadBuffer_0            => rdRqtReadBuffer_0,
      outCmdReadBuffer_0           => outCmdReadBuffer_0,-- Cmd response buffer for Midi parser component
      emptyResponseRdBuffer_0      => emptyResponseRdBuffer_0,
                                
      rdRqtReadBuffer_1            => '0', --rdRqtReadBuffer_1,
      outCmdReadBuffer_1           => open, --outCmdReadBuffer_1,-- Cmd response buffer for KeyboardCntrl component
      emptyResponseRdBuffer_1      => open, --emptyResponseRdBuffer_1,

      -- Buffer and signals to manage the writes commands
      inCmdWriteBuffer            => (others=>'0'), --inCmdWriteBuffer,-- For setup component and store midi file BL component
      wrRqtWriteBuffer            => '0', --wrRqtWriteBuffer,
      fullCmdWriteBuffer          => open, --fullCmdWriteBuffer,
      emptyCmdWriteBufferOut      => open, --emptyCmdWriteBufferOut,
      writeWorking                => open --writeWorking-- High when the RamCntrl is executing some write command, low when no writes 
		
      -- DDR2 interface	
--      ddr2_addr            		=>,
--      ddr2_ba              		=>,
--      ddr2_ras_n           		=>,
--      ddr2_cas_n           		=>,
--      ddr2_we_n            		=>,
--      ddr2_ck_p            		=>,
--      ddr2_ck_n            		=>,
--      ddr2_cke             		=>,
--      ddr2_cs_n            		=>,
--      ddr2_odt             		=>,
--      ddr2_dq              		=>,
--      ddr2_dm              		=>,
--      ddr2_dqs_p           		=>,
--      ddr2_dqs_n           		=>,
   );


my_midiParser: MidiParser
  port map( 
        rst_n           			=> rst_n,
        clk             			=> clk,
		cen							=> cen,
		readMidifileRqt				=> readMidifileRqt,
									
		fileOk						=> fileOk,
		OnOff						=> OnOff,
		notesOn						=> notesOn,
									
		-- Debug                    
		statesOut_ODBD				=> statesOut_ODBD,
									
		statesOut_MidiCntrl			=> statesOut_MidiCntrl,
									
		regAuxHeader                => regAuxHeader,
		cntrOutHeader               => cntrOutHeader,
		statesOutHeader             => statesOutHeader,

		regAuxOut_0       			=> regAuxOut_0,
		regAddrOut_0                => regAddrOut_0,
		statesOut_0                 => statesOut_0,
		runningStatusOut_0          => runningStatusOut_0,
		dataBytesOut_0              => dataBytesOut_0,
		regWaitOut_0                => regWaitOut_0,

		regAuxOut_1       			=> regAuxOut_1,
		regAddrOut_1                => regAddrOut_1,
		statesOut_1                 => statesOut_1,
		runningStatusOut_1          => runningStatusOut_1,
		dataBytesOut_1              => dataBytesOut_1,
		regWaitOut_1                => regWaitOut_1,


        -- Mem side                 
		mem_emptyBuffer				=> emptyResponseRdBuffer_0,
        mem_CmdReadResponse    		=> outCmdReadBuffer_0,
        mem_fullBuffer         		=> fullCmdReadBuffer_0,
        mem_CmdReadRequest		    => inCmdReadBuffer_0,
		mem_readResponseBuffer		=> rdRqtReadBuffer_0,
        mem_writeReciveBuffer     	=> wrRqtReadBuffer_0
  );


end Behavioral;
