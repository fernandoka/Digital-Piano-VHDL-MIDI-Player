----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero 
--
-- Create Date: 06.12.2019 17:45:15
-- Design Name: 
-- Module Name: MySetup - Behavioral
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
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity MySetup is
  Generic(START_ADDR    :   in  natural); -- 2B Addr
  Port (
      clk           :   in  std_logic;
      rst_n         :   in std_logic;
      
      ini           :   in  std_logic;
      fin           :   out std_logic;    
      
      -- Mem
      memWrWorking  :   in  std_logic;
	  fullFifo	    :	in	std_logic;
	  wrMemCMD	    :	out	std_logic;
	  memCmd	    :	out	std_logic_vector(41 downto 0);
      
      -- SPI signals
      cs_n          :   out std_logic;   -- selección de esclavo
      io0           :   inout std_logic;    
      io1           :   in  std_logic 

  );
-- Attributes for debug
--  attribute   dont_touch    :   string;
--  attribute   dont_touch  of  MySetup  :   entity  is  "true";   
end MySetup;

architecture Behavioral of MySetup is

     
----------------------------------------------------------------------------------
-- SIGNALS FOR SPI
----------------------------------------------------------------------------------  
signal  contMode        :   std_logic;
--signal  quadMode        :   std_logic;
signal  spiDataOutRdy   :   std_logic;
signal  spiDataIn       :   std_logic_vector (7 downto 0);

signal  spiDataOut      :   std_logic_vector (31 downto 0);
signal  spiDataInRdy    :   std_logic;
signal  spiBusy         :   std_logic;

signal  sck             :   std_logic;
signal  dualMode        :   std_logic;     
     
begin

----------------------------------------------------------------------------------
-- SPI COMPONENT
---------------------------------------------------------------------------------- 
-- 4 cycles/SCK cycle -> BAUDRATE = 75000000/4 = 18750000 baudios 
spiInterface : fastSpiMaster_Dual
  generic map( CLKxBIT=>4) 
  port map( 
        rst_n    => rst_n,
        clk      => clk,
        contMode => contMode,
        dualMode => dualMode, --Not Quad Mode
        dataOutRdy  => spiDataOutRdy,
        dataIn   => spiDataIn,
        dataOut  => spiDataOut,
        dataInRdy_n => spiDataInRdy,
        busy       => spiBusy,
        
        -- SPI side
        sck      => sck,
        ss_n     => cs_n,
        io0      => io0,   
        io1_in      => io1

  );
    
    
    
   -- To use sck signal
   -- STARTUPE2: STARTUP Block
   --            Artix-7
   -- Xilinx HDL Language Template, version 14.7
   STARTUPE2_inst : STARTUPE2
   generic map (
      PROG_USR => "FALSE",  -- Activate program event security feature. Requires encrypted bitstreams.
      SIM_CCLK_FREQ => 0.0  -- Set the Configuration Clock Frequency(ns) for simulation.
   )
   port map (
      CFGCLK => open,       -- 1-bit output: Configuration main clock output
      CFGMCLK => open,     -- 1-bit output: Configuration internal oscillator clock output
      EOS => open,             -- 1-bit output: Active high output signal indicating the End Of Startup.
      PREQ => open,           -- 1-bit output: PROGRAM request to fabric output
      CLK => '0',             -- 1-bit input: User start-up clock input
      GSR => '0',             -- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
      GTS => '0',             -- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
      KEYCLEARB => '0', -- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
      PACK => '0',           -- 1-bit input: PROGRAM acknowledge input
      USRCCLKO => sck,   -- 1-bit input: User CCLK input
      USRCCLKTS => '0', -- 1-bit input: User CCLK 3-state enable input 
      USRDONEO => '1',   -- 1-bit input: User DONE pin output control
      USRDONETS => '1'  -- 1-bit input: User DONE 3-state enable output (parece que podría ser 0)
   );


----------------------------------------------------------------------------------
-- FSM, READ FROM SPI AND SEND WRITE CMD TO MEM
----------------------------------------------------------------------------------
 
FSM:
process(rst_n, clk,memWrWorking)
    
    constant MAX_ADDR : unsigned (22 downto 0) := (others=>'1');
    constant INI_ADDR : unsigned (22 downto 0) := to_unsigned(START_ADDR,23);
    
    -- Flash Commands    
    constant REMS_CMD     : std_logic_vector (7 downto 0) := X"90";
    constant READ_CMD     : std_logic_vector (7 downto 0) := X"03";
    constant DUALREAD_CMD : std_logic_vector (7 downto 0) := X"3B";
    
    
    type state_type is (
        Idle, SendDummy, WaitDummyRecv, ReadFromSpi, readByte0, readByte1,FinishedSetup
    );
    
    variable state          :   state_type;
    variable addrValSpi     :   unsigned (22 downto 0);
    variable finSetupFlag   :   std_logic;
	
begin
    
	fin <= finSetupFlag;

	
  if rst_n = '0' then
    state := Idle;
    addrValSpi := INI_ADDR;
    finSetupFlag :='0';
    wrMemCMD <='0';
    dualMode <='0';
    spiDataOutRdy  <= '0';

  elsif rising_edge(clk) then
    spiDataOutRdy  <= '0';
    wrMemCMD <='0';

		
		
		case state is
            when Idle =>
                if ini ='1' then
                    state := SendDummy;
                end if;

            when SendDummy =>
               if spiBusy='0' then
                   spiDataOutRdy  <= '1';
                   contMode <= '0';
                   dualMode <='0';
                   spiDataOut <= REMS_CMD & X"000000";
                   state := WaitDummyRecv;
               end if;

            when WaitDummyRecv =>
                   if spiBusy='1' then
                        state := ReadFromSpi;
                    end if;
                    
            when ReadFromSpi =>
               if spiBusy='0' then
                   spiDataOutRdy  <= '1';
                   contMode <= '1';
                   dualMode <='1';
                   spiDataOut <=  DUALREAD_CMD & std_logic_vector(addrValSpi) & '0'; -- Inst = DUALREAD_CMD & ini Addr
                   state := readByte0;
               end if;
             
             when readByte0 =>
                 if spiDataInRdy='0' then
                     state := readByte1;
                     memCmd(7 downto 0) <= spiDataIn;
                     if addrValSpi = MAX_ADDR then
                         contMode <='0'; -- The next read it's going to be the last one
                    end if;
                 end if;      
            
             -- If fullFifo is set, return to ReadFromSpi to send again another read command.
             -- If not, will order to the fifo component to write the data in the next cycle,
             -- until the addr reach the MAX_VAL address                      
             when readByte1 =>
                    if spiDataInRdy='0' then
                        if fullFifo='0' then
                            -- Prepare write CMD order
                            wrMemCMD <='1';
                            -- Buile write CMD
                            memCmd(41 downto 8) <="000" & std_logic_vector(addrValSpi-INI_ADDR) & spiDataIn;
                            if addrValSpi < MAX_ADDR then
                                addrValSpi := addrValSpi+1;
                                state := readByte0;
                             elsif addrValSpi = MAX_ADDR then
                                 state := FinishedSetup;
                             end if;
                        else
                            contMode <='0'; -- It's going to do read one more Byte and after start unselection(spiInterface)
                            state := ReadFromSpi;
                        end if;-- fullFifo
                    end if;-- spiDataInRdy

                
            when FinishedSetup =>
                if memWrWorking='0' and finSetupFlag='0' then
                    finSetupFlag :='1';
                end if;
                           
        end case;

  end if;
end process FSM;


end Behavioral;
