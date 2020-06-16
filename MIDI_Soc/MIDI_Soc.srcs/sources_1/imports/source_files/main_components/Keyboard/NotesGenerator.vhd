----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: NotesGenerator - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 1.4
-- Additional Comments:
--  NUM_NOTES_GEN = 2**k
-- 
-- mem_CmdReadResponse(NUM_NOTES_GEN-1+log2(NUM_NOTES_GEN) downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
--
-- mem_CmdReadRequest(25+log2(NUM_NOTES_GEN) downto 26)= note gen index, mem_CmdReadRequest(15 downto 0) = requested sample
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;


entity NotesGenerator is
  Generic( NUM_NOTES_GEN :   in  natural);
  Port ( 
        rst_n           					:   in  std_logic;
        clk             					:   in  std_logic;
        notes_on        					:   in  std_logic_vector(NUM_NOTES_GEN-1 downto 0);
        working								:	out	std_logic_vector(NUM_NOTES_GEN-1 downto 0);
				
		--Note params		
		startAddr_In             			: in std_logic_vector(25 downto 0);
		sustainStartOffsetAddr_In			: in std_logic_vector(25 downto 0);
		sustainEndOffsetAddr_In     		: in std_logic_vector(25 downto 0);
		stepVal_In                  		: in std_logic_vector(63 downto 0);
        noteVelocity                        : in std_logic_vector(3 downto 0);
        
		--IIS side		
        sampleRqt       					:   in  std_logic;
        sampleOut       					:   out std_logic_vector(23 downto 0);
        
        -- Mem side
		mem_emptyResponseBuffer				:	in	std_logic;
        mem_CmdReadResponse    				:   in  std_logic_vector(15+log2(NUM_NOTES_GEN) downto 0);
        mem_fullReciveBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    		:   out std_logic_vector(25+log2(NUM_NOTES_GEN) downto 0);
		mem_readResponseBuffer				:	out std_logic;
        mem_writeReciveBuffer     			:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  NotesGenerator  :   entity  is  "true";
end NotesGenerator;


architecture Behavioral of NotesGenerator is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
    -- This generate more signals that the necessary ones
	-- Trust in the syntesis tool to avoid the mapping of unnecesary signals
	type    signalsPerLevel  is array( 0 to NUM_NOTES_GEN-1 ) of std_logic_vector(23 downto 0); 
	type    samples  is array( 0 to log2(NUM_NOTES_GEN) ) of signalsPerLevel;
	
	type   addrGen is  array(0 to NUM_NOTES_GEN-1) of std_logic_vector(25 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- For sum
    signal  notesGen_samplesOut :   samples;
	
	signal fsmsCe                                          :    std_logic;
	signal memAckResponse, memAckSend, memSamplesSendRqt   :    std_logic_vector(NUM_NOTES_GEN-1 downto 0);
	signal workingInter, sampleCe                          :    std_logic_vector(NUM_NOTES_GEN-1 downto 0);
	
	signal notesGen_addrOut    :   addrGen;
begin

----------------------------------------------------------------------------------
-- PIPELINED SUM
--      Manage the sums of all notes, is organized as a balanced tree
---------------------------------------------------------------------------------- 
genTreeLevels:
for i in 0 to log2(NUM_NOTES_GEN)-1 generate
	genFixedSumsPerTreeLevel:
	for j in 0 to ( (NUM_NOTES_GEN/2**(i+1)) - 1) generate
		sum: MyFiexedSum
		generic map(WL=>24)
		port map( rst_n =>rst_n, clk=>clk,a_in=>notesGen_samplesOut(i)(j*2),b_in=>notesGen_samplesOut(i)(j*2+1),c_out=>notesGen_samplesOut(i+1)(j));
	end generate;
end generate;

sampleOut <= notesGen_samplesOut(log2(NUM_NOTES_GEN))(0);

----------------------------------------------------------------------------------
-- NOTES GENERATOR
--      Creation of the notes generators components
----------------------------------------------------------------------------------
working <=workingInter;
genNotes:
for i in 0 to NUM_NOTES_GEN-1 generate
	NoteGen: UniversalNoteGen
	  port map(
		-- Host side
		rst_n                   	=> rst_n,
		clk                     	=> clk,
		noteOnOff               	=> notes_on(i),
		sampleRqt    				=> sampleRqt, -- IIS new sample Rqt
		working						=> workingInter(i),
		sample_out              	=> notesGen_samplesOut(0)(i),

		-- NoteParams               
		startAddr_In				=> startAddr_In				,
		sustainStartOffsetAddr_In	=> sustainStartOffsetAddr_In,
		sustainEndOffsetAddr_In    	=> sustainEndOffsetAddr_In  ,
		stepVal_In					=> stepVal_In				,
        noteVelocity                => noteVelocity,
        
		-- Mem side                 
		samples_in                  => mem_CmdReadResponse(15 downto 0),    	
		memAckSend                 	=> memAckSend(i),     	
		memAckResponse		       	=> memAckResponse(i),      	
		addr_out                   	=> notesGen_addrOut(i),     	
	    memSamplesSendRqt  		   	=> memSamplesSendRqt(i)
	  );

end generate;

-- Internal ce signal for the FSMs, check if some note is working
cenForFsms: reducedOr
  generic map(WL=>NUM_NOTES_GEN)
  port map(a_in=>workingInter, reducedA_out=>fsmsCe);

----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmResponse:
process(mem_emptyResponseBuffer,mem_CmdReadResponse)
begin
    -- Everything in one cycle

    mem_readResponseBuffer <= '0';
    memAckResponse <=(others=>'0');
    if mem_emptyResponseBuffer='0' then
        memAckResponse(to_integer( unsigned(mem_CmdReadResponse(15+log2(NUM_NOTES_GEN) downto 16)) )) <='1';
        -- Read order to response buffer
        mem_readResponseBuffer <='1';
    end if; 
               
end process;
  

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmSend:
process(rst_n,clk,memSamplesSendRqt,mem_fullReciveBuffer)
    type states is ( checkGeneratorRqt, sendSecondCmd);
    
    variable state      	:   states;
    variable turnCntr   	:   natural range 0 to NUM_NOTES_GEN-1;
    variable regReadCmdRqt 	:   std_logic_vector(25+log2(NUM_NOTES_GEN) downto 0);
    
    variable addrPlusOne    :   unsigned(25 downto 0);
    variable flag           :   std_logic;
begin
    
    mem_CmdReadRequest <= regReadCmdRqt;
    addrPlusOne := unsigned(regReadCmdRqt(25 downto 0))+1;
    
    if rst_n='0' then
       turnCntr := 0;
       state := checkGeneratorRqt;
       regReadCmdRqt := (others=>'0');
       flag :='0';
       mem_writeReciveBuffer <= '0';
       memAckSend <=(others=>'0');
	   
    elsif rising_edge(clk) then
        mem_writeReciveBuffer <= '0'; -- Just one cycle
		memAckSend <=(others=>'0'); -- Just one cycle
        
		case state is
			
			-- Two Cmd per read request of a note generator
            when checkGeneratorRqt =>
                if fsmsCe='1' then
                    -- Wait one cycle to the previous write order take effect
                    if flag='0' then
                         if mem_fullReciveBuffer='0' then
                            if memSamplesSendRqt(turnCntr)='1' then
                                regReadCmdRqt := std_logic_vector(to_unsigned(turnCntr,log2(NUM_NOTES_GEN))) & notesGen_addrOut(turnCntr); -- Note Gen index + sample addr
                                -- Write command in the mem buffer
                                mem_writeReciveBuffer <= '1';
                                -- Send ack to note gen
                                memAckSend(turnCntr) <='1';
                                flag :=not flag;
                                state := sendSecondCmd;
                            else
                                if turnCntr=NUM_NOTES_GEN-1 then -- Until max notes
                                    turnCntr := 0;
                                else
                                    turnCntr := turnCntr+1;
                                end if;
                            end if;
                        end if;--fsmsCe='1' and mem_fullReciveBuffer='0'  
                  else
                    flag := not flag;               
                  end if;
              end if; --fsmsCe='1'		
              	
			when sendSecondCmd =>
                -- Wait one cycle to the previous write order take effect
                if flag='0' then
                    if mem_fullReciveBuffer='0' then		
                        regReadCmdRqt(25 downto 0) := std_logic_vector(addrPlusOne); -- Note Gen index + sample addr
                        -- Write command in the mem buffer
                        mem_writeReciveBuffer <= '1';
                        flag :=not flag;
                        if turnCntr=NUM_NOTES_GEN-1 then -- Until max notes
                            turnCntr := 0;
                        else
                            turnCntr := turnCntr+1;
                        end if; 
                        state := checkGeneratorRqt;                
                    end if;
			   else
			    flag := not flag;
			   end if;
			   
        end case;
        
        
        
    end if;
end process;
  
end Behavioral;