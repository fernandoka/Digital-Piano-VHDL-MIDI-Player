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
-- Revision 0.3
-- Additional Comments:
--		This component manage the activation of the differents components for
--		midi parser component
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

entity MidiController is
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		cen                     :   in 	std_logic;
		readMidifileRqt			:	in	std_logic; -- One cycle high to request a read
		finishHeaderRead		:	in	std_logic; -- One cycle high to notify the end of a read
		headerOK				:	in	std_logic; -- High when the header data it's okey
		finishTracksRead		:	in	std_logic_vector(1 downto 0); -- One cycle high to notify the end of a read
		tracksOK				:	in	std_logic_vector(1 downto 0); -- High when the track data it's okey
		ODBD_ValReady			:	in	std_logic; -- High when the value of the last read it's ready
		
		readHeaderRqt			:	out	std_logic;
		muxBP_0					:	out	std_logic; -- Decides if BP_0 serves bytes to Read Header(low) or Read Track 0(high)
		readTracksRqt			:	out	std_logic_vector(3 downto 0); -- Per track->10 play mode 01 check mode
		parseOnOff				:	out	std_logic; -- 1 Controller is On everything goes right, otherwise something went wrong
		
		--Debug
		statesOut       		:	out std_logic_vector(4 downto 0)
		
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  MidiController  :   entity  is  "true";
end MidiController;

architecture Behavioral of MidiController is
	
begin

fsm:
process(rst_n, clk, readMidifileRqt, finishHeaderRead, headerOK, ODBD_ValReady)
    type states is (s0, s1, s2, s3, s4);	
	variable state	:	states;
	
	variable	cntr		:	unsigned(1 downto 0);
	variable	finishFlag	:	std_logic_vector(1 downto 0);

begin


	parseOnOff <='0';
	if state/=s0 then
		parseOnOff <='1';
	end if;
	
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
    	
	if rst_n='0' then
		state := s0;
		cntr :=(others=>'0');
		readHeaderRqt <='0';
		finishFlag :=(others=>'0');	
		readTracksRqt <=(others=>'0');	
		muxBP_0 <='0';		
    
	elsif rising_edge(clk) then
		readHeaderRqt <='0';	
		readTracksRqt <=(others=>'0');	
		
		if cen='1' then
            if state/=s0 then
				state := s0;
			end if;
		else

			case state is
				when s0 =>
					if readMidifileRqt='1' then
						muxBP_0 <='0'; -- BP_0 serve bytes to Read Header
						readHeaderRqt <='1';
						finishFlag :=(others=>'0');	
						state := s1;
					end if;
				
				when s1 =>
					if finishHeaderRead='1' then
						if headerOK='1' then
							state := s2;
						else
							state := s0;
						end if;
					end if;

				when s2 =>
					if ODBD_ValReady='1' then
						muxBP_0 <='1'; -- BP_0 serve bytes to Read Track 0
						-- Send read rqt in check mode for the read track components
						readTracksRqt <= "0101";
						cntr := (others=>'0');
						state := s3;
					end if;
				
				-- Wait until the read track components finish the check read
				when s3 =>
					if finishTracksRead(0)='1' or  finishTracksRead(1)='1' then
						if tracksOK(0)='1' or tracksOK(1)='1' then
							if cntr=1 or 
							(finishTracksRead(0)='1' and tracksOK(0)='1' and 
							finishTracksRead(1)='1' and tracksOK(1)='1') 
							then
								-- Send read rqt in play mode for the read track components
								readTracksRqt <= "1010";
								state := s4;
							else
								cntr := cntr+1;
							end if;							
						else
							state := s0;
						end if;-- tracksOK(0)='1' or tracksOK(1)='1'
					end if;

				when s4 =>
					if finishTracksRead(0)='1' then
						finishFlag(0) :='1';
					end if;
					
					if finishTracksRead(1)='1' then
						finishFlag(1) :='1';
					end if;
					
					if finishFlag(0)='1' and  finishFlag(1)='1' then
						state := s0;
					end if;
				
			  end case;
			  
		end if;-- cen='0'	
    end if; -- rising_edge(clk)
end process;
  
end Behavioral;
