----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ReadTrackChunk - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 1.3
-- Additional Comments:
--    Notes: In play mode, infinite loop are not checked !!           
--
--    How to use: 
--          -> First, order a read in check mode to be sure if the file follow our requirements
--          -> Second, order a read in play mode to start sending the commands
--                  
--		if readRqt(0) read will be done in check mode, and no waiting time no commands to the keyboard will be send.
--		if readRqt(1) read will be done in play mode,  commands to the keyboard will be send and waiting time will be enable.
--
--		Command format: cmd(7 downto 0) = note code
--					 	cmd(9) = when high, note on	
--						cmd(8) = when high, note off
--						Null command when -> cmd(9 downto 0) = (others=>'0')
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

entity ReadTrackChunk is
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
        cen                     :   in 	std_logic;
		readRqt					:	in	std_logic_vector(1 downto 0); -- One cycle high to request a read 
		trackAddrStart			:	in 	std_logic_vector(26 downto 0); -- Must be stable for the whole read
		OneDividedByDivision	:	in 	std_logic_vector(23 downto 0); -- Q4.20
		finishRead				:	out std_logic; -- One cycle high to notify the end of track reached
		trackOK					:	out	std_logic; -- High track data is ok, low track data is not ok			
		
		-- CMD Keyboard interface
        sequencerAck            :   in std_logic;
		wrCmdRqt                :   out std_logic;
		cmd					    :	out std_logic_vector(9 downto 0);
				
		--Debug		
		regAuxOut       		: out std_logic_vector(31 downto 0);
		regAddrOut          	: out std_logic_vector(26 downto 0);
		statesOut       		: out std_logic_vector(8 downto 0);
		runningStatusOut        : out std_logic_vector(7 downto 0);  
		dataBytesOut            : out std_logic_vector(15 downto 0);
		regWaitOut              : out std_logic_vector(17 downto 0);
		 
		--Byte provider side
		nextByte        		:   in  std_logic_vector(7 downto 0);
		byteAck					:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        		:   out std_logic_vector(26 downto 0);
		byteRqt					:	out std_logic -- One cycle high to request a new byte

  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  ReadHeaderChunk  :   entity  is  "true";
end ReadTrackChunk;

use work.my_common.all;

architecture Behavioral of ReadTrackChunk is
----------------------------- Constants --------------------------------------------

	constant TRACK_CHUNK_MARK : std_logic_vector(31 downto 0) := X"4d54726b";
	
	--Meta events
	constant META_EVENT_MARK			: std_logic_vector(7 downto 0) := X"ff";
	constant META_EVENT_END_OF_TRACK	: std_logic_vector(7 downto 0) := X"2f";
	constant META_EVENT_SET_TEMPO		: std_logic_vector(7 downto 0) := X"51";
	constant SET_TEMPO_CMD_LENGTH       : std_logic_vector(7 downto 0) := X"03";
--	constant META_EVENT_KEY_SIGNATURE	: std_logic_vector(7 downto 0) := X"59";
	
	--Mtrk events
	constant MTRK_EVENT_NOTE_ON	: std_logic_vector(7 downto 0) := X"90";		
	constant MTRK_EVENT_NOTE_OFF	: std_logic_vector(7 downto 0) := X"80";
	constant MTRK_EVENT_PC	: std_logic_vector(7 downto 0) := X"c0";
	constant MTRK_EVENT_CKP	: std_logic_vector(7 downto 0) := X"d0";
	
	constant MTRK_EVENT_CC	: std_logic_vector(7 downto 0) := X"b0";		
	constant CC_SUSTAIN	: std_logic_vector(7 downto 0) := X"40";

	--Sysex event
	constant SYSEX_EVENT_0	: std_logic_vector(7 downto 0) := X"f0";		
	constant SYSEX_EVENT_1	: std_logic_vector(7 downto 0) := X"f7";
	
	--Op constants
	constant ONE_DIVIDED_BY_ONE_THOUSAND   :   unsigned(23 downto 0) := X"000419"; -- Q4.20
	constant ROUND_VAL_0                   :   unsigned(47 downto 0) :=X"000000080000"; -- Q28.20
    constant ROUND_VAL_1                   :   unsigned(55 downto 0) :=X"00000000080000"; -- Q36.20

