----------------------------------------------------------------------------------
-- Company: fdi Universidad Complutense de Madrid, Spain
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 06.12.2019 19:33:54
-- Design Name: 
-- Module Name: MainController - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.9
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity MainController is
  Port (
    clk   				   :   in  	    std_logic;
    rst_n 				   :   in 		std_logic;
    
    -- For RGBLed
    currentState    	   :   out 	    std_logic_vector(4 downto 0); 
    
    -- Buttons
    sysStart    	       :   in 		std_logic;
    playSong               :   in       std_logic;
    loadMidiFile           :   in       std_logic;
    reverbOnOff            :   in       std_logic;
    externInterface        :   in       std_logic;
    
    -- For MidiParser 
    OnOffSong              :   in       std_logic;
    readMidifileRqt        :   out      std_logic;
    
    -- For KeyboardCntrl
    reverbStatus           :   out      std_logic;
    
    -- For Setup Component
    finSetup    		   :   in  	    std_logic;
    iniSetup    		   :   out 	    std_logic;
    
    -- ExternInterfaceCmdReceiver
    finishFileReception    :   in       std_logic;
    externInterfaceStatus  :   out      std_logic;
    
    -- Enable and Control 
    cenComponents          :   out      std_logic_vector(1 downto 0); -- For MidiParser and KeyboardCntrl
    muxControlSignals      :   out      std_logic; -- For 7Segs diplay
    memRdWr				   :   out		std_logic -- For RamCntrl
            
);
-- Attributes for debug
--  attribute   dont_touch    :   string;
--  attribute   dont_touch  of  MainController  :   entity  is  "true"; 
end MainController;

architecture Behavioral of MainController is

begin

----------------------------------------------------------------------------------
-- FSMT
----------------------------------------------------------------------------------
FSMT:
process(rst_n, clk, sysStart, playSong, loadMidiFile, OnOffSong, loadMidiFile, finishFileReception, externInterface)

    type state_type is (Idle, WaitEndSetup, FinishedSetup, ReadMidiFile,waitLoadMidiFile);
    variable state                  : state_type;
    
    variable waitOneCycleFlag       : boolean; -- To wait one cycle
    variable externInterfaceFlag    : std_logic;
    variable reverbStatusFlag       : std_logic;
    variable muxControlFlags        : std_logic;
    
begin
    
    externInterfaceStatus <= externInterfaceFlag;
    muxControlSignals <= muxControlFlags;
    reverbStatus <= reverbStatusFlag;
    
    -------------------
    -- MOORE OUTPUTS --
    -------------------
    
    -- CurrentState
    currentState<=(others=>'0');
    if state=Idle then
        currentState(0) <='1';
    end if;
    
    if state=WaitEndSetup then
        currentState(1) <='1';
    end if;
    
    if state=FinishedSetup then
        currentState(2) <='1';
    end if;
    
    if state=ReadMidiFile then
        currentState(3) <='1';
    end if;

    if state=waitLoadMidiFile then
        currentState(4) <='1';
    end if;

    iniSetup <='0';
    if state/=Idle then
       iniSetup <='1';
    end if;
    
    memRdWr <='0'; -- RamCntrl in write mode
    if state=FinishedSetup or state=ReadMidiFile then
        memRdWr <='1'; -- RamCntrl in read mode
    end if;
    
    cenComponents(0) <='1'; -- MidiParser is not enable
    if state=ReadMidiFile then
        cenComponents(0) <='0'; -- MidiParser is enable
    end if;
    
    cenComponents(1) <='1'; -- KeyboardCntrl is not enable
    if externInterfaceFlag='1' or state=ReadMidiFile then
        cenComponents(1) <='0'; -- KeyboardCntrl is enable
    end if;    
    

    if rst_n = '0' then
        state := Idle;
        waitOneCycleFlag := true;
        reverbStatusFlag := '0';
        externInterfaceFlag := '0';
        muxControlFlags :='0';
        readMidifileRqt <='0';
        
    elsif rising_edge(clk) then
        readMidifileRqt <='0';
    
        -- Enable Extern interface interaction
        if externInterface='1' and state/=waitLoadMidiFile and state/=Idle and state/=WaitEndSetup then
            externInterfaceFlag := not externInterfaceFlag;
        end if;
        
        if reverbOnOff='1' then
            reverbStatusFlag := not reverbStatusFlag;
        end if;
        
        
        case state is
            when Idle =>
                if sysStart ='1' then
                    state := WaitEndSetup;
                end if;
            
            when WaitEndSetup =>
                if finSetup ='1' then
                    state :=FinishedSetup;
                end if;
        
            when FinishedSetup =>
                if muxControlFlags ='0' and externInterfaceFlag='1' then
                    muxControlFlags :='1';
                end if;
                
                if playSong='1' then
                    readMidifileRqt <='1';
                    waitOneCycleFlag := false; -- Wait one cycle before check OnOffSong signal
                    state := ReadMidiFile;
                elsif loadMidiFile='1' then
                    state := waitLoadMidiFile;
                end if;
            
            when ReadMidiFile =>
                if muxControlFlags ='0' then
                    muxControlFlags :='1';
                end if;
                
                if waitOneCycleFlag then 
                    -- Press again the button to stop playing the midi file
                    if playSong='1' or OnOffSong='0' then
                        state :=FinishedSetup;
                    
                    -- Could change directly to waitLoadMidiFile
                    elsif loadMidiFile='1' then
                        state := waitLoadMidiFile;
                    end if;
                else
                    waitOneCycleFlag := not waitOneCycleFlag;
                end if;
                
            when waitLoadMidiFile =>
                if muxControlFlags ='1' then
                    muxControlFlags :='0';
                end if;
                
                if finishFileReception='1' then
                    state :=FinishedSetup;
                end if;
                
            end case;
        
    end if; --rst_n/rising_edge(clk)
end process FSMT;

end Behavioral;
