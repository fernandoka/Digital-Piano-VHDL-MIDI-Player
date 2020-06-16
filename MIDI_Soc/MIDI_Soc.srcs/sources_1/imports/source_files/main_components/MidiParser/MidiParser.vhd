----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: MidiParser.vhd - Behavioral
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
--      This component at least can read one track.
--
--      ReadTrack_0 and ReadHeader share the BP_0 component to request the data bytes
--
--      Length of Keyboard cmd is 14
--
--		-- For Midi parser component --
--		Format of mem_CmdReadRequest	:	cmd(24 downto 0) = 16bytes addr to read,  
--									 	
--										cmd(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1 downto 25) /= "(others=>'0')"  -> "BP index" cmd from ByteProvider_i
--									                   
--										cmd(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1 downto 25) = "(others=>'0')" -> cmd from OneDividedByDivisionProvider
--
--
--		-- For Midi parser component --
--		Format of mem_CmdReadResponse :	If cmd(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1 downto 25) /= "(others=>'0')" 
--											cmd(127 downto 0) = bytes readed for 16 bytes addr
--									 	else
--											cmd(127 downto 32) = (others=>'0')
--											cmd(31 downto 0) = bytes readed for 4 bytes addr
--						
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;

entity MidiParser is
  Generic(MAX_NUM_TRACKS :   in  natural);
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;

        -- Host
		cen							:	in	std_logic;
		readMidifileRqt				:	in	std_logic;
		fileOk						:	out	std_logic;
		OnOff						:	out	std_logic;
        
        --Debug
        statesOut_MidiCntrl         :   out std_logic_vector(4 downto 0);
        
        -- Keyboard side
		keyboard_ack	            :	in	std_logic; -- Request of a new command
        aviableCmd                  :   out std_logic; -- High until keyboard ack   
        cmdKeyboard                 :   out std_logic_vector(14 downto 0);

        -- Mem side
		mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1+127 downto 0);
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1+24 downto 0); 
		mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  MidiParser  :   entity  is  "true";
end MidiParser;

architecture Behavioral of MidiParser is
----------------------------------------------------------------------------------
-- CONSTANTS DECLARATIONS
----------------------------------------------------------------------------------
    constant    INTERN_MAX_NUM_TRACKS       :   natural := getNumMidiTracks(MAX_NUM_TRACKS);
    constant    START_ADDR_OF_ODBD_CONST    :   natural := 2844660;
    constant    MIDI_FILE_START_ADDR        :   natural := 11509712;
    
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
	type    byteAddr_t is array(0 to INTERN_MAX_NUM_TRACKS-1)     of std_logic_vector(26 downto 0); 
	type    byteData_t is array( 0 to INTERN_MAX_NUM_TRACKS-1 )   of std_logic_vector(7 downto 0);
	type    memAddr_t  is array( 0 to INTERN_MAX_NUM_TRACKS-1 )   of std_logic_vector(22 downto 0);
    type    tempoValue_t    is array(0 to INTERN_MAX_NUM_TRACKS-1) of std_logic_vector(23 downto 0);
        
