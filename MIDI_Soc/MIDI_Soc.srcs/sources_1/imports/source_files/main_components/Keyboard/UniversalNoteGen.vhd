----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 1.1
-- Additional Comments: 
--		These signals follow a Q32.32 fix format:	stepVal_In					
--      											sustainStepStart_In	
--      											sustainStepEnd_In	
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;


entity UniversalNoteGen is
  port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;  
    noteOnOff               	:	in	std_logic; -- On high, Off low
    sampleRqt    				:	in	std_logic;
	working						:	out	std_logic;
    sample_out              	:	out	std_logic_vector(23 downto 0);

	-- NoteParams
	startAddr_In				:	in	std_logic_vector(25 downto 0);
	sustainStartOffsetAddr_In	:	in	std_logic_vector(25 downto 0);
	sustainEndOffsetAddr_In    	:	in	std_logic_vector(25 downto 0);
	stepVal_In					:	in	std_logic_vector(63 downto 0);  -- If is a simple note, stepVal_In=1.0 
	noteVelocity                :   in  std_logic_vector(3 downto 0);
	
    -- Mem side
    samples_in              	:   in  std_logic_vector(15 downto 0);
    memAckSend                 	:   in 	std_logic;
    memAckResponse				:	in  std_logic;
	addr_out                	:   out std_logic_vector(25 downto 0);
    memSamplesSendRqt           :   out std_logic
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  UniversalNoteGen  :   entity  is  "true";  
end UniversalNoteGen;

architecture Behavioral of UniversalNoteGen is
---------------------------	CONSTANTS --------------------------------------
	constant    VALUE_TO_ROUND      :   signed(50 downto 0) := "000" & X"000200000000";-- 1 in bit 33

    constant    VALUE_TO_ROUND_SUSTAIN     :   signed(29 downto 0) := "00" & X"0000400"; -- 1 in bit 10, sign extended
    constant    OFFSET_CNT_VAL             :   signed(11 downto 0) := X"400"; -- Q2.10, these bits represents 1.0

    constant    VALUE_TO_ROUND_RELEASE     :   signed(26 downto 0) := "000" & X"000010"; -- 1 in bit 4, sign extended
    constant    RELEASE_CNT_VAL            :   signed(6 downto 0) := "010" & X"0"; -- Q2.5, these bits represents 1.0
    
	constant    MAX_POS_VAL  :   signed(15 downto 0) := X"7FFF";
	constant    MAX_NEG_VAL  :   signed(15 downto 0) := X"8000";
	
---------------------------	SIGNALS	----------------------------------------
	-- Registers
	
	signal finalVal, truncateAndSaturVal          :   signed(23 downto 0); -- 16 bits
	
	-- Interpolation
	signal wtinI,wtinIPlus1                       : signed(15 downto 0);
    signal subVal                                 :   signed(16 downto 0); -- 17 bits
	signal mulVal                                 :   signed(49 downto 0); -- 50 bits
    
    signal roundVal                               :   signed(50 downto 0); -- 51 bits
    signal addVal                                 :   signed(16 downto 0);
	
	signal decimalPart                            :   signed(32 downto 0); -- 33 bits, msb de signo
	signal ci                                     :   unsigned(63 downto 0); -- 64 bits	

    -- Sustain phase
	signal valueForSustainLoop                    :   signed(11 downto 0); --12 bits, msb de signo, Q2.10
    signal mulValSustain                          :   signed(28 downto 0); -- 29 bits Q3.26
    signal roundValOffset                         :   signed(29 downto 0); -- 30 bits Q4.26

    -- Release phase
    signal valueForReleaseDecay                   :   signed(6 downto 0); -- 7 bits, msb de signo, aprox 2.6ms of release phase at 48800Khz (mono) 
    signal mulValRelease                          :   signed(25 downto 0); -- 26 bits Q6.20
    signal roundValRelease                        :   signed(26 downto 0); -- 27 bits Q7.20

    -- Velocity
    signal  velocityParam                         :   std_logic_vector(3 downto 0);

begin	

    decimalPart <= signed("0" & ci(31 downto 0));
	
