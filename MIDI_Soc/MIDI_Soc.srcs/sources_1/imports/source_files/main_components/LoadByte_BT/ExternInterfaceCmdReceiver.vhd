----------------------------------------------------------------------------------
-- Company: fdi Universidad Complutense de Madrid, Spain
-- Engineer: Fernando Candelario Herrero
--
-- Revision: 
-- Revision 1.0
-- Additional Comments: 	
--      externKeyboardOnOff is a flag, is mantined by Main Controller compoenent.
--
--      startEndRecive only gets high for one cycle in depression, like a button.
--
--		Command format: cmd(3 downto 0) = velocity
--					 	cmd(11 downto 4) = note code
--                      cmd(12) = when high, note on	
--						cmd(13) = when high, note off
--                      cmd(14) = when high, comes from extern interface, otherwise comes from MidiParser component 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;


entity ExternInterfaceCmdReceiver is
  Generic(  START_ADDR	:	in	natural;
            FREQ        :   in  natural;
            BAUDRATE    :   in  natural;
            FIFO_DEPTH  :   in  natural
  );
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;
    
    -- Common use
	externInterfaceStatus		:	in	std_logic;

	
	-- Ctrl signals for File Reception
    loadMidiFile                :   out std_logic; -- Order a change of state switching to waitLoadMidiFile in MainController component
	finishFileReception			:	out	std_logic;
	memIsFull					:	out	std_logic; -- High when the last load file order fill up all the ddr memory
	
	-- For keyboard CMDs
	sequencerAck                :   in	std_logic;
	aviableCmd                  :   out std_logic;
	keyboardCmd                 :   out std_logic_vector(14 downto 0);
    
    -- Play/stop song
	playSong                    :   out std_logic; -- Order a change of state switching to ReadMidiFile or FinishedSetup in MainController component
	
    -- Enable/disable reverb effect
	reverbOnOff                 :   out std_logic;
	
	-- BT side
	btRxD   					:	in	std_logic;  -- Información recibida desde el Bluethooth, conectada al TxD del chip RN-42 (G16)

	-- Mem side
	memRdWr                     :   in	std_logic; -- Low enables writing in ram memory
	memWrWorking  				:   in  std_logic;
	wrMemCMD	    			:	out	std_logic;
	memCmd	    				:	out	std_logic_vector(41 downto 0)
	
  );
-- Attributes for debug
--	attribute   dont_touch    :   string;
--	attribute   dont_touch  of  ExternInterfaceCmdReceiver  :   entity  is  "true";  
end ExternInterfaceCmdReceiver;

architecture Behavioral of ExternInterfaceCmdReceiver is

  -- For rs232receiver
  signal btDataRx						: std_logic_vector (7 downto 0);
  signal btDataRdyRx, btBusy, btEmpty	: std_logic;
  
  -- For Fifo
  signal rdFifo, emptyFifo, rst_nFifo  :   std_logic;
  signal outFifo                       :   std_logic_vector(7 downto 0);
  
begin	

    btReceiver: rs232receiver
    generic map ( FREQ => FREQ, BAUDRATE => BAUDRATE )
    port map ( rst_n => rst_n, clk => clk, dataRdy => btDataRdyRx, data => btDataRx, RxD => btRxD );


    rst_nFifo <= rst_n and externInterfaceStatus;

-- Buffer to save the note on/off CMDs
  Buffer_In: my_fifo
  generic map(WIDTH =>8, DEPTH =>FIFO_DEPTH)
  port map(
    rst_n   => rst_nFifo,
    clk     => clk,
    wrE     => btDataRdyRx,
    dataIn  => btDataRx,
    rdE     => rdFifo,
    dataOut => outFifo,
    full    => open,
    empty   => emptyFifo
  );


process (rst_n, clk, externInterfaceStatus, memRdWr, emptyFifo, sequencerAck)
    -- Constants
    constant    RECV_FILE_MODE_ON_OFF   :   std_logic_vector(7 downto 0) := X"67";
    constant    ON_OFF_SONG             :   std_logic_vector(7 downto 0) := X"7e";
    constant    REVERB_ON_OFF           :   std_logic_vector(7 downto 0) := X"5F";
    constant    MAX_ADDR                :   unsigned(25 downto 0) := (others=>'1');
    constant    NUM_RECV_BYTES          :   natural :=  2;
    
    type states is ( idle, loadMidi_s0, loadMidi_s1, loadMidi_s2, loadMidi_s3, recvKeyboardCmd, sendCMD); 
    variable state: states;
    
    variable	memAddr	    :	unsigned(25 downto 0);
    variable    timeOut     :   unsigned(26 downto 0); -- Aprox 1.7s at 75Mhz
    
    -- Receive 3 bytes from external device
    variable    dataRecv    :   std_logic_vector(23 downto 0);
    variable    cntr        :   natural range 0 to NUM_RECV_BYTES;
    
    variable    waitOneCycleFlag        :   boolean;
    
