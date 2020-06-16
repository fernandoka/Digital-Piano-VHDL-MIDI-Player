----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06.01.2020 21:13:45
-- Design Name: 
-- Module Name: ReadVarLengthTest - Behavioral
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

entity ReadVarLengthTest is
--  Port ( );
end ReadVarLengthTest;

architecture Behavioral of ReadVarLengthTest is

component ReadVarLength is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        readRqt			:	in	std_logic; -- One cycle high to request a read
        iniAddr			:	in	std_logic_vector(26 downto 0);
        valOut			:	out	std_logic_vector(63 downto 0);
        dataRdy			:	out std_logic;  -- One cycle high when the data is ready

		--Byte provider side
		nextByte        :   in  std_logic_vector(7 downto 0);
		byteAck			:	in	std_logic; -- One cycle high to notify the reception of a new byte
        byteAddr		:	out std_logic_vector(26 downto 0);
		byteRqt			:	out std_logic -- One cycle high to request a new byte
  ); 
end component;


    constant clkPeriod : time := 13.333333333333333333333333333333333333333333333333333333333 ns;   -- Periodo del reloj (75 MHz)


    -- Señales 
    signal clk     : std_logic := '1';      
    signal rst_n   : std_logic := '0';
    signal dataByte :   std_logic_vector(7 downto 0);
    signal valOut   :   std_logic_vector(63 downto 0);
    
    signal byteRqt, dataRdy  :std_logic;
    signal readRqt :   std_logic := '0';
    signal byteAck :   std_logic :='0';
    signal iniAddr, byteAddr :   std_logic_vector(26 downto 0);   

begin
  
clkGen:
  clk <= not clk after clkPeriod/2;
    
rstGen :
    rst_n <= 
    '1' after (50 us + 5 ns), 
    '0' after (50000 ms);

-- Examples:
--00000000 		00
--00000040 		40
--0000007F 		7F
--00000080 		81 00
--00002000 		C0 00
--00003FFF 		FF 7F
--00004000 		81 80 00
--00100000 		C0 80 00
--001FFFFF 		FF FF 7F
--00200000 		81 80 80 00
--08000000 		C0 80 80 00
--0FFFFFFF 		FF FF FF 7F


dataReadRqtGen: 
process
begin
    -- wait for rst_n
    wait for ( 50 us + 5 ns + clkPeriod*5);

--0000007F 		7F
        dataByte <= X"7F";    
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <= '0';
        byteAck <= '1';
         
    wait until dataRdy ='0';
        assert(valOut = X"000000000000007F")
        report "first example fail" severity error;
        byteAck <= '0';
    wait for (clkPeriod*2);




--00000080 		81 00
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"81";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"00";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until dataRdy ='0';
        assert(valOut = X"0000000000000080")
        report "second example fail" severity error;
    
    wait for (clkPeriod*2);

--00002000 		C0 00
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"C0";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"00";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until dataRdy ='0';
        assert(valOut = X"0000000000002000")
        report "third example fail" severity error;

    wait for (clkPeriod*2);


--00003FFF 		FF 7F
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"FF";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"7F";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until dataRdy ='0';
        assert(valOut = X"0000000000003FFF")
        report "fourth example fail" severity error;

    wait for (clkPeriod*2);
		
--00004000 		81 80 00
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"81";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"80";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until byteRqt ='0';
        dataByte <= X"00";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until dataRdy ='0';
        assert(valOut = X"0000000000004000")
        report "fifth example fail" severity error;
		
    wait for (clkPeriod*2);
		
--0010 0000 		C0 80 00
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"C0";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"80";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until byteRqt ='0';
        dataByte <= X"00";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until dataRdy ='0';
        assert(valOut = X"0000000000100000")
        report "sixth example fail" severity error;

    wait for (clkPeriod*2);

--001FFFFF 		FF FF 7F
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"FF";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"FF";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until byteRqt ='0';
        dataByte <= X"7F";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until dataRdy ='0';
        assert(valOut = X"00000000001FFFFF")
        report "seventh example fail" severity error;

    wait for (clkPeriod*2);
		
--00200000 		81 80 80 00
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"81";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"80";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until byteRqt ='0';
        dataByte <= X"80";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"00";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until dataRdy ='0';
        assert(valOut = X"0000000000200000")
        report "eigth example fail" severity error;

    wait for (clkPeriod*2);

--08000000 		C0 80 80 00
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"C0";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"80";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until byteRqt ='0';
        dataByte <= X"80";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"00";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until dataRdy ='0';
        assert(valOut = X"0000000008000000")
        report "nineth example fail" severity error;

    wait for (clkPeriod*2);

--0FFF FFFF 		FF FF FF 7F
        readRqt <='1';
    wait for (clkPeriod);
        readRqt <='0';
    
    wait until byteRqt ='0';
        dataByte <= X"FF";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"FF";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';
    
    wait until byteRqt ='0';
        dataByte <= X"FF";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until byteRqt ='0';
        dataByte <= X"7F";    
        byteAck <= '1';
    wait for (clkPeriod);
        byteAck <= '0';

    wait until dataRdy ='0';
        assert(valOut = X"000000000FFFFFFF")
        report "tenth example fail" severity error;
		
		
    wait;

end process;

iniAddr <= (others=>'0');
lala : ReadVarLength
  Port map( 
        rst_n => rst_n,
        clk => clk,
        readRqt => readRqt,
        iniAddr => iniAddr, 
        valOut => valOut,
        dataRdy => dataRdy,
		
		nextByte => dataByte,
        byteAck => byteAck,
        byteAddr => byteAddr,
		byteRqt	=> byteRqt
  );

end Behavioral;
