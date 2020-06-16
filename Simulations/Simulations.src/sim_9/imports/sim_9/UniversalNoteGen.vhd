----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision: 
-- Revision 0.4
-- Additional Comments: 
--		These signals follow a Q32.32 fix format:	stepVal_In					
--      											sustainStepStart_In	
--      											sustainStepEnd_In	
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.math_real.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;


entity UniversalNoteGen is
  port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;  
    noteOnOff               	:	in	std_logic; -- On high, Off low
    sampleRqt    				:	in	std_logic;
	working						:	out	std_logic;
    sample_out              	:	out	std_logic_vector(15 downto 0);

    
	-- NoteParams
	startAddr_In				:	in	std_logic_vector(25 downto 0);
	sustainStartOffsetAddr_In	:	in	std_logic_vector(25 downto 0);
	sustainEndOffsetAddr_In    	:	in	std_logic_vector(25 downto 0);
	maxSamples_In				:	in	std_logic_vector(25 downto 0);	-- (TARGET_NOTE/BASE_NOTE)*SAMPLES_PER_WAVETABLE
	stepVal_In					:	in	std_logic_vector(63 downto 0);  -- If is a simple note, stepVal_In=1.0 
	sustainStepStart_In			:	in	std_logic_vector(63 downto 0);	-- If is a simple note, sustainStepStart_In=1.0
	sustainStepEnd_In			:	in	std_logic_vector(63 downto 0);	-- If is a simple note, sustainStepEnd_In=1.0
	
    -- Mem side
    samples_in              	:   in  std_logic_vector(15 downto 0);
    memAckSend                 	:   in 	std_logic;
    memAckResponse				:	in  std_logic;
	addr_out                	:   out std_logic_vector(25 downto 0);
    memSamplesSendRqt           :   out std_logic
  );
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  UniversalNoteGen  :   entity  is  "true";  
end UniversalNoteGen;

use work.my_common.all;

architecture Behavioral of UniversalNoteGen is
---------------------------	CONSTANTS --------------------------------------
	constant    VALUE_TO_ROUND      :   signed(50 downto 0) := "000" & X"000100000000";

	constant    MAX_POS_VAL  :   signed(16 downto 0) := "0" & X"7FFF";
	constant    MAX_NEG_VAL  :   signed(16 downto 0) := "1" & X"0000";
	
---------------------------	SIGNALS	--------------------------------------
	-- Registers
	signal wtinI,wtinIPlus1 : signed(15 downto 0);

	signal finalVal        :	signed(15 downto 0);-- 16 bits
	signal subVal          :   signed(16 downto 0);--17 bits
	signal mulVal          :   signed(49 downto 0); -- 50 bits
    
    signal roundVal        :   signed(50 downto 0); -- 51 bits
    signal addVal          :   signed(16 downto 0);
	
	signal decimalPart     :	signed(32 downto 0);-- 33 bits, msb de signo
	signal ci              :	unsigned(63 downto 0);-- 64 bits	
	
begin	