begin 
   
   -- Only these recivied bits represents the keyboard CMD 
   keyboardCmd <= '1' & dataRecv(17 downto 8) & dataRecv(3 downto 0);

   -------------------
   -- MOORE OUTPUTS --
   -------------------
   aviableCmd <='0';                 
   if state=sendCMD then
      aviableCmd <='1';
   end if;

  if rst_n='0' then
    state :=idle;
    timeOut := (others=>'1');
    memAddr := (others=>'0');
    cntr := 0;
    waitOneCycleFlag := true;
    dataRecv :=(others=>'0');
    memCmd <=(others=>'0');
    finishFileReception <='0';
    wrMemCMD <='0';
    memIsFull <='0';
    rdFifo <='0';
    playSong <='0';
    loadMidiFile <='0';
    reverbOnOff <='0';
    
  elsif rising_edge(clk) then 
    finishFileReception <='0';
    wrMemCMD <='0';
    rdFifo <='0';
    playSong <='0';
    loadMidiFile <='0';
    reverbOnOff <='0';
    
    if externInterfaceStatus='0' then
        if state/=idle then
            state :=idle;
        end if;
    else      
        case state is
            
            when idle=>
                if waitOneCycleFlag then
                    if emptyFifo='0' then
                        rdFifo <='1';
                        
                        -- If midiParser or keyboard is running, any file can be loaded in memory 
                        if outFifo=RECV_FILE_MODE_ON_OFF then
                            loadMidiFile <='1';
                            state := loadMidi_s0;
                        
                        -- Start/Stop playing song
                        elsif outFifo=ON_OFF_SONG then
                            playSong <='1';
                            waitOneCycleFlag := false;
                        
                        -- Enable/disable reverb effect
                        elsif outFifo=REVERB_ON_OFF then
                            reverbOnOff <='1';                            
                            waitOneCycleFlag := false;
    
                        -- Recive one Keyboard CMD
                        else
                            dataRecv := dataRecv(15 downto 0) & outFifo;
                            waitOneCycleFlag := false;
                            cntr :=1;
                            state := recvKeyboardCmd;             
                        end if;
                    end if;
                    
                else
                    waitOneCycleFlag := not waitOneCycleFlag;
                end if;
                
            ------------------------------
            -- STATES TO LOAD MIDI FILE --
            ------------------------------
          
            -- Waits until KeyboardCntrl and MidiParser are off. 
            -- Furthermore, RamCntrl must be in write mode
            when loadMidi_s0=>
                if memRdWr='0' then
                    waitOneCycleFlag := false;
                    timeOut := (others=>'1');
                    memAddr := to_unsigned(START_ADDR,26);
                    state :=loadMidi_s1;
                end if;
                
            when loadMidi_s1=>
                if waitOneCycleFlag then
                    if emptyFifo='0' then
                        memCmd(7 downto 0) <=  outFifo;
                        rdFifo <='1';
                        waitOneCycleFlag := false;
                        timeOut := (others=>'1');
                        state := loadMidi_s2;
                    -- Will end here if the nº of bytes in the file is an even number (par)
                    elsif timeOut=0 then
                        state := loadMidi_s3;
                    else
                        timeOut := timeOut-1;
                    end if;
                else
                    waitOneCycleFlag := not waitOneCycleFlag;
                end if;
                
            when loadMidi_s2 =>
                if waitOneCycleFlag then
                    if emptyFifo='0' then
                        memCmd(41 downto 8) <=  std_logic_vector(memAddr) & outFifo;
                        rdFifo <='1';
                        wrMemCMD <='1';
                        if memAddr=MAX_ADDR then
                            memIsFull <='1';
                            state := loadMidi_s3;
                        else
                            waitOneCycleFlag := false;
                            memAddr := memAddr+1;
                            timeOut := (others=>'1');
                            state := loadMidi_s1;
                        end if;
                        
                    -- Will end here if the nº of bytes in the file is an odd number (impar)
                    elsif timeOut=0 then
                        memCmd(41 downto 16) <=  std_logic_vector(memAddr); -- In order to write the previously recived byte
                        wrMemCMD <='1';
                        state := loadMidi_s3;
                    else
                        timeOut := timeOut-1;
                    end if;
                    
                else
                    waitOneCycleFlag := not waitOneCycleFlag;
                end if;

                
            when loadMidi_s3=>
                if memWrWorking='0' then
                    finishFileReception <='1';
                    state := idle;
                end if;
                
                
            ----------------------------------
            -- STATES TO RECV KEYBOARD CMDs --
            ----------------------------------
            when recvKeyboardCmd=>
                if waitOneCycleFlag then
                    if emptyFifo='0' then
                        dataRecv := dataRecv(15 downto 0) & outFifo;
                        rdFifo <='1';
                        
                        if cntr < NUM_RECV_BYTES then 
                            waitOneCycleFlag := false;
                            cntr := cntr+1;
                            
                        -- Check if the note code is correct                            
                        elsif (unsigned(dataRecv(15 downto 8)) >= 21 and unsigned(dataRecv(15 downto 8)) <= 108) then
                            state := sendCMD;                        
                        
                        else
                            waitOneCycleFlag := false;                  
                            state := idle;
                        end if;
                    end if;
                    
                else
                  waitOneCycleFlag := not waitOneCycleFlag;                  
                end if;
                
            when sendCMD=>
                if sequencerAck='1' then
                    state :=idle;
                end if;    
                
        end case;
    end if;-- if externKeyboardOnOff='1'
      
  end if;--rst_n/rising_edge
end process;


    
end Behavioral;