----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- For Midi Controller component
	signal	muxBP_0	:	std_logic;

	-- For ODBD component
    signal  ODBD_ReadRqt, ODBD_readyVal 	:   std_logic;
	signal	divisionVal						:	std_logic_vector(14 downto 0); -- Input in ODBD component, used as output signal in Read Header Component
	signal	ODBD_Val						:	std_logic_vector(23 downto 0);
	signal	mem_ODBD_addr					:	std_logic_vector(24 downto 0);
	
	-- For ByteProvider components
	signal	BP_addr				:	byteAddr_t;
	signal	BP_data				:	byteData_t;
	signal	BP_byteRqt, BP_ack	:	std_logic_vector(INTERN_MAX_NUM_TRACKS-1 downto 0);
	signal  goFirstRead         :   std_logic;
	
	-- For Read Header components
	signal	readFinishHeader, headerOKe, startHeaderRead    :	std_logic;
	signal	finishTracksRead, tracksOK                  :	std_logic_vector(INTERN_MAX_NUM_TRACKS-1 downto 0);
	signal  readTracksRqt                               :   std_logic_vector(INTERN_MAX_NUM_TRACKS*2-1 downto 0); -- Send start parse/read of track
	signal	tracksAddrStart							    :	std_logic_vector(INTERN_MAX_NUM_TRACKS*27-1 downto 0); -- Addr of the first byte of the track
    signal  numTracksToRead                             :   std_logic_vector(15 downto 0);

	signal	BP_addr_ReadHeader							:	std_logic_vector(26 downto 0); 
	signal	BP_data_ReadHeader							:	std_logic_vector(7 downto 0);
	signal	BP_byteRqt_ReadHeader, BP_ack_ReadHeader	:	std_logic;
	signal  OnOffInter                                  :   std_logic;
	
	-- For Read Tracks components
	signal	BP_addr_ReadTrack_0							:	std_logic_vector(26 downto 0); 
	signal	BP_data_ReadTrack_0							:	std_logic_vector(7 downto 0);
	signal	BP_byteRqt_ReadTrack_0, BP_ack_ReadTrack_0	:	std_logic;
	
	signal  wrCmdRqt                                    :  std_logic_vector(INTERN_MAX_NUM_TRACKS-1 downto 0);
	signal  sequencerAck                                :  std_logic_vector(INTERN_MAX_NUM_TRACKS-1 downto 0);
	signal  updateTempoVal                              :  tempoValue_t;
	signal  updateTempoRqt, updateTempoAck              :  std_logic_vector(INTERN_MAX_NUM_TRACKS-1 downto 0);
	
	signal  regCurrentTempo                             :  std_logic_vector(23 downto 0);
  
	-- For manage the mem CMDs
	signal	memAckSend, memAckResponse, memSamplesSendRqt	:	std_logic_vector(INTERN_MAX_NUM_TRACKS downto 0);
	signal	mem_byteP_addrOut								:	memAddr_t;
	
	-- For Cmd Sequencer
    signal allTracks   :    std_logic_vector(INTERN_MAX_NUM_TRACKS*14-1 downto 0);
    signal cmdSeq      :    std_logic_vector(13 downto 0);

begin

----------------------------------------------------------------------------------
-- COMPONENTS
--		MidiController
--      Byte Provider components
--		OneDividedByDivision component
--		Read Header Component
--      Cmd Keyboard Sequencer
--		Read Track Components
----------------------------------------------------------------------------------  

-- Multiplexors for BP_0
	BP_addr(0) <= BP_addr_ReadHeader when muxBP_0='0' else BP_addr_ReadTrack_0;	
	BP_byteRqt(0) <= BP_byteRqt_ReadHeader when muxBP_0='0' else BP_byteRqt_ReadTrack_0;
	
	BP_data_ReadHeader <= BP_data(0) when muxBP_0='0' else (others=>'0');
    BP_ack_ReadHeader <= BP_ack(0) when muxBP_0='0' else '0';
    
	BP_data_ReadTrack_0 <= BP_data(0) when muxBP_0='1' else (others=>'0');
    BP_ack_ReadTrack_0 <= BP_ack(0) when muxBP_0='1' else '0';

--------------------------------------------------------------------
-- MIDI CONTROLLER
--------------------------------------------------------------------
OnOff <=OnOffInter;
my_MidiController : MidiController
 generic map(MAX_NUM_TRACKS=> INTERN_MAX_NUM_TRACKS)
 port map( 
        rst_n           	=> rst_n,	
        clk                 => clk,    
        cen                 => cen,
        readMidifileRqt     => readMidifileRqt,    
        finishHeaderRead    => readFinishHeader,    
        headerOK            => headerOKe,    
        finishTracksRead    => finishTracksRead,    
        tracksOK            => tracksOK,    
        ODBD_ValReady       => ODBD_readyVal,    
        numTracksToRead     => numTracksToRead,
                         
        readHeaderRqt        => startHeaderRead,
        muxBP_0              => muxBP_0,
        goFirstRead          => goFirstRead,
        readTracksRqt        => readTracksRqt,    
        parseOnOff           => OnOffInter,    
        fileOk               => fileOk,                        
        --Debug                 
        statesOut            => statesOut_MidiCntrl
		
  );

