----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: CmdKeyboardSequencer - Behavioral
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
--		Command format: cmd(7 downto 0) = note code
--					 	cmd(9) = when high, note on	
--						cmd(8) = when high, note off
--						Null command when -> cmd(9 downto 0) = (others=>'0')
--
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

entity CmdKeyboardSequencer is
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
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  CmdKeyboardSequencer  :   entity  is  "true";
    
end CmdKeyboardSequencer;

--use work.my_common.all;

architecture Behavioral of CmdKeyboardSequencer is
  component my_fifo is
  generic (
    WIDTH : natural;   -- anchura de la palabra de fifo
    DEPTH : natural    -- numero de palabras en fifo
  );
  port (
    rst_n   : in  std_logic;   -- reset as?ncrono del sistema (a baja)
    clk     : in  std_logic;   -- reloj del sistema
    wrE     : in  std_logic;   -- se activa durante 1 ciclo para escribir un dato en la fifo
    dataIn  : in  std_logic_vector(WIDTH-1 downto 0);   -- dato a escribir
    rdE     : in  std_logic;   -- se activa durante 1 ciclo para leer un dato de la fifo
    dataOut : out std_logic_vector(WIDTH-1 downto 0);   -- dato a leer
    full    : out std_logic;   -- indicador de fifo llena
    empty   : out std_logic    -- indicador de fifo vacia
  );
end component;
----------------------------------------------------------------------------------
-- SIGNALS FOR FIFO
---------------------------------------------------------------------------------- 
signal wrFifo, rdFifo		:	std_logic;  
signal fullFifo, emptyFifo	:	std_logic;
signal dataInFifo 			:	std_logic_vector(9 downto 0);


begin


----------------------------------------------------------------------------------
-- FIFO COMPONENT
---------------------------------------------------------------------------------- 

FifoInterface: my_fifo
  generic map(WIDTH =>10, DEPTH =>4)
  port map(
    rst_n   => rst_n,
    clk     => clk,
    wrE     => wrFifo,
    dataIn  => dataInFifo,
    rdE     => keyboard_ack,
    dataOut => cmdKeyboard,
    full    => fullFifo,
    empty   => emtyCmdBuffer
  );


  
process(rst_n,clk,cen,sendCmdRqt,fullFifo)
	type states is (s0, s1);	
	variable state	:	states;
begin

    ------------------
	-- MEALY OUTPUT --
	------------------
	wrFifo <='0';
	if cen='1' and fullFifo='0' then
		if (state=s0 and sendCmdRqt(0)='1') or 
			(state=s1 and sendCmdRqt(1)='1') then
			wrFifo <='1';
		end if;
	end if;

    ------------------
	-- MOORE OUTPUT --
	------------------	
	dataInFifo <=(others=>'0');
	if state=s0 then
		dataInFifo <= cmdTrack_0;
	elsif state=s1 then
		dataInFifo <= cmdTrack_1;
	end if;
	
	-- Debug
	statesOut <=(others=>'0');
	if state=s0 then
		statesOut(0) <='1';
	end if;

	if state=s1 then
		statesOut(1) <='1';
	end if;
	--
	
	
	
    if rst_n='0' then
		seq_ack <=(others=>'0');
		
    
	elsif rising_edge(clk) then
		seq_ack <=(others=>'0');
		
		case state is
			when s0=>
				if cen='1' and fullFifo='0' then
					state:=s1;
					if sendCmdRqt(0)='1' then	
						seq_ack(0) <= '1';
					end if;
				end if;
			
				
			when s1=>
				if cen='1' and fullFifo='0' then
					state:=s0;
					if sendCmdRqt(1)='1' then
						seq_ack(1) <= '1';
					end if;
				end if;

				
		end case;			
	
    end if;
end process;
  
end Behavioral;
