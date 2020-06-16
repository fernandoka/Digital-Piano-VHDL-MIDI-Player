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
-- Revision 0.9
-- Additional Comments:
--		Not completly generic component, the pipelined sum and the NotesGenerators 
--		have to be done by hand
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

entity NotesGenerator is
  Port ( 
        rst_n           					:   in  std_logic;
        clk             					:   in  std_logic;
        notes_on        					:   in  std_logic_vector(15 downto 0);
        working								:	out	std_logic_vector(15 downto 0);
				
		--Note params		
		startAddr_In             			: in std_logic_vector(25 downto 0);
		sustainStartOffsetAddr_In			: in std_logic_vector(25 downto 0);
		sustainEndOffsetAddr_In     		: in std_logic_vector(25 downto 0);
		maxSamples_In               		: in std_logic_vector(25 downto 0);
		stepVal_In                  		: in std_logic_vector(63 downto 0);
		sustainStepStart_In         		: in std_logic_vector(63 downto 0);
		sustainStepEnd_In           		: in std_logic_vector(63 downto 0);
				
		--IIS side		
        sampleRqt       					:   in  std_logic;
        sampleOut       					:   out std_logic_vector(15 downto 0);
        
        -- Mem side
		mem_emptyResponseBuffer				:	in	std_logic;
        mem_CmdReadResponse    				:   in  std_logic_vector(15+7 downto 0); -- mem_CmdReadResponse(19 downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
        mem_fullReciveBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    		:   out std_logic_vector(25+7 downto 0); -- mem_CmdReadRequest(29 downto 26)= note gen index, mem_CmdReadRequest(15 downto 0) = requested sample
		mem_readResponseBuffer				:	out std_logic;
        mem_writeReciveBuffer     			:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  NotesGenerator  :   entity  is  "true";
end NotesGenerator;

use work.my_common.all;

architecture Behavioral of NotesGenerator is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
    -- This generate more signals that the necessary ones
	-- Trust in the syntesis tool to avoid the mapping of unnecesary signals
	type    signalsPerLevel  is array( 0 to 15 ) of std_logic_vector(15 downto 0); 
	type    samples  is array( 0 to log2(16) ) of signalsPerLevel;
	
	type   addrGen is  array(0 to 15) of std_logic_vector(25 downto 0);

----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- For sum
    signal  notesGen_samplesOut :   samples;
	
	signal fsmsCe                                          :    std_logic;
	signal memAckResponse, memAckSend, memSamplesSendRqt   :    std_logic_vector(15 downto 0);
	signal workingInter, sampleCe                          :    std_logic_vector(15 downto 0);
	
	signal notesGen_addrOut    :   addrGen;
begin

----------------------------------------------------------------------------------
-- PIPELINED SUM
--      Manage the sums of all notes, is organized as a balanced tree
---------------------------------------------------------------------------------- 
genTreeLevels:
for i in 0 to log2(16)-1 generate
	genFixedSumsPerTreeLevel:
	for j in 0 to ( (16/2**(i+1)) - 1) generate
		sum: MyFiexedSum
		generic map(WL=>16)
		port map( rst_n =>rst_n, clk=>clk,a_in=>notesGen_samplesOut(i)(j*2),b_in=>notesGen_samplesOut(i)(j*2+1),c_out=>notesGen_samplesOut(i+1)(j));
	end generate;
end generate;

sampleOut <= notesGen_samplesOut(log2(16))(0);

----------------------------------------------------------------------------------
-- NOTES GENERATOR
--      Creation of the notes generators components
----------------------------------------------------------------------------------
working <=workingInter;
genNotes:
for i in 0 to 15 generate
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
		maxSamples_In				=> maxSamples_In			,
		stepVal_In					=> stepVal_In				,
		sustainStepStart_In			=> sustainStepStart_In		,
		sustainStepEnd_In			=> sustainStepEnd_In		,

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
  generic map(WL=>16)
  port map(a_in=>workingInter, reducedA_out=>fsmsCe);

----------------------------------------------------------------------------------
-- MEM CMD READ RESPONSE ARBITRATOR
--      Manage the read response commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmResponse:
process(fsmsCe,mem_emptyResponseBuffer)
begin
    -- Everything in one cycle

    mem_readResponseBuffer <= '0';
    memAckResponse <=(others=>'0');
    if fsmsCe='1' and mem_emptyResponseBuffer='0' then
        memAckResponse(to_integer( unsigned(mem_CmdReadResponse(19 downto 16)) )) <='1';
        -- Read order to response buffer
        mem_readResponseBuffer <='1';
    end if; 
               
end process;
  

 
----------------------------------------------------------------------------------
-- MEM CMD READ RQT ARBITRATOR
--      Manage the read request commands of the DDR for the notes generators components 
----------------------------------------------------------------------------------  

fsmSend:
process(rst_n,clk,fsmsCe,memSamplesSendRqt,mem_fullReciveBuffer)
    type states is ( checkGeneratorRqt, waitMemAck0);
    
    variable state      	:   states;
    variable turnCntr   	:   unsigned(6 downto 0);
    variable regReadCmdRqt 	:   std_logic_vector(25+7 downto 0);
    
    variable addrPlusOne    :   unsigned(25 downto 0);
begin
    
    mem_CmdReadRequest <= regReadCmdRqt;
    addrPlusOne := unsigned(regReadCmdRqt(25 downto 0))+1;
    
    if rst_n='0' then
       turnCntr := (others=>'0');
       state := checkGeneratorRqt;
       regReadCmdRqt := (others=>'0');
       mem_writeReciveBuffer <= '0';
       memAckSend <=(others=>'0');
	   
    elsif rising_edge(clk) then
        mem_writeReciveBuffer <= '0'; -- Just one cycle
		memAckSend <=(others=>'0'); -- Just one cycle
        
		case state is
			
			-- Two Cmd per read request of a note generator
            when checkGeneratorRqt =>
                 if fsmsCe='1' and mem_fullReciveBuffer='0' then
                    if memSamplesSendRqt(to_integer(turnCntr))='1' then
                        regReadCmdRqt := std_logic_vector(turnCntr) & notesGen_addrOut(to_integer(turnCntr)); -- Note Gen index + sample addr
                        -- Write command in the mem buffer
                        mem_writeReciveBuffer <= '1';
						-- Send ack to note gen
                        memAckSend(to_integer(turnCntr)) <='1';
						state := waitMemAck0;
				    else
                        if turnCntr=15 then -- Until max notes
                            turnCntr := (others=>'0');
                        else
                            turnCntr := turnCntr+1;
                        end if;
				    end if;
				    
                end if;--fsmsCe='1' and mem_fullReciveBuffer='0'  
            
			
			when waitMemAck0 =>
                if mem_fullReciveBuffer='0' then		
					regReadCmdRqt(25 downto 0) := std_logic_vector(addrPlusOne); -- Note Gen index + sample addr
					-- Write command in the mem buffer
					mem_writeReciveBuffer <= '1';
					if turnCntr=15 then -- Until max notes
                        turnCntr := (others=>'0');
                    else
                        turnCntr := turnCntr+1;
                    end if; 
					state := checkGeneratorRqt;                
				end if;
			
        end case;
        
        
        
    end if;
end process;
  
end Behavioral;