--------------------------------------------------------------------
-- BYTE PROVIDERS COMPONENTS 
--------------------------------------------------------------------
BP_0 : ByteProvider
  port map( 
        rst_n => rst_n,
        clk => clk,
		addrInVal =>BP_addr(0),			
        byteRqt =>BP_byteRqt(0),  
        byteAck => BP_ack(0),            
        nextByte => BP_data(0),
        goFirstRead => goFirstRead,
        
        -- Mem side
		dataIn       	    =>	mem_CmdReadResponse(127 downto 0),
        memAckSend       	=>	memAckSend(1),
        memAckResponse   	=>	memAckResponse(1),
        addr_out         	=>	mem_byteP_addrOut(0),    
		memSamplesSendRqt	=>	memSamplesSendRqt(1)

	);

genBP:if INTERN_MAX_NUM_TRACKS > 1 generate
    genBP_Loop:for i in 2 to INTERN_MAX_NUM_TRACKS generate
        BP_i : ByteProvider
            port map( 
                rst_n => rst_n,
                clk => clk,
                addrInVal =>BP_addr(i-1),			
                byteRqt =>BP_byteRqt(i-1),  
                byteAck => BP_ack(i-1),            
                nextByte =>BP_data(i-1),
                goFirstRead => goFirstRead,
                      
                -- Mem arbitrator side
                dataIn       	    =>	mem_CmdReadResponse(127 downto 0),
                memAckSend       	=>	memAckSend(i),
                memAckResponse   	=>	memAckResponse(i),
                addr_out         	=>	mem_byteP_addrOut(i-1),    
                memSamplesSendRqt	=>	memSamplesSendRqt(i)
            
            );
        end generate genBP_Loop;
end generate genBP;

--------------------------------------------------------------------
-- ONE DIVIDED BY DIVISON COMPONENT
--------------------------------------------------------------------
my_ODBD_Provider : OneDividedByDivision_Provider
  generic map(START_ADDR=> START_ADDR_OF_ODBD_CONST) -- Address of 4Bytes of the first OneDividedByDivision constants stored in memory 
  port map( 
        rst_n           		=> rst_n,
        clk             		=> clk,
		readRqt					=> ODBD_ReadRqt,
		division				=> divisionVal,
		readyValue				=> ODBD_readyVal,
		OneDividedByDivision	=> ODBD_Val,
		 
		-- Mem arbitrator side
		dataIn       			=>	mem_CmdReadResponse(23 downto 0),
		memAckSend      		=>	memAckSend(0),		
		memAckResponse			=>	memAckResponse(0),
		addr_out        		=>	mem_ODBD_addr,    
		memConstantSendRq		=>	memSamplesSendRqt(0)

  );

--------------------------------------------------------------------
-- READ HEADER CHUNK COMPONENT
--  NOT REDUCED SET OF ODBD CONSTANTS 
--      Address of the first byte of midi file ->11640784 = ((189644*30)+65535*2)*2+4
--  REDUCED SET OF ODBD CONSTANTS
--      Address of the first byte of midi file ->11509712= ((189644*30)+32767*2)*2+4
--------------------------------------------------------------------
my_ReadHeaderChunk : ReadHeaderChunk 
  generic map(START_ADDR=> MIDI_FILE_START_ADDR, MAX_NUM_TRACKS=> INTERN_MAX_NUM_TRACKS)  
  port map( 
    rst_n               => rst_n,
    clk                 => clk,
    cen                 => cen,                     
    readRqt             => startHeaderRead,            
    finishRead          => readFinishHeader,  
    headerOk            => headerOKe,
    numTracksToRead     => numTracksToRead,
    
    -- OneDividedByDivision_Provider side
    ODBD_ReadRqt => ODBD_ReadRqt,
    division     => divisionVal,
    
    -- Start addreses for the Read Trunk Chunk components
    tracksAddrStart => tracksAddrStart,
    
    --Byte provider side
    nextByte => BP_data_ReadHeader,
    byteAck  => BP_ack_ReadHeader,
    byteAddr => BP_addr_ReadHeader,
    byteRqt  => BP_byteRqt_ReadHeader

  );