TruncateAndSatur:    
        truncateAndSaturVal <= X"0" & MAX_POS_VAL & X"0" when roundValRelease(26 downto 5) > MAX_POS_VAL else
                               X"F" & MAX_NEG_VAL & X"F" when roundValRelease(26 downto 5) < MAX_NEG_VAL else
                               roundValRelease(20) & roundValRelease(20) & roundValRelease(20) & roundValRelease(20) & 
                               roundValRelease(20 downto 5) & 
                               roundValRelease(20) & roundValRelease(20) & roundValRelease(20) & roundValRelease(20);


VelocityMul:    -- Very High intensity, 4.0
    finalVal <= truncateAndSaturVal(23) & truncateAndSaturVal(23) & 
                truncateAndSaturVal(19 downto 4) & 
                truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) when velocityParam="1000" else 
                
                -- High intensity, 2.0
                truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & 
                truncateAndSaturVal(19 downto 4) & 
                truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) when velocityParam="0100" else
                
                -- Low intensity, 0.5
                truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & 
                truncateAndSaturVal(19 downto 4) & 
                truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) when velocityParam="0010" else
                
                -- Very low intensity, 0.25
                truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & truncateAndSaturVal(23) & 
                truncateAndSaturVal(19 downto 4) & 
                truncateAndSaturVal(23) & truncateAndSaturVal(23) when velocityParam="0001" else 
                
                -- Normal intensity, 1.0
                truncateAndSaturVal;

	

	filterRegisters :
  process (rst_n, clk, memAckSend, memAckResponse, noteOnOff, sampleRqt)
      type states is (idle, waitCmdAck ,getSample0, getSample1, interpolate, calculateNextAddr); 
      variable state: states;
      variable interpolatedSamplesCntr : unsigned(25 downto 0);
      variable cntr : natural range 0 to 1;
      variable currentAddr : unsigned(25 downto 0);
      variable wtout : signed(23 downto 0);
	  variable noteOnOffFlag   :   boolean;
	  
	  -- NoteParams registers
	  variable	startAddr				:	unsigned(25 downto 0);
	  variable  sustainStartOffsetAddr  :	unsigned(25 downto 0);
	  variable  sustainEndOffsetAddr    :	unsigned(25 downto 0);
	  variable  stepVal				    :	unsigned(63 downto 0);
	  variable	sustainStepStart        :	unsigned(63 downto 0);
        
 begin          		
                	
    addr_out <= std_logic_vector(currentAddr);
    sample_out <= std_logic_vector(wtout);
	
	if rst_n='0' then
        state := idle;
        cntr := 0;
        interpolatedSamplesCntr := (others=>'0');
        currentAddr :=(others=>'0');
        wtout := (others=>'0');
        noteOnOffFlag :=false;
        wtinIPlus1 <= (others=>'0');
        wtinI <= (others=>'0');
		ci <=(others=>'0');
        valueForSustainLoop <=(others=>'0');
        valueForReleaseDecay <=(others=>'0');
        working <='0';
        memSamplesSendRqt <= '0';
        
	elsif rising_edge(clk) then
	    ---------------------------
        -- PIPELINED OPERTATIONS --
        ---------------------------  
        -- Interpolation
        -- wtout[j] = wtint[j] + getDecimalPart(ci)*(wtint[j+1]-wtint[j])
        subVal <= (wtinIPlus1(15) & wtinIPlus1) - (wtinI(15) & wtinI); -- Q17.0 = Q16.0-Q16.0
    
        mulVal <= decimalPart*subVal; -- Q50.0 = Q33.0*Q17.0
    
        roundVal <= (mulVal(49) & mulVal) + VALUE_TO_ROUND; --Q51.0 = Q50.0+Q50.0
    
        addVal <= roundVal(50 downto 34) + (wtinI(15) & wtinI); --Q17.0 = Q16.0+Q16.0
        
        -- Apply Sustain Offset const    
        mulValSustain <= valueForSustainLoop*addVal; -- Q3.26 = Q2.10*Q1.16
        
        roundValOffset <= (mulValSustain(28) & mulValSustain) + VALUE_TO_ROUND_SUSTAIN; --Q4.26 = Q3.26+Q3.26 
        
        -- Apply Release decay const
        mulValRelease <= roundValOffset(29 downto 11)*valueForReleaseDecay;  -- Q6.20 = Q4.15*Q2.5
        
        roundValRelease <= (mulValRelease(25) & mulValRelease) +  VALUE_TO_ROUND_RELEASE; -- Q7.20 = Q6.20+Q6.20

            case state is
                    
                when idle =>
                    if noteOnOff='1' and not noteOnOffFlag then
                        noteOnOffFlag := not noteOnOffFlag;
                    end if;
                    
                    if noteOnOffFlag then
                        cntr := 0;
                        wtout := (others=>'0');
                        interpolatedSamplesCntr := (others=>'0');
						
						-- NoteParams assignement
						currentAddr 			:= unsigned(startAddr_In);
						startAddr               := unsigned(startAddr_In); -- Used in sustain part
						sustainStartOffsetAddr	:= unsigned(sustainStartOffsetAddr_In);			
						sustainEndOffsetAddr    := unsigned(sustainEndOffsetAddr_In);   	
						stepVal				    := unsigned(stepVal_In);					
                        velocityParam           <= noteVelocity;

						state := waitCmdAck;
						
                        ci <=(others=>'0');
                        valueForSustainLoop <= OFFSET_CNT_VAL;
                        valueForReleaseDecay <= RELEASE_CNT_VAL;
                        memSamplesSendRqt <= '1';
                        working <='1';
                    end if;

				when waitCmdAck=>
					if memAckSend='1' then
                       memSamplesSendRqt <= '0';
                       state := getSample0;
					end if;
            
                -- Recive samples
                when getSample0 =>                    
                    if memAckResponse='1' then 
                        wtinI <= signed(samples_in);
                        state := getSample1;
                    end if;            
            
                when getSample1 =>
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
                        if interpolatedSamplesCntr = sustainStartOffsetAddr then
                            sustainStepStart := ci;
                        end if;
                        ci	  <= ci + stepVal; -- Calculate next step
                        state := calculateNextAddr;
                    end if;
                    
                when calculateNextAddr =>
                    if noteOnOff='0' and noteOnOffFlag then
                        noteOnOffFlag := not noteOnOffFlag;
                    end if;
                    
                    
                    -- Prepare next sample addr
                    -- Attack+Decay+Sustain+Release phase
                    -- In sustain/release phase, use of a constant to reduce the amplitud of the sound
                    if noteOnOffFlag or (not noteOnOffFlag and valueForReleaseDecay/=0) then
                        state := getSample0;
                        -- Order read rqt
                        memSamplesSendRqt <= '1';
                        
                        if interpolatedSamplesCntr < sustainEndOffsetAddr then
                            interpolatedSamplesCntr := interpolatedSamplesCntr+1;
                            currentAddr := startAddr + ci(57 downto 32) - 1;-- Just use the integer part
                            
							-- For evolution of release const
							if not noteOnOffFlag and valueForReleaseDecay > 0 then
								valueForReleaseDecay <=valueForReleaseDecay-1;
							end if;
						
                        else
                            interpolatedSamplesCntr := sustainStartOffsetAddr;
                            currentAddr := startAddr + sustainStepStart(57 downto 32) - 1;-- Just use the integer part
                            -- For evolution of sustain const
                            if noteOnOffFlag then
                                if valueForSustainLoop > 0 then
                                    valueForSustainLoop <=valueForSustainLoop-1;
                                end if;
                            -- For evolution of release const
                            else
                                if valueForReleaseDecay > 0 then
                                    valueForReleaseDecay <=valueForReleaseDecay-1;
                                end if;
                            end if;
                            ci <= sustainStepStart;
                        end if;
                    
                    -- Release phase
                    else
                        working <='0';
                        state := idle;      
                  end if;--onOffFlag='1'
                                
                end case;
    end if;--rst_n/rising_edge
  end process;
        
end Behavioral;
