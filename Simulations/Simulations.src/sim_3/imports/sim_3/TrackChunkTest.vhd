----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name:  - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TrackChunkTest is
--  Port ( );
end TrackChunkTest;

architecture Behavioral of TrackChunkTest is

component MidiRom is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		addr			:	in	std_logic_vector(22 downto 0);
        readByteRqt_n	:	in	std_logic; -- One cycle low to request a read
		ack			    :	out	std_logic; -- One cycle high to notify the reception of a new byte
		data			:	out	std_logic_vector(127 downto 0)
  );
end component;


component ByteProvider is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		addrInVal		:	in	std_logic_vector(26 downto 0); -- Byte addres
		byteRqt			:	in	std_logic; -- One cycle high to request a new byte
		
		byteAck			:	out	std_logic; -- One cycle high to notify the reception of a new byte
		nextByte        :   out	std_logic_vector(7 downto 0);
		
		-- Mem side
		mem_ack			:	in	std_logic;
		mem_dataIn		:	in	std_logic_vector(127 downto 0);
		
		mem_readRqt_n	:	out std_logic; -- Active low
		mem_addr		:	out std_logic_vector(22 downto 0)
		
  );
end component;

component ReadTrackChunk is
  Port ( 
      rst_n                   :   in  std_logic;
      clk                     :   in  std_logic;
      cen                     :   in std_logic;
      readRqt                    :    in    std_logic_vector(1 downto 0); -- One cycle high to request a read 
      trackAddrStart            :    in std_logic_vector(26 downto 0); -- Must be stable for the whole read
      OneDividedByDivision    :    in std_logic_vector(23 downto 0); -- Q4.20
      finishRead                :    out std_logic; -- One cycle high to notify the end of track reached
      trackOK                    :    out    std_logic; -- High track data is ok, low track data is not ok            
      notesOn                    :    out std_logic_vector(87 downto 0);
              
      --Debug        
      regAuxOut               : out std_logic_vector(31 downto 0);
      regAddrOut              : out std_logic_vector(26 downto 0);
      statesOut               : out std_logic_vector(8 downto 0);
      runningStatusOut        : out std_logic_vector(7 downto 0);  
      dataBytesOut            : out std_logic_vector(15 downto 0);
      regWaitOut              : out std_logic_vector(17 downto 0);
       
      --Byte provider side
      nextByte                :   in  std_logic_vector(7 downto 0);
      byteAck                    :    in    std_logic; -- One cycle high to notify the reception of a new byte
      byteAddr                :   out std_logic_vector(26 downto 0);
      byteRqt                    :    out std_logic -- One cycle high to request a new byte

);
end component;

    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)

    
-- Señales 
    signal clk                  : std_logic := '1';      
    signal rst_n                : std_logic := '0';
        
    --Rom
    signal rom_addr             :   std_logic_vector(22 downto 0);
    signal rom_readRqt, rom_ack :   std_logic;
    signal rom_data             :   std_logic_vector(127 downto 0);

    -- Byte Provider
     signal BP_addr :   std_logic_vector(26 downto 0);
     signal BP_byteRqt, BP_ack  : std_logic;
     signal BP_data : std_logic_vector(7 downto 0);
     
     -- Read track
     signal startTrackRead  :   std_logic_vector(1 downto 0);
     signal  readFinish, trackOK, cen  : std_logic;
     signal regAuxOut      :   std_logic_vector(31 downto 0);
     
     signal runningStatusOut          : std_logic_vector(7 downto 0);
     signal statesOut               : std_logic_vector(8 downto 0);
     signal iniAddr, regAddrOut : std_logic_vector(26 downto 0);
     signal dataBytesOut    :   std_logic_vector(15 downto 0);
     signal notesOn     :   std_logic_vector(87 downto 0);
     
     signal regWaitOut  :   std_logic_vector(17 downto 0);
     
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
    startTrackRead <=(others=>'0');
    cen <='0';
    wait for ( 50 us + 5 ns + clkPeriod*5);
   
    -- Checking cen feature
    cen <='1';
    wait for (clkPeriod*2);
        -- Order check
        startTrackRead(0) <='1';
    wait for (clkPeriod);
	    startTrackRead(0) <='0';
    
    wait for (clkPeriod*10);       
    cen <='0';
    
    wait for (clkPeriod*10);
    
    -- Order check
    cen <='1';
    wait for (clkPeriod*2);
        
        startTrackRead(0) <='1';
    wait for (clkPeriod);
        startTrackRead(0) <='0';
        
    
    wait until readFinish='1' and trackOK='1';
    wait for (clkPeriod*2);

    -- Order read
        startTrackRead(1) <='1';
    wait for (clkPeriod);
	    startTrackRead(1) <='0';
    
    wait;

end process;


rom : MidiRom
  Port map( 
        rst_n => rst_n,
        clk => clk,
		addr => rom_addr,			
        readByteRqt_n => rom_readRqt,  
        ack => rom_ack,            
        data => rom_data    
  );

my_ByteProvider : ByteProvider
  Port map( 
        rst_n => rst_n,
        clk => clk,
		addrInVal =>BP_addr,			
        byteRqt =>BP_byteRqt,  
        byteAck => BP_ack,            
        nextByte =>BP_data,
      
        -- Mem side
        mem_ack =>rom_ack,
        mem_dataIn =>rom_data,
        mem_readRqt_n =>rom_readRqt,
        mem_addr =>rom_addr    
  );

iniAddr <= "000" & X"00000e";

my_ReadTrackChunk : ReadTrackChunk
  Port map( 
        rst_n => rst_n,
        clk => clk,
        cen => cen,
		readRqt => startTrackRead,			
        trackAddrStart => iniAddr,
        OneDividedByDivision => X"000889", -- 1/480 Q4.20 format  
        finishRead => readFinish,
        trackOK => trackOK, 
        notesOn => notesOn,
        
        --Debug        
        regAuxOut        =>regAuxOut,
        regAddrOut       =>regAddrOut,
        statesOut        =>statesOut,
        runningStatusOut =>runningStatusOut,
        dataBytesOut     =>dataBytesOut,
        regWaitOut       =>regWaitOut,
        
        -- Mem side
        nextByte =>BP_data,
        byteAck =>BP_ack,
        byteAddr =>BP_addr,
        byteRqt =>BP_byteRqt
  );
  

end Behavioral;