--------------------------------------------------------------------
-- CMD KEYBOARD SEQUENCER 
--------------------------------------------------------------------

cmdKeyboard <='0' & cmdSeq;

SequencerCMD: TracksCmdSequencer
  generic map(WL_CMD => 14, NUM_TRACK_READERS => INTERN_MAX_NUM_TRACKS)
  port map( 
        rst_n           => rst_n,
        clk             => clk,
        
        -- Cmd Inputs   
        tracksCmd       => allTracks,
        sendCmdRqt      => wrCmdRqt,
        seq_ack         => sequencerAck,
    
        -- Out side     
        keyboard_ack    => keyboard_ack,
        aviableCmdRqt   => aviableCmd,
        cmdKeyboard     => cmdSeq
  );

--------------------------------------------------------------------
-- READ TRACKS COMPONENTS
--------------------------------------------------------------------
my_currentTempo:
process(rst_n,clk,updateTempoRqt,OnOffInter)
    constant    TRACK_MAX_INDEX :   natural :=INTERN_MAX_NUM_TRACKS-1;
    variable    turn            :   natural range 0 to TRACK_MAX_INDEX;
    variable    internCe        :   std_logic_vector(TRACK_MAX_INDEX downto 0);
    
    variable    waitOneCycleFlag    :   boolean;
    
begin
    internCe(0) := updateTempoRqt(0);
    for i in 1 to TRACK_MAX_INDEX loop
        internCe(i) := updateTempoRqt(i) or internCe(i-1);
    end loop;

    if rst_n='0' then
        regCurrentTempo <=std_logic_vector(to_unsigned(500000,24)); -- Following the midi standard
        updateTempoAck <=(others=>'0');
        waitOneCycleFlag := false;
        turn := 0;
        
    elsif rising_edge(clk) then
        updateTempoAck <=(others=>'0');
        
        if OnOffInter='1' then
            if not waitOneCycleFlag then 
                if internCe(TRACK_MAX_INDEX)='1' then
                    if updateTempoRqt(turn)='1' then
                        updateTempoAck(turn) <='1';
                        regCurrentTempo <=updateTempoVal(turn);
                        waitOneCycleFlag := true;
                    end if;
                    if turn = TRACK_MAX_INDEX then
                        turn := 0;
                    else
                        turn := turn+1;
                    end if;
                end if;-- if updateTempoRqt(turn)='1' then
           else
               waitOneCycleFlag := not waitOneCycleFlag; 
           end if; -- if not waitOneCycleFlag then 
         else
            if unsigned(regCurrentTempo)/=to_unsigned(500000,24) then
                regCurrentTempo <=std_logic_vector(to_unsigned(500000,24)); -- Following the midi standard
            end if;
            
            if waitOneCycleFlag then 
                waitOneCycleFlag := not waitOneCycleFlag ;
            end if;
            
        end if; --OnOffInter='1'
        
    end if;--rst_n/rising_edge
end process my_currentTempo;

ReadTrackChunk_0 : ReadTrackChunk
  port map( 
        rst_n           		=> rst_n,	
        clk             		=> clk,	
        cen                 	=> cen,    
		readRqt					=> readTracksRqt(1 downto 0),	
		trackAddrStart			=> tracksAddrStart(26 downto 0),	
		OneDividedByDivision	=> ODBD_Val,
		
      -- Tempo
        currentTempo            => regCurrentTempo,
        updateTempoAck          => updateTempoAck(0),
        updateTempoRqt          => updateTempoRqt(0),
        updateTempoVal          => updateTempoVal(0),
		
        -- Read status
		finishRead				=> finishTracksRead(0),	
		trackOK					=> tracksOK(0),	
		
        -- CMD Keyboard interface
        sequencerAck            => sequencerAck(0),
        wrCmdRqt                => wrCmdRqt(0),
        cmd                     => allTracks(14-1 downto 0),
  
								
		--Byte provider side	    
		nextByte        		=> BP_data_ReadTrack_0,
		byteAck					=> BP_ack_ReadTrack_0,	
		byteAddr        		=> BP_addr_ReadTrack_0,	
		byteRqt					=> BP_byteRqt_ReadTrack_0	
	
  );

