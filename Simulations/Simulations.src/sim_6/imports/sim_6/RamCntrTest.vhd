----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name: RamCntrlTest - Behavioral
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

entity RamCntrlTest is
--  Port ( );
end RamCntrlTest;

architecture Behavioral of RamCntrlTest is
component RamCntrl is
   Generic(CACHE_SIZE   :   in  natural); -- Number of rows of the cache
   port (
         -- Only for Test
        clk                       :   in  std_logic;
        
        statesOut                 :   out std_logic_vector(9 downto 0);
        
        memOut_addr            :     out    std_logic_vector(25 downto 0);
        memOut_cen            :    out    std_logic;
        memOut_rd             :    out    std_logic;
        memOut_wr             :    out    std_logic;
        memOut_ack            :    out    std_logic;
        memOut_data_in        :    out    std_logic_vector(15 downto 0);
        memOut_data_out       :    out    std_logic_vector(127 downto 0);
        --
      
      
      -- Common
      clk_200MHz_i				:	in    std_logic; -- 200 MHz system clock
      rst_n      				:	in    std_logic; -- active low system reset
      ui_clk_o    				:	out   std_logic;

      -- Ram Cntrl Interface
	  rdWr						:	in	std_logic; -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     	:	in	std_logic_vector(26 downto 0); -- For midi parser component 
	  wrRqtReadBuffer_0     	:	in	std_logic; 
	  fullCmdReadBuffer_0		:	out	std_logic;
		
	  inCmdReadBuffer_1     	:	in	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
      wrRqtReadBuffer_1			:	in	std_logic;
	  fullCmdReadBuffer_1		:	out	std_logic;
	  
	  -- Buffers and signals to manage the read response commands
	  rdRqtReadBuffer_0			:	in	std_logic;
	  outCmdReadBuffer_0		:	out	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
	  emptyResponseRdBuffer_0	:	out	std_logic;
	  
	  rdRqtReadBuffer_1			:	in	std_logic;
	  outCmdReadBuffer_1		:	out	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
	  emptyResponseRdBuffer_1	:	out	std_logic;	  

	  -- Buffer and signals to manage the writes commands
	  inCmdWriteBuffer			:	in	std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
	  wrRqtWriteBuffer			:	in	std_logic;
	  fullCmdWriteBuffer		:	out	std_logic;
      emptyCmdWriteBufferOut    :	out	std_logic;
	  writeWorking				:	out	std_logic -- High when the RamCntrl is executing some write command, low when no writes 
		
      -- DDR2 interface	
--      ddr2_addr            		: 	out   std_logic_vector(12 downto 0);
--      ddr2_ba              		: 	out   std_logic_vector(2 downto 0);
--      ddr2_ras_n           		: 	out   std_logic;
--      ddr2_cas_n           		: 	out   std_logic;
--      ddr2_we_n            		: 	out   std_logic;
--      ddr2_ck_p            		: 	out   std_logic_vector(0 downto 0);
--      ddr2_ck_n            		: 	out   std_logic_vector(0 downto 0);
--      ddr2_cke             		: 	out   std_logic_vector(0 downto 0);
--      ddr2_cs_n            		: 	out   std_logic_vector(0 downto 0);
--      ddr2_odt             		: 	out   std_logic_vector(0 downto 0);
--      ddr2_dq              		: 	inout std_logic_vector(15 downto 0);
--      ddr2_dm              		: 	out   std_logic_vector(1 downto 0);
--      ddr2_dqs_p           		: 	inout std_logic_vector(1 downto 0);
--      ddr2_dqs_n           		: 	inout std_logic_vector(1 downto 0)
   );	
   
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  RamCntrl  :   entity  is  "true";   
end component;


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
    
    signal  inCmdReadBuffer_1     	:	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
    signal  wrRqtReadBuffer_1       :    std_logic;
    signal  fullCmdReadBuffer_1     :    std_logic;

    -- Buffers and signals to manage the read response commands
    signal	rdRqtReadBuffer_0		:	std_logic;
    signal	outCmdReadBuffer_0		:	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
    signal	emptyResponseRdBuffer_0	:	std_logic;

    signal	rdRqtReadBuffer_1		:	std_logic;
    signal	outCmdReadBuffer_1		:	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
    signal	emptyResponseRdBuffer_1	:	std_logic;	 
    
    -- Buffer and signals to manage the writes commands
    signal    inCmdWriteBuffer   :    std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
    signal    wrRqtWriteBuffer   :    std_logic;
    signal    fullCmdWriteBuffer, emptyCmdWriteBufferOut :    std_logic;
    signal    writeWorking       :    std_logic; -- High when the RamCntrl is executing some write command, low when no writes 
    
    
    
    -- Only Test
    signal memOut_addr           :   std_logic_vector(25 downto 0);
    signal memOut_cen            :   std_logic;
    signal memOut_rd             :   std_logic;
    signal memOut_wr             :   std_logic;
    signal memOut_ack            :   std_logic;
    signal memOut_data_in        :   std_logic_vector(15 downto 0);
    signal memOut_data_out       :   std_logic_vector(127 downto 0);
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
    
	  -- Buffers and signals to manage the read request commands
    inCmdReadBuffer_0         <= (others=>'0');
    wrRqtReadBuffer_0         <= '0';
                                 
    inCmdReadBuffer_1         <= (others=>'0');
    wrRqtReadBuffer_1            <= '0';
    
    -- Buffers and signals to manage the read response commands
    rdRqtReadBuffer_0         <= '0';
                                
    rdRqtReadBuffer_1            <= '0';

    -- Buffer and signals to manage the writes commands
    inCmdWriteBuffer            <= (others=>'0');
    wrRqtWriteBuffer            <= '0';
    
	wait until (rst_n='1');
	
	wait for (clkPeriod*5);
	
    -------------------------
    -- Send two writes CMD --
    -------------------------
    inCmdWriteBuffer          <= std_logic_vector(to_unsigned(297,26))& X"f9ff";
    wrRqtWriteBuffer          <= '1';
    wait for (clkPeriod);
    
    inCmdWriteBuffer          <= std_logic_vector(to_unsigned(280,26))& X"fAff";
    wait for (clkPeriod);
    wrRqtWriteBuffer          <= '0';
    
    wait until emptyCmdWriteBufferOut='0'and writeWorking='0'; -- To be sure that all the writings are done
    
    rdWr <='1'; -- Read mode
    
    ---------------------------------------------
    -- Send two reads CMD in inCmdReadBuffer_1 --
    ---------------------------------------------
    inCmdReadBuffer_1          <= "0000000" & std_logic_vector(to_unsigned(2391,26)); -- Get the last sample 
    wrRqtReadBuffer_1          <='1';
    wait for (clkPeriod);
    
    -- Testing Quick read feature
    inCmdReadBuffer_1          <= "0000010" & std_logic_vector(to_unsigned(2390,26)); -- Get the penultimate sample 
    wrRqtReadBuffer_1          <='1';
    wait for (clkPeriod);
    wrRqtReadBuffer_1          <='0';
    
    -- Recive response of the first CMD in inCmdReadBuffer_1
    wait until emptyResponseRdBuffer_1='0';
    rdRqtReadBuffer_1<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_1<='0';
    
    -- Recive response of the second CMD in inCmdReadBuffer_1
    wait until emptyResponseRdBuffer_1='0';
    rdRqtReadBuffer_1<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_1<='0';

    ------------------------------------------
    -- Three reads CMD in inCmdReadBuffer_0 --
    ------------------------------------------
    inCmdReadBuffer_0          <= "00" & std_logic_vector(to_unsigned(0,25));-- Addr per 16B
    wrRqtReadBuffer_0          <='1';
    wait for (clkPeriod);
    
    -- Testing CMD from OneDividedByDivisionProvider
    inCmdReadBuffer_0          <= "11" & std_logic_vector(to_unsigned(3,25)); -- Addr per 4B
    wrRqtReadBuffer_0          <='1';
    wait for (clkPeriod);
   
    -- Testing CMD from OneDividedByDivisionProvider
    inCmdReadBuffer_0          <= "11" & std_logic_vector(to_unsigned(4,25)); -- Addr per 4B
    wrRqtReadBuffer_0          <='1';
    wait for (clkPeriod);
    wrRqtReadBuffer_0          <='0';

    -- Recive response of the first CMD in inCmdReadBuffer_0
    wait until emptyResponseRdBuffer_0='0';
    rdRqtReadBuffer_0<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_0<='0';
    
    -- Recive response of the second CMD in inCmdReadBuffer_0
    wait until emptyResponseRdBuffer_0='0';
    rdRqtReadBuffer_0<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_0<='0';

    -- Recive response of the third CMD in inCmdReadBuffer_0
    wait until emptyResponseRdBuffer_0='0';
    rdRqtReadBuffer_0<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_0<='0';
    
    --------------------------------------------------------------
    -- Two reads CMD in inCmdReadBuffer_0 and inCmdReadBuffer_1 --
    --------------------------------------------------------------
    inCmdReadBuffer_0          <= "01" & std_logic_vector(to_unsigned(1,25));-- Addr per 16B
    wrRqtReadBuffer_0          <='1';
    inCmdReadBuffer_1          <= "0000011" & std_logic_vector(to_unsigned(2376,26)); -- Addr per 8B, Get the first sample, size of sample 16 bits
    wrRqtReadBuffer_1          <='1';
    wait for (clkPeriod);
    
    -- Testing CMD from OneDividedByDivisionProvider
    inCmdReadBuffer_0          <= "11" & std_logic_vector(to_unsigned(1,25));-- Addr per 4B
    wrRqtReadBuffer_0          <='1';
    inCmdReadBuffer_1          <= "0000011" & std_logic_vector(to_unsigned(2377,26)); -- Addr per 8B, Get the second sample, size of sample 16 bits 
    wrRqtReadBuffer_1          <='1';
    wait for (clkPeriod);
    wrRqtReadBuffer_0          <='0';
    wrRqtReadBuffer_1          <='0';
    
    --Testing out buffers behaviour Waiting to fill the buffers
    wait for (clkPeriod*20);

    -- Recive first CMD of inCmdReadBuffer_1
