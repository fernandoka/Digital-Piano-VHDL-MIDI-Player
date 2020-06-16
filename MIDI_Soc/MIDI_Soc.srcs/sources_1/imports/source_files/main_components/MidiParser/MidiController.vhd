----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: MidiController - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.5
-- Additional Comments:
--		This component manage the activation of the differents components for
--		midi parser component
--	
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity MidiController is
  Generic(MAX_NUM_TRACKS : in  natural);
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		cen                     :   in 	std_logic;
		readMidifileRqt			:	in	std_logic; -- One cycle high to request a read
		finishHeaderRead		:	in	std_logic; -- One cycle high to notify the end of a read
		headerOK				:	in	std_logic; -- High when the header data it's okey
		finishTracksRead		:	in	std_logic_vector(MAX_NUM_TRACKS-1 downto 0); -- One cycle high to notify the end of a read
		tracksOK				:	in	std_logic_vector(MAX_NUM_TRACKS-1 downto 0); -- High when the track data it's okey
		ODBD_ValReady			:	in	std_logic; -- High when the value of the last read it's ready
        numTracksToRead         :   in  std_logic_vector(15 downto 0);
        
		readHeaderRqt			:	out	std_logic;
		muxBP_0					:	out	std_logic; -- Decides if BP_0 serves bytes to Read Header(low) or Read Track 0(high)
		goFirstRead             :   out std_logic; -- "Reset fo the BP components"
		readTracksRqt			:	out	std_logic_vector(2*MAX_NUM_TRACKS-1 downto 0); -- Per track->10 play mode 01 check mode
		parseOnOff				:	out	std_logic; -- 1 Controller is On everything goes right, otherwise something went wrong
		fileOk                  :   out std_logic;
		
		--Debug
		statesOut       		:	out std_logic_vector(4 downto 0)
		
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  MidiController  :   entity  is  "true";
end MidiController;

architecture Behavioral of MidiController is
	
	signal readTracksRom       :   std_logic_vector(2*MAX_NUM_TRACKS-1 downto 0);
	
begin

romVals:
process(numTracksToRead)
	type   rom_t   is array( 0 to MAX_NUM_TRACKS) of std_logic_vector(MAX_NUM_TRACKS*2-1 downto 0);

    variable romValues  :   rom_t;
begin
    
    readTracksRom <=romValues(to_integer(unsigned(numTracksToRead)));  
    
    romValues :=(others=>(others=>'0'));
    for i in 1 to MAX_NUM_TRACKS loop
        for j in 1 to i loop
            romValues(i)(2*(j-1)) :='1';
        end loop;
    end loop;

end process;


fsm:
process(rst_n, clk, cen, readMidifileRqt, finishHeaderRead, tracksOK, headerOK, ODBD_ValReady, numTracksToRead)
    type states is (s0, s1, s2, s3, s4);	
	type tmpForLoop_t  is  array(0 to MAX_NUM_TRACKS-1)    of  std_logic_vector(MAX_NUM_TRACKS downto 0);	
        
	variable state	:	states;
	
	variable	finishFlag	              :   std_logic_vector(MAX_NUM_TRACKS-1 downto 0);
	variable	tmpFinish, tmpTracksOk    :   std_logic_vector(MAX_NUM_TRACKS-1 downto 0);
	variable	checkFinishTracksOk       :   std_logic_vector(MAX_NUM_TRACKS-1 downto 0);
            
     
begin
    --Debug
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
    --

	parseOnOff <='0';
	if state/=s0 then
		parseOnOff <='1';
	end if;

	-------------------------------------------------------------------------------------------
	-- Generation of reduced AND signals, to check If a set of track have finished correctly --
	-------------------------------------------------------------------------------------------
    tmpFinish(0) := finishFlag(0);
    for i in 1 to MAX_NUM_TRACKS-1 loop
        tmpFinish(i) :=finishFlag(i) and tmpFinish(i-1);
    end loop;

    tmpTracksOk(0) := tracksOK(0);
    for i in 1 to MAX_NUM_TRACKS-1 loop
        tmpTracksOk(i) :=tracksOK(i) and tmpTracksOk(i-1);
    end loop;
    
    for i in 0 to MAX_NUM_TRACKS-1 loop
        checkFinishTracksOk(i) :=tmpFinish(i) and tmpTracksOk(i);
    end loop;
    
    	
	if rst_n='0' then
		state := s0;
		readHeaderRqt <='0';
		finishFlag :=(others=>'0');	
		readTracksRqt <=(others=>'0');	
		muxBP_0 <='0';		
        goFirstRead <='0';
        fileOk <= '0';
        
	elsif rising_edge(clk) then
		readHeaderRqt <='0';	
		readTracksRqt <=(others=>'0');	
		goFirstRead <='0';
		
		if cen='1' then
            if state/=s0 then
                goFirstRead <='1'; -- Reset of BP components
				state := s0;
			end if;
		else

			case state is
				when s0 =>
					if readMidifileRqt='1' then
						muxBP_0 <='0'; -- BP_0 serve bytes to Read Header
						readHeaderRqt <='1';
						fileOk <='0';
						state := s1;
					end if;
				
				when s1 =>
					if finishHeaderRead='1' then
						if headerOK='1' and unsigned(numTracksToRead) <= MAX_NUM_TRACKS then
							state := s2;
						else
                            goFirstRead <='1'; -- Reset of BP components
							state := s0;
						end if;
					end if;

				when s2 =>
					if ODBD_ValReady='1' then
						muxBP_0 <='1'; -- BP_0 serve bytes to Read Track 0
						-- Send read rqt in check mode for the read track components
                        readTracksRqt <= readTracksRom;
						state := s3;
					end if;
				
				-- Wait until the read track components finish the check read
				when s3 =>
                    
                    for i in 0 to MAX_NUM_TRACKS-1 loop
                        if finishTracksRead(i)='1' then
                            finishFlag(i) :='1';
                        end if;
                    end loop;
                    
                    if tmpFinish(to_integer(unsigned(numTracksToRead)-1))='1' then
                        finishFlag := (others=>'0');
                        if checkFinishTracksOk(to_integer(unsigned(numTracksToRead)-1))='1' then
                            -- Send read rqt in play mode for the read track components
                            -- Shift one positon to the left Rom value, to send read in play mode to tracks components
                            readTracksRqt <= readTracksRom(2*MAX_NUM_TRACKS-2 downto 0) & '0';  
                            fileOk <= '1';
                            state := s4;
                        else
                            goFirstRead <='1'; -- Reset of BP components
                            state := s0;
                        end if;-- tracksOK(0)='1' or tracksOK(1)='1'
                     end if;-- if tmpFinish(numTracksToRead-1)='1' then
                                         
				when s4 =>
					
                    for i in 0 to MAX_NUM_TRACKS-1 loop
                        if finishTracksRead(i)='1' then
                            finishFlag(i) :='1';
                        end if;
                    end loop;
					
					
                    if tmpFinish(to_integer(unsigned(numTracksToRead)-1))='1' then
                        goFirstRead <='1'; -- Reset of BP components
                        finishFlag := (others=>'0');
                        state := s0;
                    end if;			
			  end case;
			  
		end if;-- cen='0'	
    end if; -- rising_edge(clk)
end process;
  
end Behavioral;
