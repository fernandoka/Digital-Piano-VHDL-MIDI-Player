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
-- Revision 1.0
-- Additional Comments:
--      Send rqt to ODBD provider. MidiController will wait until the response of
--      ODBD provider
--
--      Only support one division format, bit 15 of regDivison must be 0
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ReadHeaderChunk is
  Generic( START_ADDR     : in  natural;
           MAX_NUM_TRACKS : in  natural
  );
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
		division				:	out	std_logic_vector(14 downto 0);
		
		-- Start addreses for the Read Trunk Chunk components
		tracksAddrStart			:	out std_logic_vector(MAX_NUM_TRACKS*27-1 downto 0);
		
		 
		--Byte provider side
		nextByte        		:   in  std_logic_vector(7 downto 0);
		byteAck					:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        		:   out std_logic_vector(26 downto 0);
		byteRqt					:	out std_logic -- One cycle high to request a new byte

  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  ReadHeaderChunk  :   entity  is  "true";
end ReadHeaderChunk;

architecture Behavioral of ReadHeaderChunk is

	constant HEADER_CHUNK_MARK  : std_logic_vector(31 downto 0) := X"4d546864";
	constant HEADER_LENGTH	    : std_logic_vector(31 downto 0) := X"00000006";
	
	constant HEADER_FORMAT_1	: std_logic_vector(15 downto 0) := X"0001";
	constant HEADER_MAX_NTRKS_1	: std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(MAX_NUM_TRACKS,16));

	constant HEADER_FORMAT_0	: std_logic_vector(15 downto 0) := X"0000";
	constant HEADER_NTRKS_0	    : std_logic_vector(15 downto 0) := X"0001";

	
begin

fsm:
process(rst_n,clk,readRqt,byteAck)
    type regStartAddr_t   is  array (0 to MAX_NUM_TRACKS-1) of std_logic_vector(31 downto 0);
    type states is (s0, s1, s2, s3, s4, s5, s6, s7);	
	variable state	:	states;
	
	variable regAddr       :   unsigned(26 downto 0);
	variable regAux        :   std_logic_vector(31 downto 0);
	variable regDivision   :   std_logic_vector(15 downto 0);
	variable cntr          :   unsigned(2 downto 0);
	
	variable regNumTracksToRead        :   unsigned(15 downto 0); 
	variable formatFlag                :   boolean; -- false-> format 0, true-> format 1
	variable regsTrackAddrStart        :   regStartAddr_t;
	variable indexRegsTrackAddrStart   :   natural range 0 to MAX_NUM_TRACKS;
	
begin
	
	division <=regDivision(14 downto 0);
	byteAddr <= std_logic_vector(regAddr);
	
	for i in 0 to MAX_NUM_TRACKS-1 loop
	   tracksAddrStart((i+1)*27-1 downto i*27) <= regsTrackAddrStart(i)(26 downto 0); 
	end loop;
	
    numTracksToRead <= std_logic_vector(regNumTracksToRead);
	
	if rst_n='0' then
		state := s0;
		regDivision := (others=>'0');
		regAux := (others=>'0');
		cntr := (others=>'0');
        regsTrackAddrStart :=(others=>(others=>'0'));
		regAddr := to_unsigned(START_ADDR,27);
		formatFlag := false;
		regNumTracksToRead := (others=>'0');
		indexRegsTrackAddrStart := 0;
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
                        indexRegsTrackAddrStart := 0;
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
						if regAux = HEADER_CHUNK_MARK then
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
						if regAux(15 downto 0)=HEADER_FORMAT_1 then
						  formatFlag := true;
						elsif regAux(15 downto 0)=HEADER_FORMAT_0 then
						  formatFlag := false;
						end if;
						if regAux(15 downto 0)=HEADER_FORMAT_0 or regAux(15 downto 0)=HEADER_FORMAT_1 then
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
						if (formatFlag and regAux(15 downto 0) <= HEADER_MAX_NTRKS_1) or (not formatFlag and regAux(15 downto 0) = HEADER_NTRKS_0) then
							regNumTracksToRead := unsigned(regAux(15 downto 0)); 
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
						-- Only support one division format, bit 15 must be 0
						-- Division value cannot be 0
						if unsigned(regDivision)=0 or regDivision(15)='1' then
							finishRead <='1';
							state := s0;
						else
						    regsTrackAddrStart(indexRegsTrackAddrStart)(31 downto 27) := (others=>'0');
							regsTrackAddrStart(indexRegsTrackAddrStart)(26 downto 0) := std_logic_vector(regAddr);
							indexRegsTrackAddrStart := indexRegsTrackAddrStart+1;
							-- ODBD rqt
                            ODBD_ReadRqt <='1';
                            state := s7;
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
					-- +8 bytes due to the track chunk mark bytes and length bytes of track
					regsTrackAddrStart(indexRegsTrackAddrStart) := std_logic_vector(unsigned(regsTrackAddrStart(indexRegsTrackAddrStart-1)) + unsigned(regAux) + 8);
                    indexRegsTrackAddrStart :=indexRegsTrackAddrStart+1;
					state := s7;
				end if;
				
			  when s7 =>
			  
				-- Check if the sum dosen't make overflow.
				if regsTrackAddrStart(indexRegsTrackAddrStart-1)(27)='1' then                    
				    finishRead <='1';
				    state := s0;
                elsif regNumTracksToRead = indexRegsTrackAddrStart then
    				headerOk <='1';
    				finishRead <='1';
				    state := s0;
			    else
                    -- Don't read the track chunk mark, 4 bytes
                    regAddr := unsigned(regsTrackAddrStart(indexRegsTrackAddrStart-1)(26 downto 0)) + 4;
                    byteRqt <='1';
                    state := s6;
			    end if;
			  
			end case;
			  
		end if;-- cen='0'	
    end if;-- rising_edge(clk)
end process;
  
end Behavioral;