--    wait until emptyResponseRdBuffer_1='0';
    rdRqtReadBuffer_1<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_1<='0';

    --Testing out buffers behaviour Waiting to fill the buffers
    wait for (clkPeriod*20);

    
    -- Recive second CMD of inCmdReadBuffer_1
    rdRqtReadBuffer_1<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_1<='0';

    --Testing out buffers behaviour Waiting to fill the buffers
    wait for (clkPeriod*20);
    
    -- Recive first CMD of inCmdReadBuffer_0
    rdRqtReadBuffer_0<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_0<='0';

    --Testing out buffers behaviour Waiting to fill the buffers
    wait for (clkPeriod*20);
        
    -- Recive second CMD of inCmdReadBuffer_0
    rdRqtReadBuffer_0<='1';
    wait for (clkPeriod);
    rdRqtReadBuffer_0<='0';
    
    wait;

end process;

Ram: RamCntrl
   generic map(CACHE_SIZE=>2) -- Number of rows of the cache
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
								 
	  inCmdReadBuffer_1     	=> inCmdReadBuffer_1, -- For KeyboardCntrl component
      wrRqtReadBuffer_1			=> wrRqtReadBuffer_1, 
	  fullCmdReadBuffer_1		=> fullCmdReadBuffer_1, 
	  
	  -- Buffers and signals to manage the read response commands
	  rdRqtReadBuffer_0			=> rdRqtReadBuffer_0,
	  outCmdReadBuffer_0		=> outCmdReadBuffer_0,-- Cmd response buffer for Midi parser component
	  emptyResponseRdBuffer_0	=> emptyResponseRdBuffer_0,
								
	  rdRqtReadBuffer_1			=> rdRqtReadBuffer_1,
	  outCmdReadBuffer_1		=> outCmdReadBuffer_1,-- Cmd response buffer for KeyboardCntrl component
	  emptyResponseRdBuffer_1	=> emptyResponseRdBuffer_1,

	  -- Buffer and signals to manage the writes commands
	  inCmdWriteBuffer			=> inCmdWriteBuffer,-- For setup component and store midi file BL component
	  wrRqtWriteBuffer			=> wrRqtWriteBuffer,
	  fullCmdWriteBuffer		=> fullCmdWriteBuffer,
      emptyCmdWriteBufferOut    => emptyCmdWriteBufferOut,
	  writeWorking				=> writeWorking-- High when the RamCntrl is executing some write command, low when no writes 
		
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


end Behavioral;