genReadTrack:if INTERN_MAX_NUM_TRACKS > 1 generate
    genReadTrack_Loop:for i in 1 to INTERN_MAX_NUM_TRACKS-1 generate
        ReadTrackChunk_i : ReadTrackChunk
          port map( 
                rst_n           		=> rst_n,	
                clk             		=> clk,	
                cen                 	=> cen,    
                readRqt					=> readTracksRqt(2*(i+1)-1 downto 2*i),	
                trackAddrStart			=> tracksAddrStart(27*(i+1)-1 downto 27*i),	
                OneDividedByDivision	=> ODBD_Val,
                
                -- Tempo
                currentTempo            => regCurrentTempo,
                updateTempoAck          => updateTempoAck(i),
                updateTempoRqt          => updateTempoRqt(i),
                updateTempoVal          => updateTempoVal(i),
        
                -- Read status	
                finishRead				=> finishTracksRead(i),	
                trackOK					=> tracksOK(i),	
        
                -- CMD Keyboard interface
                sequencerAck            => sequencerAck(i),
                wrCmdRqt                => wrCmdRqt(i),
                cmd                     => allTracks((i+1)*14-1 downto i*14),
                                        
                --Byte provider side	    
                nextByte        		=> BP_data(i),
                byteAck					=> BP_ack(i),	
                byteAddr        		=> BP_addr(i),	
                byteRqt					=> BP_byteRqt(i)	
            
          );
        end generate genReadTrack_Loop;
end generate genReadTrack;

----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the byte providers components
--      and the ODBD provider 
----------------------------------------------------------------------------------  

fsmResponse:
process(rst_n,clk,cen,mem_emptyBuffer,mem_CmdReadResponse)
begin
    -- Everything in one cycle
    
    -- Read order to response buffer, read send response  
    mem_readResponseBuffer <= '0'; 
    memAckResponse <=(others=>'0');
    if cen='0' and mem_emptyBuffer='0' then        
        mem_readResponseBuffer <= '1';
        memAckResponse(to_integer( unsigned(mem_CmdReadResponse(log2(getNumMidiTracks(MAX_NUM_TRACKS))+1+127 downto 128)) )) <='1';
    end if;

end process fsmResponse;
  

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmSend:
process(rst_n,clk,cen,memSamplesSendRqt)    
    
    variable turnCntr   	:   natural  range 0 to INTERN_MAX_NUM_TRACKS;
    variable regReadCmdRqt 	:   std_logic_vector(log2(INTERN_MAX_NUM_TRACKS)+1+24 downto 0);
    
begin
    
    mem_CmdReadRequest <= regReadCmdRqt;
  
    if rst_n='0' then
       turnCntr := 0;
       regReadCmdRqt := (others=>'0');
       mem_writeReciveBuffer <= '0';
       memAckSend <=(others=>'0'); 
               
    elsif rising_edge(clk) then
        mem_writeReciveBuffer <= '0'; -- Just one cycle
        memAckSend <=(others=>'0'); -- Just one cycle
                
        if cen='0' then
			if memSamplesSendRqt(turnCntr)='1' then
				-- Write command in the mem buffer
				mem_writeReciveBuffer <= '1';
				-- Send Ack to provider
				memAckSend(turnCntr) <='1';
				-- Build cmd
				if turnCntr=0 then
					regReadCmdRqt(log2(INTERN_MAX_NUM_TRACKS)+1+24 downto 25) := (others=>'0');
					regReadCmdRqt(24 downto 0) := mem_ODBD_addr; -- ODBD index + ODBD addr
				else
					regReadCmdRqt := std_logic_vector(to_unsigned(turnCntr,log2(INTERN_MAX_NUM_TRACKS)+1)) & mem_byteP_addrOut(turnCntr-1) & "00"; -- provider index + provider addr
				end if;
				
			end if;
    
			if turnCntr=INTERN_MAX_NUM_TRACKS then -- Until max providers
				turnCntr := 0;
			else
				turnCntr := turnCntr+1;
			end if;		
		end if;
        
    end if;--rst_n/rising_edge
end process fsmSend;
  
end Behavioral;