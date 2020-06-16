----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ReadHeaderChunk - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.6
-- Additional Comments:
--      Send rqt to ODBD provider. MidiController will wait until the response of
--      ODBD provider
--
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

entity ReadHeaderChunk is
  Generic(START_ADDR    :   in  natural);
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		cen                     :   in 	std_logic;
		readRqt					:	in	std_logic; -- One cycle high to request a read
		finishRead				:	out std_logic; -- One cycle high when the component end to read the header
		headerOk				:	out std_logic; -- High, if the header follow our requirements
		
		-- OneDividedByDivision_Provider side
        ODBD_ReadRqt			:	out	std_logic;
		division				:	out	std_logic_vector(15 downto 0);
		
		-- Start addreses for the Read Trunk Chunk components
		track0AddrStart			:	out std_logic_vector(26 downto 0);
		track1AddrStart			:	out std_logic_vector(26 downto 0);
		
		--Debug
		regAuxOut       		: 	out std_logic_vector(31 downto 0);
		cntrOut         		: 	out std_logic_vector(2 downto 0);
		statesOut       		: 	out std_logic_vector(7 downto 0);
		 
		--Byte provider side
		nextByte        		:   in  std_logic_vector(7 downto 0);
		byteAck					:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        		:   out std_logic_vector(26 downto 0);
		byteRqt					:	out std_logic -- One cycle high to request a new byte

  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  ReadHeaderChunk  :   entity  is  "true";
end ReadHeaderChunk;

architecture Behavioral of ReadHeaderChunk is

	constant HEADER_CHUNK_MARK : std_logic_vector(31 downto 0) := X"4d546864";
	constant HEADER_LENGTH	: std_logic_vector(31 downto 0) := X"00000006";
	constant HEADER_FORMAT	: std_logic_vector(15 downto 0) := X"0001";
	constant HEADER_NTRKS	: std_logic_vector(15 downto 0) := X"0002";
	
begin

fsm:
process(rst_n,clk,readRqt,byteAck)
    type states is (s0, s1, s2, s3, s4, s5, s6, s7);	
	variable state	:	states;
	
	variable regAddr   :   unsigned(26 downto 0);
	variable regAux	:	std_logic_vector(31 downto 0);
	variable regDivision : std_logic_vector(15 downto 0);
	variable cntr	:	unsigned(2 downto 0);
	
	variable regTrack0AddrStart : std_logic_vector(26 downto 0);
	variable regTrack1AddrStart : std_logic_vector(31 downto 0);
	
