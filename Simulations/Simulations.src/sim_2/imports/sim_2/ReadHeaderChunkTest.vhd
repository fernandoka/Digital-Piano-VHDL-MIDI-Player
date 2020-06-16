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

entity ReadHeaderChunkTest is
--  Port ( );
end ReadHeaderChunkTest;

architecture Behavioral of ReadHeaderChunkTest is

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

component ReadHeaderChunk is
  Generic(START_ADDR    :   in  natural);
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		readRqt			:	in	std_logic; -- One cycle high to request a read
		finishRead		:	out std_logic; -- One cycle high when the component end to read the header
		headerOk		:	out std_logic; -- High, if the header follow our requirements
		division		:	out std_logic_vector(15 downto 0);
        track0AddrStart	:	out std_logic_vector(26 downto 0);
        track1AddrStart    :    out std_logic_vector(26 downto 0);
        
        --Debug
        regAuxOut       : out std_logic_vector(31 downto 0);
        cntrOut            : out std_logic_vector(2 downto 0);
        statesOut          : out std_logic_vector(7 downto 0);
        
		--Byte provider side
		nextByte        :   in  std_logic_vector(7 downto 0);
		byteAck			:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        :   out std_logic_vector(26 downto 0);
		byteRqt			:	out std_logic -- One cycle high to request a new byte

  );
end component;



component ReadHeaderChunk_2 is
  Generic(START_ADDR    :   in  natural);
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		cen                     :   in 	std_logic;
		readRqt					:	in	std_logic; -- One cycle high to request a read
		finishRead				:	out std_logic; -- One cycle high when the component end to read the header
		headerOk				:	out std_logic; -- High, if the header follow our requirements
		numTracksToRead         :   out std_logic_vector(15 downto 0);
		
		-- OneDividedByDivision_Provider side
        ODBD_ReadRqt			:	out	std_logic;
		division				:	out	std_logic_vector(15 downto 0);
		
		-- Start addreses for the Read Trunk Chunk components
		tracksAddrStart			:	out std_logic_vector(2*27-1 downto 0);
		
		 
		--Byte provider side
		nextByte        		:   in  std_logic_vector(7 downto 0);
		byteAck					:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        		:   out std_logic_vector(26 downto 0);
		byteRqt					:	out std_logic -- One cycle high to request a new byte

  );
end component;


component MilisecondDivisor is
  Generic(FREQ : in natural);-- Frequency in Khz
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		cen				:	in	std_logic;
		Tc				:	out std_logic
		
  );
end component;

    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)

    
-- Señales 
    signal clk                  : std_logic := '1';      
    signal rst_n                : std_logic := '0';
    
    -- Miliseconds counter
    signal miliTc   :   std_logic;
    
    --Rom
    signal rom_addr             :   std_logic_vector(22 downto 0);
    signal rom_readRqt, rom_ack :   std_logic;
    signal rom_data             :   std_logic_vector(127 downto 0);

    -- Byte Provider
     signal BP_addr :   std_logic_vector(26 downto 0);
     signal BP_byteRqt, BP_ack  : std_logic;
     signal BP_data : std_logic_vector(7 downto 0);
     
     -- Read header
     signal startHeaderRead, readFinish, headerOKe  : std_logic;
     signal divisionVal : std_logic_vector(15 downto 0);
     -- For header chunk
--     signal regAux      :   std_logic_vector(31 downto 0);
--     signal cntrOut            :  std_logic_vector(2 downto 0);
--     signal statesOut          : std_logic_vector(7 downto 0);
--     signal track0AddrStartVal, track1AddrStartVal : std_logic_vector(26 downto 0); 
     
     -- For header chunk 2
     signal tracksAddrStart       :   std_logic_vector(2*27-1 downto 0);
     signal ODBD_ReadRqt, cen     :   std_logic;
     signal numTracksToRead       :   std_logic_vector(15 downto 0);
     
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
    cen <='0';
    -- wait for rst_n
    startHeaderRead <='0';
    wait for ( 50 us + 5 ns + clkPeriod*5);
   
    wait for (clkPeriod*2);
        startHeaderRead <='1';
    wait for (clkPeriod);
	    startHeaderRead <='0';

	wait until readFinish='1';
        assert(headerOKe='1')
        report "Bad header chunk parser dosen't work properly" severity error;
        assert(divisionVal=X"01e0")
        report "Bad header chunk parser dosen't work properly, division value fails" severity error;

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

--my_ReadHeaderChunk : ReadHeaderChunk
--  generic map(START_ADDR=>0)
--  Port map( 
--        rst_n => rst_n,
--        clk => clk,
--		readRqt => startHeaderRead,			
--        finishRead => readFinish,  
--        headerOk => headerOKe,
--        division => divisionVal,
--        track0AddrStart =>track0AddrStartVal,
--        track1AddrStart => track1AddrStartVal,
        
--        --Debug
--        regAuxOut =>regAux,
--        cntrOut =>cntrOut,
--        statesOut =>statesOut,
        
--        -- Mem side
--        nextByte =>BP_data,
--        byteAck =>BP_ack,
--        byteAddr =>BP_addr,
--        byteRqt =>BP_byteRqt
--  );


my_ReadHeaderChunk : ReadHeaderChunk_2
  generic map(START_ADDR=>0)
  Port map( 
        rst_n               => rst_n,
        clk                 => clk,
        cen                 => cen,                     
        readRqt             => startHeaderRead,            
        finishRead          => readFinish,  
        headerOk            => headerOKe,
        numTracksToRead     => numTracksToRead,
  
        -- OneDividedByDivision_Provider side
        ODBD_ReadRqt => ODBD_ReadRqt,
        division     => divisionVal,
        
        -- Start addreses for the Read Trunk Chunk components
        tracksAddrStart => tracksAddrStart,
        
        --Byte provider side
        nextByte => BP_data,
        byteAck  => BP_ack,
        byteAddr => BP_addr,
        byteRqt  => BP_byteRqt
  );

  
  
  
my_Mili: MilisecondDivisor
    generic map(FREQ=>75000)
    port map( 
        rst_n => rst_n,
        clk => clk,
      cen =>'1',
      Tc => miliTc
    );
  
    

end Behavioral;