Interpolate:
    subVal <= (wtinIPlus1(15) & wtinIPlus1) - (wtinI(15) & wtinI); -- Q17.0 = Q16.0-Q16.0
    
    mulVal <= decimalPart*subVal; -- Q49.0 = Q17.0*Q33.0
    
    roundVal <= (mulVal(49) & mulVal) + VALUE_TO_ROUND; --Q50.0 = Q49.0+Q49.0
    
    addVal <= roundVal(50 downto 34) + (wtinI(15) & wtinI); --Q17.0 = Q16.0+Q16.0
    
    finalVal <= MAX_POS_VAL(15 downto 0) when addVal > MAX_POS_VAL else
                MAX_NEG_VAL(15 downto 0) when addVal < MAX_NEG_VAL else
                addVal(15 downto 0);


    decimalPart <= signed("0" & ci(31 downto 0));
	

	filterRegisters :
  process (rst_n, clk, memAckSend, memAckResponse, noteOnOff, sampleRqt)
      type states is (idle, waitCmdAck ,getSample1, getSample2, interpolate, calculateNextAddr); 
      variable state: states;
      variable releaseFlag      :   std_logic;
      variable interpolatedSamplesCntr : unsigned(25 downto 0);
      variable cntr : natural range 0 to 1;
      variable currentAddr : unsigned(25 downto 0);
      variable wtout : signed(15 downto 0);
	  
	  -- NoteParams registers
	  variable	startAddr				:	unsigned(25 downto 0);
	  variable  sustainStartOffsetAddr  :	unsigned(25 downto 0);
	  variable  sustainEndOffsetAddr    :	unsigned(25 downto 0);
	  variable  maxSamples			    :	unsigned(25 downto 0);
	  variable  stepVal				    :	unsigned(63 downto 0);
	  variable	sustainStepStart        :	unsigned(63 downto 0);
	  variable	sustainStepEnd	        :	unsigned(63 downto 0);

 begin          		
                	
    addr_out <= std_logic_vector(currentAddr);
    sample_out <= std_logic_vector(wtout);
	
	------------------
	-- Moore output --
	------------------
    working <='0';
	if state/=idle then
		working <='1';
	end if;
	
	
	if rst_n='0' then
        state := idle;
        cntr := 0;
        interpolatedSamplesCntr := (others=>'0');
        currentAddr :=(others=>'0');
        wtout := (others=>'0');
        releaseFlag :='0';
        wtinIPlus1 <= (others=>'0');
        wtinI <= (others=>'0');
		ci <=(others=>'0');
        memSamplesSendRqt <= '0';
        
	elsif rising_edge(clk) then
            
            case state is
                    
                when idle =>
                    if noteOnOff='1' then
                        cntr := 0;
                        wtout := (others=>'0');
                        interpolatedSamplesCntr := (others=>'0');
						
						-- NoteParams assignement
						currentAddr 			:= unsigned(startAddr_In);
						startAddr               := unsigned(startAddr_In); -- Used in sustain part
						sustainStartOffsetAddr	:= unsigned(sustainStartOffsetAddr_In);			
						sustainEndOffsetAddr    := unsigned(sustainEndOffsetAddr_In);   	
						maxSamples			    := unsigned(maxSamples_In);				
						stepVal				    := unsigned(stepVal_In);					
                        sustainStepStart        := unsigned(sustainStepStart_In);			
						sustainStepEnd	        := unsigned(sustainStepEnd_In);			
						
						state := waitCmdAck;
                        releaseFlag :='0';
                        ci <=(others=>'0');
                        memSamplesSendRqt <= '1';
                    end if;

				when waitCmdAck=>
					if memAckSend='1' then
                       memSamplesSendRqt <= '0';
                       state := getSample1;
					end if;
            
                -- Recive samples
                when getSample1 =>                    
                    if memAckResponse='1' then 
                        wtinI <= signed(samples_in);
                        state := getSample2;
                    end if;            
            
                when getSample2 =>
                   if memAckResponse='1' then 
                       wtinIPlus1 <= signed(samples_in);
					   state := interpolate;
                  end if;
                
                -- Wait 2 SampleRqt because the audio is mono
                when interpolate =>
                    if cntr=0 and sampleRqt ='1' then
                        cntr :=cntr+1;
                    elsif cntr=1 and sampleRqt ='1' then
                        wtout := finalVal;
                        cntr := 0;
                        ci	  <= ci + stepVal; -- Calculate next step
                        state := calculateNextAddr;
                    end if;
                    
                when calculateNextAddr =>
                    -- Prepare next sample addr
                    -- Attack+Decay+Sustain phase
                    if noteOnOff='1' and releaseFlag='0' then
                        state := waitCmdAck;
                        -- Read request
                        memSamplesSendRqt <= '1';
                        
                        if interpolatedSamplesCntr < sustainEndOffsetAddr then
                            interpolatedSamplesCntr := interpolatedSamplesCntr+1;
                            currentAddr := startAddr + ci(57 downto 32) - 1;-- Just use the integer part
                        else
                            interpolatedSamplesCntr := sustainStartOffsetAddr;
                            currentAddr := startAddr + sustainStepStart(57 downto 32) - 1;-- Just use the integer part
                            ci <= sustainStepStart;
                        end if;
                    
                    -- Release phase
                    else
                        if releaseFlag='1' then
                            if interpolatedSamplesCntr < maxSamples then
                                interpolatedSamplesCntr := interpolatedSamplesCntr+1;
                                currentAddr := startAddr + ci(57 downto 32) - 1;-- Just use the integer part
                                state := waitCmdAck;
                                -- Read request
                                memSamplesSendRqt <= '1';
                            else
                                state := idle;
                            end if;
                        else
                            interpolatedSamplesCntr := unsigned(sustainEndOffsetAddr);
                            currentAddr := startAddr + sustainStepEnd(57 downto 32) - 1;-- Just use the integer part
                            ci <= sustainStepEnd;
                            state := waitCmdAck;
                            releaseFlag :='1';
                            -- Read request
                            memSamplesSendRqt <= '1';
                        end if; --releaseFlag='1'      
                                          
                  end if;--noteOnOff='1'              
                end case;
    end if;--rst_n/rising_edge
  end process;
        
end Behavioral;