----------------------------- Signals --------------------------------------------
	--fsm
	signal fsmByteRqt	:	std_logic;
	signal fsmAddr		:	std_logic_vector(26 downto 0);
	signal muxByteAddr	:	std_logic;
	
	--ReadVarLength
	signal resVarLength			:	std_logic_vector(63 downto 0);
	signal varLengthByteAddr	:	std_logic_vector(26 downto 0);
	signal varLengthByteRqt		:	std_logic;
	signal readVarLengthRqt		:	std_logic;
	signal varLengthRdy			:	std_logic;
	
	--msDivisor
	signal TCmili, cenDivisor	:	std_logic;
	
begin

byteAddr <= fsmAddr when muxByteAddr='0' else varLengthByteAddr;
byteRqt <= fsmByteRqt or varLengthByteRqt;


readVarLEnghtData: ReadVarLength
  port map( 
        rst_n   	=> rst_n,
        clk     	=> clk,
        readRqt		=> readVarLengthRqt,
		iniAddr		=> fsmAddr,
		valOut		=> resVarLength,
		dataRdy		=> varLengthRdy,
	
		--Byte provider side
		nextByte	=> nextByte,
		byteAck		=> byteAck,
		byteAddr	=> varLengthByteAddr,
		byteRqt		=> varLengthByteRqt
  );


msDivisor: MilisecondDivisor
  generic map(FREQ =>75)-- Frequency in Khz
  port map( 
        rst_n   => rst_n,
        clk     => clk,
		cen		=> cenDivisor,
		Tc		=> TCmili
		
  );


fsm:
process(rst_n,clk,readRqt,byteAck,varLengthRdy)
    type modes is (check, play);
	type states is (s0, s1, s2, s3, s4, s5, s6, skipVarLengthBytes, resolveMetaEvent, readEventData, waitSequencerAck, manageSetTempoCmd);	
	type fsm_states is record
		state   :   states;
        mode   	:   modes;
	end record;
	variable fsm_state	    :	fsm_states;
	
	variable regAddr        :	unsigned(26 downto 0);
	variable regWait	    :	unsigned(17 downto 0); -- aprox 4 mins of max waiting time
	
	variable mulAux0        : unsigned(47 downto 0);
	variable mulAux1        : unsigned(91 downto 0);
    variable mulAux2        : unsigned(55 downto 0);        

	variable addAux0        : unsigned(48 downto 0);
	variable addAux2        : unsigned(56 downto 0);
	variable resWait		: unsigned(17 downto 0);
	
	variable regAux0        : unsigned(27 downto 0);
	variable regAux1        : unsigned(31 downto 0);
	
	variable regTempo       : std_logic_vector(23 downto 0);
	variable readedBytes    : unsigned(26 downto 0);
	
	variable regAux         :   std_logic_vector(31 downto 0);
	variable runningStatus	:	std_logic_vector(7 downto 0);
	variable dataBytes		:	std_logic_vector(15 downto 0);
	variable cntr           :   unsigned(2 downto 0);