begin
	
	division <=regDivision;
	byteAddr <= std_logic_vector(regAddr);
	track0AddrStart <= regTrack0AddrStart;
	track1AddrStart <= regTrack1AddrStart(26 downto 0);

    --Debug
    regAuxOut <=regAux;
    cntrOut <=std_logic_vector(cntr);
    
    statesOut <=(others=>'0');
    if state=s0 then
        statesOut(0)<='1'; 
    end if;
    
    if state=s1 then
        statesOut(1)<='1'; 
    end if;

    if state=s2 then
        statesOut(2)<='1'; 
    end if;

    if state=s3 then
        statesOut(3)<='1'; 
    end if;

    if state=s4 then
        statesOut(4)<='1'; 
    end if;

    if state=s5 then
        statesOut(5)<='1'; 
    end if;

    if state=s6 then
        statesOut(6)<='1'; 
    end if;

    if state=s7 then
        statesOut(7)<='1'; 
    end if;

    --
    	
	if rst_n='0' then
		state := s0;
		regDivision := (others=>'0');
		regAux := (others=>'0');
		cntr := (others=>'0');
		regTrack1AddrStart := (others=>'0');
		regTrack0AddrStart := (others=>'0');
		regAddr := to_unsigned(START_ADDR,27);
		headerOk <='0';
		finishRead <='0';
		byteRqt <='0';
        ODBD_ReadRqt <='0';

    elsif rising_edge(clk) then
		finishRead <='0';
		byteRqt <='0';
        ODBD_ReadRqt <='0';

		
		if cen='1' then
            if state/=s0 then
				state := s0;
			end if;
		else
		
			case state is
				when s0=>
					if readRqt='1' then
						headerOk<='0'; -- By default the header dosen't follow our requirements
						regAddr := to_unsigned(START_ADDR,27);
						byteRqt <='1';
						state := s1;
					end if;
				
				when s1 =>
					if cntr < 4 then 
						if byteAck='1' then
							
							if cntr < 3 then
							  byteRqt <='1';
							end if;
							
							regAux := regAux(23 downto 0) & nextByte;
							regAddr := regAddr+1;
							cntr := cntr+1;
						end if;
					else
						cntr :=(others=>'0');
						if regAux=HEADER_CHUNK_MARK then
							byteRqt <='1';
							state := s2;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if;
					
				when s2 =>
					if cntr < 4 then 
						if byteAck='1' then
							
							if cntr < 3 then
							  byteRqt <='1';
							end if;
						
							regAux := regAux(23 downto 0) & nextByte;
							regAddr := regAddr+1;
							cntr := cntr+1;
						end if;
					else
						cntr :=(others=>'0');
						if regAux=HEADER_LENGTH then
							byteRqt <='1';
							state := s3;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if;
				

				when s3 =>
					if cntr < 2 then
						if byteAck='1' then
						
							if cntr < 1 then
							  byteRqt <='1';
							end if;
										
							regAux := regAux(23 downto 0) & nextByte;
							regAddr := regAddr+1;
							cntr := cntr+1;
						end if;
					else
						cntr :=(others=>'0');
						if regAux(15 downto 0)=HEADER_FORMAT then
							byteRqt <='1';					
							state := s4;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if;
				
				when s4 =>
					if cntr < 2 then                             
						if byteAck='1' then
							if cntr < 1 then
							  byteRqt <='1';
							end if;

							regAux := regAux(23 downto 0) & nextByte;
							regAddr := regAddr+1;
							cntr := cntr+1;
						end if;
					else
						cntr :=(others=>'0');
						if regAux(15 downto 0)=HEADER_NTRKS then
							byteRqt <='1';
							state := s5;
						else
							finishRead <='1';
							state := s0;
						end if;
					end if;
				
				when s5 =>
					if cntr < 2 then 
						if byteAck='1' then
					
							if cntr < 1 then
								byteRqt <='1';
							end if;

							regDivision := regDivision(7 downto 0) & nextByte;
							regAddr := regAddr+1;
							cntr := cntr+1;
						end if;
					else
						cntr :=(others=>'0');
						if unsigned(regDivision)=0 then
							finishRead <='1';
							state := s0;
						else
							regTrack0AddrStart := std_logic_vector(regAddr);
							-- ODBD rqt
                            ODBD_ReadRqt <='1';
							-- Don't read the track chunk mark, 4 bytes
							regAddr := regAddr+4;
							byteRqt <='1';
							state := s6;
						end if;
						
					end if;
			  
			  when s6 =>
				if cntr < 4 then 
					if byteAck='1' then
						
						if cntr < 3 then
						  byteRqt <='1';
						end if;
						
						regAux := regAux(23 downto 0) & nextByte;
						regAddr := regAddr+1;
						cntr := cntr+1;
					end if;
				else
					cntr :=(others=>'0');
					regTrack1AddrStart := std_logic_vector(unsigned(regTrack0AddrStart) + unsigned(regAux) + 8);
					state := s7;
				end if;
				
			  when s7 =>
				-- Check if the sum dosen't make overflow.
				if regTrack1AddrStart(27)='0' then                    
				 headerOk <='1';
				end if;
				finishRead <='1';
				state := s0;
			  
			end case;
			  
		end if;-- cen='0'	
    end if;-- rising_edge(clk)
end process;
  
end Behavioral;