begin
	
	fsmAddr <= std_logic_vector(regAddr);
		
	-------------------
	-- Moore outputs --
	-------------------
	-- Enable readVarLegth component
	muxByteAddr <='0';
	if fsm_state.state=s3 or fsm_state.state=skipVarLengthBytes then
		muxByteAddr <='1';
	end if;
	
	-- Enable msDivisor
	cenDivisor <='0';
	if fsm_state.state=s4 then
		cenDivisor <='1';
	end if;
	
	---------------------------
    -- Combinational signals --
    ---------------------------
    
    -- Calculate ms to wait, aprox 
    -- deltaTime*(tempoVal/division)/1000
    -- PipeLined operations, 2 stages, to calculate wait time
    mulAux0 := unsigned(regTempo)*unsigned(OneDividedByDivision); -- Q28.20 = Q24.0*Q4.20
    addAux0 := ('0' & mulAux0)+('0' & ROUND_VAL_0); --Q29.20 = Q28.20+Q28.20
    
    mulAux1 := unsigned(resVarLength)*regAux0; -- Q92.0 = Q64.0*Q28.0

    mulAux2 := regAux1*ONE_DIVIDED_BY_ONE_THOUSAND; -- Q36.20=Q32.0*Q4.20
    addAux2 := ('0' & mulAux2)+('0' & ROUND_VAL_1); --Q37.20 = Q36.20+Q36.20
    
	-- Final Satur, 57 bits to 17 bits
			resWait := addAux2(37 downto 20);
	if addAux2(38)='1' then
	   resWait :=(others=>'1'); 
	end if;
	
    readedBytes := (regAddr - (unsigned(trackAddrStart) + 6)); -- 6 instead of 8, do not count the ini and end byte address

    --Debug
    regAddrOut <= std_logic_vector(regAddr);
    regAuxOut <= regAux;
    runningStatusOut<=runningStatus;
    dataBytesOut<= dataBytes;
    regWaitOut<= std_logic_vector(regWait);
    
    statesOut <=(others=>'0');
    if fsm_state.state=s0 then
        statesOut(0)<='1'; 
    end if;
    
    if fsm_state.state=s1 then
        statesOut(1)<='1'; 
    end if;

    if fsm_state.state=s2 then
        statesOut(2)<='1'; 
    end if;

    if fsm_state.state=s3 then
        statesOut(3)<='1'; 
    end if;

    if fsm_state.state=s4 then
        statesOut(4)<='1'; 
    end if;

    if fsm_state.state=s5 then
        statesOut(5)<='1'; 
    end if;

    if fsm_state.state=skipVarLengthBytes then
        statesOut(6)<='1'; 
    end if;

    if fsm_state.state=resolveMetaEvent then
        statesOut(7)<='1'; 
    end if;

    if fsm_state.state=readEventData then
        statesOut(8)<='1'; 
    end if;
    --
    	
	if rst_n='0' then
		regWait := (others=>'0');
		runningStatus := (others=>'0');
		regAux := (others=>'0');
		regAddr := (others=>'0');
		dataBytes := (others=>'0');
		cntr := (others=>'0');
		regTempo  := (others=>'0');
		fsm_state := (s0,check);
        wrCmdRqt <='0';
		finishRead <='0';
		trackOK<='0';
		fsmByteRqt <='0';
		readVarLengthRqt <='0';
		
		
    elsif rising_edge(clk) then
		finishRead <='0';
		fsmByteRqt <='0';
		readVarLengthRqt <='0';



        -- PipeLined operations, 2 stages, to calculate wait time
        -- Satur result, stage 1
        if addAux0(48)='0' then
            regAux0 := addAux0(47 downto 20);
        else
            regAux0 := (others=>'1');
        end if;
        
        -- Satur result, stage 2
        if mulAux1(32)='0' then
            regAux1 := mulAux1(31 downto 0);
        else
            regAux1 := (others=>'1');    
        end if;


        if cen='1' then
            if fsm_state.state/=s0 then
                cntr := (others=>'0');
                trackOK<='0';
                fsm_state.state:=s0;
            end if;
        else
            case fsm_state.state is
                when s0=>
                    if readRqt(0)='1' then	
                        regAddr := unsigned(trackAddrStart);
                        fsm_state.mode := check;
                        fsmByteRqt <='1';
                        fsm_state.state := s1;                    
                        trackOK<='0';
                    elsif readRqt(1)='1' then
                        regAddr := unsigned(trackAddrStart) + 8; -- Skip track mark and length data 
                        regTempo  := std_logic_vector(to_unsigned(500000,24)); -- Following the midi standard
                        readVarLengthRqt <='1';
                        fsm_state.state := s3;                    
                        fsm_state.mode := play;
                    end if;
            
                -- Check TRACK_CHUNK_MARK
                when s1 =>
                    if cntr < 4 then 
                        if byteAck='1' then
                            
                            if cntr < 3 then
                              fsmByteRqt <='1';
                            end if;
                            
                            regAux := regAux(23 downto 0) & nextByte;
                            regAddr := regAddr+1;
                            cntr := cntr+1;
                        end if;
                    else
                        cntr :=(others=>'0');
                        if regAux=TRACK_CHUNK_MARK then
                            if fsm_state.mode=play then
                                regAddr := regAddr + 4; -- Avoid track length information 
                                readVarLengthRqt <='1';
                                fsm_state.state := s3;
                            else
                                fsmByteRqt <='1';
                                fsm_state.state := s2;
                            end if;
                        
                        else
                            finishRead <='1';
                            fsm_state.state := s0;
                        end if;
                    end if;
    
                -- Save nÃƒâ€šÃ‚Âº bytes of track
                when s2 =>
                    if cntr < 4 then 
                        if byteAck='1' then
                            
                            if cntr < 3 then
                              fsmByteRqt <='1';
                            end if;
                            
                            regAux := regAux(23 downto 0) & nextByte;
                            regAddr := regAddr+1;
                            cntr := cntr+1;
                        end if;
                    else
                        cntr :=(others=>'0');
                        readVarLengthRqt <='1';
                        fsm_state.state := s3;
                    end if;
                    
                -----------------------------------------
                -- MAIN LOOP STARTS IN THIS STATE (s3) --
                -----------------------------------------
                -- Event Parser Starts in this state, first read delta time	
                -- Get the time to wait before processing the midi command                
                when s3 =>
                    if cntr=0 then
                        if varLengthRdy='1' then 
                            cntr :=cntr+1;
                        end if;
                    -- Wait two cycles to calculate wait time in ms
                    elsif cntr<2 then
                        cntr :=cntr+1;
                    else
                        -- This condition to avoid infinite loops
                        if fsm_state.mode=play or (fsm_state.mode=check and (readedBytes<=unsigned(regAux))) then                                    
                            regWait := resWait;
                            regAddr := unsigned(varLengthByteAddr) + 1; -- Update the value of the current addr                    
                            cntr :=(others=>'0');
                            if fsm_state.mode = check then
                                fsmByteRqt <='1';
                                fsm_state.state := s5;
                            else
                                fsm_state.state := s4;
                            end if;
                        else
                            finishRead <='1';
                            fsm_state.state := s0;
                        end if;
            
                    end if;--if cntr=0
                    
                -- Wait delta time value in ms before execute command
                when s4 =>
                    if regWait=0 then
                        fsmByteRqt <='1';
                        fsm_state.state := s5;
                    elsif TCmili='1' then
                        regWait := regWait-1;
                    end if;
                
                -- Read one byte and decide if is a status byte or not
                -- If is a status byte, running status will change
                -- If not, runningStatus would not change, 
                -- one more read order of the same byte will be done in the nexts states
                when s5 =>
                    if byteAck='1' then
                        if nextByte(7)='1' then 
                            regAddr := regAddr+1;
                            runningStatus := nextByte;						
                        end if;
                        fsm_state.state := s6;
                    end if;
                
                -- Decision state
                when s6 =>
                    if runningStatus=META_EVENT_MARK then
                        fsmByteRqt <='1';
                        fsm_state.state := resolveMetaEvent;
                    elsif runningStatus=SYSEX_EVENT_0 or runningStatus=SYSEX_EVENT_1 then
                        readVarLengthRqt <='1';
                        fsm_state.state := skipVarLengthBytes;
                    else
                        -----------------
                        -- Midi events --
                        -----------------
                        if runningStatus=MTRK_EVENT_NOTE_OFF or runningStatus=MTRK_EVENT_NOTE_ON  then
                            fsmByteRqt <='1';
                            fsm_state.state := readEventData;
                        -- The rest of midi events follow this pattern, skip those data bytes
                        elsif runningStatus=MTRK_EVENT_CKP or runningStatus=MTRK_EVENT_PC then
                            regAddr := regAddr+1;
                            readVarLengthRqt <='1';
                            fsm_state.state := s3;
                        else
                            regAddr := regAddr+2;
                            readVarLengthRqt <='1';
                            fsm_state.state := s3;
                        end if;
                    end if;
    
                when resolveMetaEvent =>
                    if byteAck='1' then
                        if nextByte=META_EVENT_END_OF_TRACK then
                            finishRead <='1';
                            -- Check if the length of the track is OK, only in check mode
                            if fsm_state.mode=check and (readedBytes=unsigned(regAux)) then
                                trackOK <='1';
                            end if;
                            fsm_state.state := s0; -- Finish of read track chunk
                        elsif nextByte=META_EVENT_SET_TEMPO then
                            fsmByteRqt <='1';
                            if fsm_state.mode=check then
                                regAddr := regAddr+1;
                            else
                                regAddr := regAddr+2;
                            end if;
                            fsm_state.state := manageSetTempoCmd;
                        else
                            readVarLengthRqt <='1';
                            regAddr := regAddr+1;
                            fsm_state.state := skipVarLengthBytes;
                        end if;
                    end if;
              
                when skipVarLengthBytes =>
                    if varLengthRdy='1' then
                        -- NÃƒâ€šÃ‚Âº of bytes starting by the las address readed by VarLength component.
                        regAddr := unsigned(varLengthByteAddr) + unsigned(resVarLength(26 downto 0)) + 1;  
                        readVarLengthRqt <='1';
                        fsm_state.state := s3;
                    end if;
    
    
                when readEventData =>
                    if cntr < 2 then 
                        if byteAck='1' then
                            
                            if cntr < 1 then
                                fsmByteRqt <='1';
                            end if;
    
                            dataBytes := dataBytes(7 downto 0) & nextByte;
                            regAddr := regAddr+1;
                            cntr := cntr+1;
                            
                        end if;
                    else
                        cntr :=(others=>'0');
                        -- Only send command in play mode
                        if fsm_state.mode=play and unsigned(dataBytes(15 downto 8)) >=21 and unsigned(dataBytes(15 downto 8)) <= 108 then
                            wrCmdRqt <='1';
                            cmd(7 downto 0) <=dataBytes(15 downto 8); 
                            if runningStatus=MTRK_EVENT_NOTE_OFF or (runningStatus=MTRK_EVENT_NOTE_ON and dataBytes(7 downto 0)=X"00") then
                               cmd(9 downto 8) <= "01";-- Note off
                            else
                               cmd(9 downto 8) <= "10";-- Note on
                            end if;
                            fsm_state.state := waitSequencerAck;                        
                        else
                            readVarLengthRqt <='1';
                            fsm_state.state := s3;                    
                        end if;
                    end if;
                    
                    
               when waitSequencerAck =>
                  if sequencerAck='1' then
                    wrCmdRqt <='0';
                    readVarLengthRqt <='1';
                    fsm_state.state := s3;
                  end if;
                          
              
                when manageSetTempoCmd =>
                        if fsm_state.mode=check then
                            if byteAck='1' then
                                -- Check the correct format of Set tempo command
                                if nextByte/=SET_TEMPO_CMD_LENGTH then
                                   finishRead <='1';
                                   fsm_state.state := s0; 
                                else
                                    readVarLengthRqt <='1';
                                    regAddr := regAddr+4; -- 3 bytes for tempo value and 1 byte for length
                                    fsm_state.state := s3;
                                end if;  
                            end if;
                        else
                            if cntr < 3 then 
                                if byteAck='1' then
                                    if cntr < 2 then
                                        fsmByteRqt <='1';
                                    end if;
            
                                    regTempo := regTempo(15 downto 0) & nextByte;
                                    regAddr := regAddr+1;
                                    cntr := cntr+1;
                                    
                                end if;
                            else                                
                                cntr :=(others=>'0');
                                readVarLengthRqt <='1';
                                fsm_state.state := s3;
                            end if;
                    end if;-- fsm_state.mode=check
              
              end case;
              
        end if; --cen='0' 
    end if;-- rising_edge(clk)
end process;
  
end Behavioral;
