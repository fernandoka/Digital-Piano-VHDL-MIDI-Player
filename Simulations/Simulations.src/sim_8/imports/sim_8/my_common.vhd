----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2019 14:05:12
-- Design Name: 
-- Module Name: my_common - Behavioral
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
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use ieee.numeric_std.all;

package my_common is

  constant YES  : std_logic := '1';
  constant NO   : std_logic := '0';
  constant HI   : std_logic := '1';
  constant LO   : std_logic := '0';
  constant ONE  : std_logic := '1';
  constant ZERO : std_logic := '0';

  -- Calcula el logaritmo en base-2 de un numero.
  function log2(v : in natural) return natural;
  -- Selecciona un entero entre dos.
  function int_select(s : in boolean; a : in integer; b : in integer) return integer;
  -- Convierte un real en un signed en punto fijo con qn bits enteros y qm bits decimales.
  function toFix( d: real; qn : natural; qm : natural ) return signed;
  -- Convierte un real en un unsigned en punto fijo con qn bits enteros y qm bits decimales.
  -- Redondea el número real.
  function toUnFix( d: real; qn : natural; qm : natural ) return unsigned;
  -- Obtiene una dirección multiplo del numero de muestras por periodo, esta dirección se le suma a la dirección de comienzo de la wave table.
  -- FS y Freq tienen que venir dados en Hz.
  -- El offset resta desde la última dirección que sea multiplo del numero de muestras por periodo.
  -- Opera en real, redondea al final.
  function getSustainAddr( WaveSize: natural; FS: real; Freq: real; offset: natural) return natural;
  --Obtiene el Step asociado a un offset  
  function getSustainStep( Freq:real; offset: natural) return real;
  
-- Debouncer for the buttons
  component Dbncr is
    generic (NR_OF_CLKS : integer := 4095);
    port (clk_i : in std_logic;
          sig_i : in std_logic;
          pls_o : out std_logic);
  end component;
  
  -- Syncronizer for swiches, can be used as a debouncer as well
  component my_SwitchSyncronizer is
    Generic(
      WL      : in natural;
      STAGES  : in natural;      -- número de biestables del sincronizador
      INIT    : in std_logic     -- valor inicial de los biestables 
    );
    Port (
        rst_n : in  std_logic;   -- reset asíncrono de entrada (a baja)
        clk   : in  std_logic;   -- reloj del sistema
        x     : in  std_logic_vector(WL-1 downto 0);   -- entrada binaria a sincronizar
        xSync : out std_logic_vector(WL-1 downto 0)    -- salida sincronizada que sique a la entrada
    
     );
  end component;
  
    component synchronizer is
      generic (
        STAGES  : in natural;      -- n?mero de biestables del sincronizador
        INIT    : in std_logic     -- valor inicial de los biestables
      );
      port (
        rst_n : in  std_logic;   -- reset as?ncrono de entrada (a baja)
        clk   : in  std_logic;   -- reloj del sistema
        x     : in  std_logic;   -- entrada binaria a sincronizar
        xSync : out std_logic    -- salida sincronizada que sique a la entrada
      );
  end component;
  
  -- Elimina los rebotes de una línea binaria  
  component debouncer
    generic(
      FREQ   : natural;    -- frecuencia de operacion en KHz
      BOUNCE : natural;    -- tiempo de rebote en ms
      XPOL   : std_logic   -- polaridad de la señal 'x' (valor en inactivo)
    );
    port(
      rst_n : in  std_logic;   -- reset asíncrono del sistema (a baja)
      clk   : in  std_logic;   -- reloj del sistema
      x     : in  std_logic;   -- entrada binaria a la que deben eliminarse los rebotes
      xDeb  : out std_logic    -- salida que sique a la entrada pero sin rebotes
    );
  end component;
    
  -- Detecta flancos en una entrada binaria lenta
  component edgeDetector
    generic(
      XPOL : std_logic   -- polaridad de la señal 'x' (valor en inactivo)
    );
    port (
      rst_n : in  std_logic;   -- reset asíncrono del sistema (a baja)
      clk   : in  std_logic;   -- reloj del sistema
      x     : in  std_logic;   -- entrada binaria con flancos a detectar
      xFall : out std_logic;   -- se activa durante 1 ciclo cada vez que detecta un flanco de subida en x
      xRise : out std_logic    -- se activa durante 1 ciclo cada vez que detecta un flanco de bajada en x
    );
  end component;
  
  
   component ps2Receiver is
    generic (
      REGOUTPUTS : boolean   -- registra o no las salidas
    );
    port (
      -- host side
      rst_n      : in  std_logic;   -- reset as?ncrono del sistema (a baja)
      clk        : in  std_logic;   -- reloj del sistema
      dataRdy    : out std_logic;   -- se activa durante 1 ciclo cada vez que hay un nuevo dato recibido
      data       : out std_logic_vector (7 downto 0);  -- dato recibido
      -- PS2 side
      ps2Clk     : in  std_logic;   -- entrada de reloj del interfaz PS2
      ps2Data    : in  std_logic    -- entrada de datos serie del interfaz PS2
    );
  end component;
  
  component my_fifo is
    generic (
      WIDTH : natural;   -- anchura de la palabra de fifo
      DEPTH : natural    -- numero de palabras en fifo
    );
    port (
      rst_n   : in  std_logic;   -- reset as?ncrono del sistema (a baja)
      clk     : in  std_logic;   -- reloj del sistema
      wrE     : in  std_logic;   -- se activa durante 1 ciclo para escribir un dato en la fifo
      dataIn  : in  std_logic_vector(WIDTH-1 downto 0);   -- dato a escribir
      rdE     : in  std_logic;   -- se activa durante 1 ciclo para leer un dato de la fifo
      dataOut : out std_logic_vector(WIDTH-1 downto 0);   -- dato a leer
      full    : out std_logic;   -- indicador de fifo llena
      empty   : out std_logic    -- indicador de fifo vacia
    );
  end component;
  
 component reducedOr is
    Generic(
          WL  :   natural
    );
    Port (
          a_in                    :   in  std_logic_vector(WL-1 downto 0);
          reducedA_out            :   out std_logic        
     );
  end component;
  
  component MyFiexedSum is
      Generic(
          WL  :   natural
      );
      Port ( 
          rst_n           :   in  std_logic;
          clk             :   in  std_logic;
          
          a_in               :   in  std_logic_vector(WL-1 downto 0);
          b_in               :   in  std_logic_vector(WL-1 downto 0);
          c_out              :   out  std_logic_vector(WL-1 downto 0)
      );
  end component;
  
  
  component bin2segNexsys4 is
    Port ( 
          
          clk : in std_logic;  -- It's expected to be a 100 Mhz clock
           
          -- Right Side
          segRight_n0 : in std_logic_vector(5 downto 0);
          segRight_n1 : in std_logic_vector(5 downto 0);
          segRight_n2 : in std_logic_vector(5 downto 0);
          segRight_n3 : in std_logic_vector(5 downto 0);
  
          -- Left Side
          segLeft_n0 : in std_logic_vector(5 downto 0);
          segLeft_n1 : in std_logic_vector(5 downto 0);
          segLeft_n2 : in std_logic_vector(5 downto 0);
          segLeft_n3 : in std_logic_vector(5 downto 0);
  
          -- Out signals
          disp_seg_o     : out std_logic_vector(7 downto 0);
          disp_an_o      : out std_logic_vector(7 downto 0)
    );
    end component;
  
component iisInterface_75Mhz is
    generic (
        WIDTH : natural   -- anchura de las muestras
    );
    port (
        
        -- host side
        rst_n        : in  std_logic;   -- reset asíncrono del sistema (a baja)
        clk          : in  std_logic;   -- reloj del sistema
        leftChannel  : out std_logic;   -- en alta cuando la muestra corresponde al canal izquiero; a baja cuando es el derecho
        outSample    : in std_logic_vector(WIDTH-1 downto 0);   -- muestra a enviar al AudioCodec
        outSampleRqt : out std_logic;                           -- se activa durante 1 ciclo cada vez que se requiere un nuevo dato a enviar
        inSample     : out std_logic_vector(WIDTH-1 downto 0);  -- muestra recibida del AudioCodec
        inSampleRdy  : out std_logic;                           -- se activa durante 1 ciclo cada vez que hay un nuevo dato recibido
        -- IIS side
        mclk : out std_logic;   -- master clock, 256fs
        sclk : out std_logic;   -- serial bit clocl, 64fs
        lrck : out std_logic;   -- left-right clock, fs
        sdti : out std_logic;   -- datos serie hacia DACs
        sdto : in  std_logic    -- datos serie desde ADCs
    );
end component;


component issInterface_150Mhz is
    generic (
          WIDTH : natural   -- anchura de las muestras
    );
    port (
          
          -- host side
          rst_n        : in  std_logic;   -- reset asíncrono del sistema (a baja)
          clk          : in  std_logic;   -- reloj del sistema
          leftChannel  : out std_logic;   -- en alta cuando la muestra corresponde al canal izquiero; a baja cuando es el derecho
          outSample    : in std_logic_vector(WIDTH-1 downto 0);   -- muestra a enviar al AudioCodec
          outSampleRqt : out std_logic;                           -- se activa durante 1 ciclo cada vez que se requiere un nuevo dato a enviar
          inSample     : out std_logic_vector(WIDTH-1 downto 0);  -- muestra recibida del AudioCodec
          inSampleRdy  : out std_logic;                           -- se activa durante 1 ciclo cada vez que hay un nuevo dato recibido
          -- IIS side
          mclk : out std_logic;   -- master clock, 256fs
          sclk : out std_logic;   -- serial bit clocl, 64fs
          lrck : out std_logic;   -- left-right clock, fs
          sdti : out std_logic;   -- datos serie hacia DACs
          sdto : in  std_logic    -- datos serie desde ADCs
    );
end component;

-- Ram components
component RamCntrl is
   Generic(CACHE_SIZE   :   in  natural); -- Number of rows of the cache
   Port (
      -- Only for Test
      clk                       :   in  std_logic;
      
      statesOut                 :   out std_logic_vector(9 downto 0);
      
      memOut_addr		    :	 out	std_logic_vector(25 downto 0);
      memOut_cen            :    out    std_logic;
      memOut_rd             :    out    std_logic;
      memOut_wr             :    out    std_logic;
      memOut_ack            :    out    std_logic;
      memOut_data_in        :    out    std_logic_vector(15 downto 0);
      memOut_data_out       :    out    std_logic_vector(127 downto 0);

      --
      
      -- Common
      clk_200MHz_i				:	in    std_logic; -- 200 MHz system clock
      rst_n      				:	in    std_logic; -- active low system reset
      ui_clk_o    				:	out   std_logic;

      -- Ram Cntrl Interface
	  rdWr						:	in	std_logic; -- RamCntrl mode, high read low write

	  -- Buffers and signals to manage the read request commands
      inCmdReadBuffer_0     	:	in	std_logic_vector(26 downto 0); -- For midi parser component 
	  wrRqtReadBuffer_0     	:	in	std_logic; 
	  fullCmdReadBuffer_0		:	out	std_logic;
		
	  inCmdReadBuffer_1     	:	in	std_logic_vector(32 downto 0); -- For KeyboardCntrl component
      wrRqtReadBuffer_1			:	in	std_logic;
	  fullCmdReadBuffer_1		:	out	std_logic;
	  
	  -- Buffers and signals to manage the read response commands
	  rdRqtReadBuffer_0			:	in	std_logic;
	  outCmdReadBuffer_0		:	out	std_logic_vector(129 downto 0); -- Cmd response buffer for Midi parser component
	  emptyResponseRdBuffer_0	:	out	std_logic;
	  
	  rdRqtReadBuffer_1			:	in	std_logic;
	  outCmdReadBuffer_1		:	out	std_logic_vector(22 downto 0);	-- Cmd response buffer for KeyboardCntrl component
	  emptyResponseRdBuffer_1	:	out	std_logic;	  

	  -- Buffer and signals to manage the writes commands
	  inCmdWriteBuffer			:	in	std_logic_vector(41 downto 0); -- For setup component and store midi file BL component
	  wrRqtWriteBuffer			:	in	std_logic;
	  fullCmdWriteBuffer		:	out	std_logic;
	  emptyCmdWriteBufferOut    :	out	std_logic;
	  writeWorking				:	out	std_logic -- High when the RamCntrl is executing some write command, low when no writes 
		
      -- DDR2 interface	
--      ddr2_addr            		: 	out   std_logic_vector(12 downto 0);
--      ddr2_ba              		: 	out   std_logic_vector(2 downto 0);
--      ddr2_ras_n           		: 	out   std_logic;
--      ddr2_cas_n           		: 	out   std_logic;
--      ddr2_we_n            		: 	out   std_logic;
--      ddr2_ck_p            		: 	out   std_logic_vector(0 downto 0);
--      ddr2_ck_n            		: 	out   std_logic_vector(0 downto 0);
--      ddr2_cke             		: 	out   std_logic_vector(0 downto 0);
--      ddr2_cs_n            		: 	out   std_logic_vector(0 downto 0);
--      ddr2_odt             		: 	out   std_logic_vector(0 downto 0);
--      ddr2_dq              		: 	inout std_logic_vector(15 downto 0);
--      ddr2_dm              		: 	out   std_logic_vector(1 downto 0);
--      ddr2_dqs_p           		: 	inout std_logic_vector(1 downto 0);
--      ddr2_dqs_n           		: 	inout std_logic_vector(1 downto 0)
   );		
end component;
  
component Ram2Ddr 
   port (
      -- Common
      clk_200MHz_i         : in    std_logic; -- 200 MHz system clock
      rstn_i                : in    std_logic; -- active low system reset
      ui_clk_o             : out   std_logic;
      ui_clk_sync_rst_o    : out   std_logic;

      -- RAM interface
      ram_a                : in    std_logic_vector(25 downto 0); -- Mem addr must be stable in the whole transaction
      ram_dq_i             : in    std_logic_vector(15 downto 0);
      ram_dq_o             : out   std_logic_vector(15 downto 0);
      ram_dq_o_128         : out   std_logic_vector(127 downto 0); -- Read all the 128 bits
      ram_cen              : in    std_logic; -- To start a transaction, active low
      ram_oen              : in    std_logic; -- Read from memory, active low
      ram_wen              : in    std_logic; -- Write in memory, active low
      ram_ack              : out    std_logic;

      
	  -- Debug
	  leds				   : out std_logic_vector(5 downto 0);

      -- DDR2 interface
      ddr2_addr            : out   std_logic_vector(12 downto 0);
      ddr2_ba              : out   std_logic_vector(2 downto 0);
      ddr2_ras_n           : out   std_logic;
      ddr2_cas_n           : out   std_logic;
      ddr2_we_n            : out   std_logic;
      ddr2_ck_p            : out   std_logic_vector(0 downto 0);
      ddr2_ck_n            : out   std_logic_vector(0 downto 0);
      ddr2_cke             : out   std_logic_vector(0 downto 0);
      ddr2_cs_n            : out   std_logic_vector(0 downto 0);
      ddr2_dm              : out   std_logic_vector(1 downto 0);
      ddr2_odt             : out   std_logic_vector(0 downto 0);
      ddr2_dq              : inout std_logic_vector(15 downto 0);
      ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
      ddr2_dqs_n           : inout std_logic_vector(1 downto 0)
   );
end component;



-- IP Core 200 MHz Clock Generator
component ClkGen
  port (-- Clock in ports
        clk_100MHz_i           : in     std_logic;
        -- Clock out ports
        clk_200MHz_o          : out    std_logic;
        -- Status and control signals
        resetn             : in     std_logic;
        locked            : out    std_logic
        );
end component;
  
component fastSpiMaster_Quad is
generic (
  CLKxBIT      : natural  -- numero d ecicloes de reloj por bit transmitido
);
port (
  -- host side
  rst_n    : in  std_logic;   -- reset asíncrono del sistema (a baja)
  clk      : in  std_logic;   -- reloj del sistema
  contMode : in  std_logic;   -- indica si la transferencia se hace de modo continuo (es decir, sin deseleccionar el dispositivo su finalización)
  quadMode : in std_logic;    -- indica si la transferencia a realizar es en modo Quad (high) o no (low).
  dataOutRdy  : in  std_logic;   -- se activa durante 1 ciclo para solicitar la transmisión, activo a alta
  dataIn   : out std_logic_vector (7 downto 0);   -- dato recibido
  dataOut  : in  std_logic_vector (31 downto 0);   -- Se escribe la instruccion y la direccion de inicio ( Inst + Addr )
  dataInRdy_n : out std_logic;   -- Notifica la recepción de cada byte leido, a baja cuando recibe
  busy        : out std_logic; -- Activo a 1 si el dispositivo esta funcionando
  
  -- SPI side
  sck      : out std_logic;   -- reloj serie
  ss_n     : out std_logic;   -- selección de esclavo
  io0      : inout std_logic;   
  io1_in      : in  std_logic;  
  io2_in      : in std_logic;
  io3_in      : in std_logic
);
end component;
  

component fastSpiMaster_Dual is
  generic (
    CLKxBIT      : natural  -- numero d ecicloes de reloj por bit transmitido
  );
  port (
    -- host side
    rst_n    : in  std_logic;   -- reset asíncrono del sistema (a baja)
    clk      : in  std_logic;   -- reloj del sistema
    contMode : in  std_logic;   -- indica si la transferencia se hace de modo continuo (es decir, sin deseleccionar el dispositivo su finalización)
    dualMode : in std_logic;    -- indica si la transferencia a realizar es en modo Quad (high) o no (low).
    dataOutRdy  : in  std_logic;   -- se activa durante 1 ciclo para solicitar la transmisión, activo a alta
    dataIn   : out std_logic_vector (7 downto 0);   -- dato recibido
    dataOut  : in  std_logic_vector (31 downto 0);   -- Se escribe la instruccion y la direccion de inicio ( Inst + Addr )
    dataInRdy_n : out std_logic;   -- Notifica la recepción de cada byte leido, a baja cuando recibe
    busy        : out std_logic; -- Activo a 1 si el dispositivo esta funcionando
    
    -- SPI side
    sck      : out std_logic;   -- reloj serie
    ss_n     : out std_logic;   -- selección de esclavo
    io0      : inout std_logic;   
    io1_in      : in  std_logic
  );
end component;


component MySetup is
  Generic(WL   :   natural
  );
  Port (
      clk   :   in  std_logic;
      rst_n :   in std_logic;
      
      ini   :   in  std_logic;
      fin   :   out std_logic;    
      
      -- Mem
      mem_ack   :   in  std_logic;
      cen   :   out std_logic;
      wr    :   out std_logic;
      setupAddr  :   out std_logic_vector(22 downto 0);
      setupDataOut   :   out std_logic_vector(WL-1 downto 0);
      
      -- SPI signals
      cs_n   : out std_logic;   -- selección de esclavo
      io0    : inout std_logic;    
      io1    : in  std_logic
  );
end component;


component MainController is
  Port (
    clk   :   in  std_logic;
  rst_n :   in std_logic;
  
  -- Debug
  leds  :   out std_logic_vector(3 downto 0); 
  
  memBeginTest    :   in std_logic;
  finSetup    :   in  std_logic;
  iniSetup    :   out std_logic;
  muxControlSignals   : out  std_logic_vector(1 downto 0);
  
  -- Mem
  cen_Mem        :  out std_logic
  
);
end component;


-------------------------
-- KEYBOARD COMPONENTS --
-------------------------
component SimpleNoteGen is
generic (
    WL              :   natural;
    FS              :   real;
    BASE_FREQ       :   real;
    SUSTAIN_OFFSET  :   natural;
    RELEASE_OFFSET  :   natural;
    START_ADDR      :   natural;
    END_ADDR        :   natural
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    interpolateSampleRqt    : in    std_logic; --
    sample_out              : out    std_logic_vector(WL-1 downto 0);
    
    --Mem side
    samples_in              :   in  std_logic_vector(WL-1 downto 0);
    memAck                  :   in  std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
	sample_inRqt			:	out	std_logic	--	A 1 cuando espera una nueva muestra de memoria.
  );
end component;

component InterpolatedNoteGen is
generic (
    FS              :   real;
    TARGET_NOTE     :   real;
    BASE_NOTE       :   real;
    SUSTAIN_OFFSET  :   natural;
    RELEASE_OFFSET  :   natural;
    START_ADDR      :   natural;
    END_ADDR        :   natural
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    interpolateSampleRqt    : in    std_logic;
    sample_out              : out    std_logic_vector(15 downto 0);
        
    --Mem side
    samples_in              :   in  std_logic_vector(15 downto 0);
    memAck                  :   in std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
	sample_inRqt			:	out	std_logic	--	A 1 cuando espera una nueva muestra de memoria.
  );
end component;

component UniversalNoteGen is
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
end component;



component NotesGenerator is
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
        mem_CmdReadResponse    				:   in  std_logic_vector(15+4 downto 0); -- mem_CmdReadResponse(19 downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
        mem_fullReciveBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    		:   out std_logic_vector(25+4 downto 0); -- mem_CmdReadRequest(29 downto 26)= note gen index, mem_CmdReadRequest(15 downto 0) = requested sample
		mem_readResponseBuffer				:	out std_logic;
        mem_writeReciveBuffer     			:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
end component;

component KeyboardCntrl is
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;
        cen             			:   in  std_logic;
		aviableCmd        		    :	in std_logic;	
		cmdKeyboard					:	in std_logic_vector(9 downto 0);
		keyboard_ack				:	out	std_logic;
			
        --IIS side	
        sampleRqt       			:   in  std_logic;
        sampleOut       			:   out std_logic_vector(15 downto 0);
       
       --Debug
       regStartAddr               : out	   std_logic_vector(25 downto 0);  
       regSustainStartOffsetAddr  : out    std_logic_vector(25 downto 0);
       regSustainEndOffsetAddr    : out    std_logic_vector(25 downto 0);
       regMaxSamples              : out    std_logic_vector(25 downto 0);
       regStepVal                 : out    std_logic_vector(63 downto 0);
       regSustainStepStart        : out    std_logic_vector(63 downto 0);
       regSustainStepEnd          : out    std_logic_vector(63 downto 0);
       notesOnOff				  :	out    std_logic_vector(15 downto 0);
       --
       
        		
        -- Mem side
		mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(15+4 downto 0); -- mem_CmdReadResponse(19 downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(25+4 downto 0); -- mem_CmdReadRequest(29 downto 26)= note gen index, mem_CmdReadRequest(25 downto 0) = sample addr
		mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
end component;

---------------------------
-- MIDI PARSE COMPONENTS --
---------------------------

component ByteProvider is
  Port ( 
        rst_n           	:   in  std_logic;
        clk             	:   in  std_logic;
		addrInVal			:	in	std_logic_vector(26 downto 0); -- Byte addres
		byteRqt				:	in	std_logic; -- One cycle high to request a new byte
			
		byteAck				:	out	std_logic; -- One cycle high to notify the reception of a new byte
		nextByte        	:   out	std_logic_vector(7 downto 0);
		
		-- Mem arbitrator side
		samples_in       	:	in	std_logic_vector(127 downto 0);
        memAckSend       	:	in	std_logic; -- One cycle high
		memAckResponse   	:	in	std_logic;
		addr_out         	:	out std_logic_vector(22 downto 0); 
		memSamplesSendRqt	:	out std_logic
		
  ); 
end component;


component ReadVarLength is
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        readRqt			:	in	std_logic; -- One cycle high to request a read
        iniAddr			:	in	std_logic_vector(26 downto 0);
        valOut			:	out	std_logic_vector(63 downto 0);
        dataRdy			:	out std_logic;  -- One cycle high when the data is ready

		--Byte provider side
		nextByte        :   in  std_logic_vector(7 downto 0);
		byteAck			:	in	std_logic; -- One cycle high to notify the reception of a new byte
        byteAddr		:	out std_logic_vector(26 downto 0);
		byteRqt			:	out std_logic -- One cycle high to request a new byte
  ); 
end component;

component MilisecondDivisor is
  Generic(FREQ : in natural);-- Frequency in Khz
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
		cen				:	in	std_logic;
		Tc				:	out std_logic
		
  );
end component;

component MidiParser is
  Port ( 
      rst_n                       :   in  std_logic;
      clk                         :   in  std_logic;

      -- Host
      cen                         :    in    std_logic;
      readMidifileRqt             :    in    std_logic;
      fileOk                      :    out    std_logic;
      OnOff                       :    out    std_logic;
      
      -- Keyboard side
      keyboard_ack                :    in    std_logic; -- Request of a new command
      aviableCmd                  :   out std_logic;    
      cmdKeyboard                 :   out std_logic_vector(9 downto 0);
      
      -- Debug
      statesOut_ODBD              :    out std_logic_vector(2 downto 0);
      
      statesOut_MidiCntrl         :    out    std_logic_vector(4 downto 0);
      
      statesOut_CmdSequencer      :    out    std_logic_vector(1 downto 0);
      
      regAuxHeader                :   out   std_logic_vector(31 downto 0);
      cntrOutHeader               :   out   std_logic_vector(2 downto 0);
      statesOutHeader             :   out   std_logic_vector(7 downto 0);
      
      regAuxOut_0                 :     out std_logic_vector(31 downto 0);
      regAddrOut_0                :     out std_logic_vector(26 downto 0);
      statesOut_0                 :     out std_logic_vector(8 downto 0);
      runningStatusOut_0          :     out std_logic_vector(7 downto 0);  
      dataBytesOut_0              :     out std_logic_vector(15 downto 0);
      regWaitOut_0                :     out std_logic_vector(17 downto 0);
          
      regAuxOut_1                 :     out std_logic_vector(31 downto 0);
      regAddrOut_1                :     out std_logic_vector(26 downto 0);
      statesOut_1                 :     out std_logic_vector(8 downto 0);
      runningStatusOut_1          :     out std_logic_vector(7 downto 0);  
      dataBytesOut_1              :     out std_logic_vector(15 downto 0);
      regWaitOut_1                :     out std_logic_vector(17 downto 0);

      
      -- Mem side
      mem_emptyBuffer               :    in    std_logic;
      mem_CmdReadResponse           :   in  std_logic_vector(129 downto 0);
      mem_fullBuffer                :   in  std_logic; 
      mem_CmdReadRequest            :   out std_logic_vector(26 downto 0); 
      mem_readResponseBuffer        :    out std_logic;
      mem_writeReciveBuffer         :   out std_logic -- One cycle high to send a new CmdReadRqt

);
end component;


component MidiController is
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
end component;

component OneDividedByDivision_Provider is
  Generic(START_ADDR	:	in	natural); -- 32 bits Address of the first value of OneDividedByDivision constants stored in DDR memory 
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		readRqt					:	in	std_logic; -- One cycle high to request a read
		division				:	in	std_logic_vector(15 downto 0);
		readyValue				:	out	std_logic; -- High when the value of the last read it's ready
		OneDividedByDivision	:	out	std_logic_vector(23 downto 0); -- Value of 1/division in Q4.20
		
		--Debug
		statesOut       		:	out std_logic_vector(2 downto 0);
		 
		-- Mem arbitrator side
		dataIn       			:	in	std_logic_vector(23 downto 0); -- Value of 1/division in Q4.20
        memAckSend      		:   in 	std_logic;
		memAckResponse			:	in  std_logic;
		addr_out        		:   out std_logic_vector(24 downto 0); 
		memConstantSendRq		:   out std_logic

  );
end component;


component ReadHeaderChunk is
  Generic(START_ADDR    :   in  natural);
  Port ( 
        rst_n           		:   in  std_logic;
        clk             		:   in  std_logic;
		cen                     :   in 	std_logic;
		readRqt					:	in	std_logic; -- One cycle high to request a read
		finishRead				:	out std_logic; -- One cycle high when the component end to read the header
		headerOk				:	out std_logic; -- High, if the header follow our requirements
		
		-- OneDividedByDivision_Provider side
        ODBD_ReadRqt			:	out	std_logic;
		division				:	out	std_logic_vector(15 downto 0);
		
		-- Start addreses for the Read Trunk Chunk components
		track0AddrStart			:	out std_logic_vector(26 downto 0);
		track1AddrStart			:	out std_logic_vector(26 downto 0);
		
		--Debug
		regAuxOut       		: 	out std_logic_vector(31 downto 0);
		cntrOut         		: 	out std_logic_vector(2 downto 0);
		statesOut       		: 	out std_logic_vector(7 downto 0);
		 
		--Byte provider side
		nextByte        		:   in  std_logic_vector(7 downto 0);
		byteAck					:	in	std_logic; -- One cycle high to notify the reception of a new byte
		byteAddr        		:   out std_logic_vector(26 downto 0);
		byteRqt					:	out std_logic -- One cycle high to request a new byte

  );
end component;

component CmdKeyboardSequencer is
  Port ( 
      rst_n           :   in  std_logic;
      clk             :   in  std_logic;
      
      -- Cmd Inputs
      cmdIn_0            :    in    std_logic_vector(9 downto 0);
      cmdIn_1         :    in    std_logic_vector(9 downto 0);
      sendCmdRqt        :    in    std_logic_vector(1 downto 0); -- High to a add a new command to the buffer
      seq_ack            :    out std_logic_vector(1 downto 0);
      
      
      -- Debug
      statesOut        :    out    std_logic_vector(1 downto 0);
      
      --Keyboard side
      keyboard_ack    :    in    std_logic; -- Request of a new command
      aviableCmd        :    out std_logic;    
      cmdKeyboard        :    out std_logic_vector(9 downto 0)
      
);
end component;



component ReadTrackChunk is
  Port ( 
      rst_n                   :   in  std_logic;
      clk                     :   in  std_logic;
      cen                     :   in     std_logic;
      readRqt                 :    in    std_logic_vector(1 downto 0); -- One cycle high to request a read 
      trackAddrStart          :    in     std_logic_vector(26 downto 0); -- Must be stable for the whole read
      OneDividedByDivision    :    in     std_logic_vector(23 downto 0); -- Q4.20
      finishRead              :    out std_logic; -- One cycle high to notify the end of track reached
      trackOK                 :    out    std_logic; -- High track data is ok, low track data is not ok            
      
      -- CMD Keyboard interface
      sequencerAck            :   in std_logic;
      wrCmdRqt                :   out std_logic;
      cmd                     :    out std_logic_vector(9 downto 0);
              
      --Debug        
      regAuxOut               : out std_logic_vector(31 downto 0);
      regAddrOut              : out std_logic_vector(26 downto 0);
      statesOut               : out std_logic_vector(8 downto 0);
      runningStatusOut        : out std_logic_vector(7 downto 0);  
      dataBytesOut            : out std_logic_vector(15 downto 0);
      regWaitOut              : out std_logic_vector(17 downto 0);
       
      --Byte provider side
      nextByte                :   in  std_logic_vector(7 downto 0);
      byteAck                 :    in    std_logic; -- One cycle high to notify the reception of a new byte
      byteAddr                :   out std_logic_vector(26 downto 0);
      byteRqt                 :    out std_logic -- One cycle high to request a new byte

);
end component;
-- Versiones de testeo

component ChromaticScale is
  Generic(
        NUM_NOTES   :   natural;
		TEMP_VALUE	:	natural
  );
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        cen             :   in  std_logic;
		numNote			:	out std_logic_vector(15 downto 0);
        notes_on		:	out	std_logic_vector(NUM_NOTES-1 downto 0)
  );    
end component;

component NoteGenTest is
generic (
    WL : natural
  );
  port(
    -- Host side
    rst_n                   : in    std_logic;  -- reset asíncrono del sistema (a baja)
    clk                     : in    std_logic;  -- reloj del sistema
    cen_in                  : in    std_logic;   -- Activo a 1
    note_in                 : in    std_logic_vector(7 downto 0);  -- 
    interpolateSampleRqt    : in    std_logic; --
    sample_out              : out    std_logic_vector(WL-1 downto 0);
   
   --Debug    
    leds                    : out std_logic_vector(3 downto 0);
    cntr_o                    : out std_logic_vector(3 downto 0);
    wtinNext                : out    std_logic_vector(WL-1 downto 0);

    --Mem side
    samples_in              :   in  std_logic_vector(WL-1 downto 0);
    memAck                  :   in std_logic;
    addr_out                :   out std_logic_vector(25 downto 0);
    readMem_out             :   out std_logic;
    sampleRqtOut_n          :   out std_logic
  );
end component;

component RomSamplesTest is
port(
	rst_n		: in std_logic;
	clk			: in std_logic;
	addr		: in std_logic_vector(9 downto 0);
	sample 		: out std_logic_vector(15 downto 0);
	sampleRqt	: in std_logic;
	romAck		: out std_logic

 );
end component;

end package my_common;
----------------------------------------------------

package body my_common is
  
    function log2(v : in natural) return natural is
      variable n    : natural;
      variable logn : natural;
    begin
      n := 1;
      for i in 0 to 128 loop
        logn := i;
        exit when (n >= v);
        n := n * 2;
      end loop;
      return logn;
    end function log2;
  
    function int_select(s : in boolean; a : in integer; b : in integer) return integer is
    begin
      if s then
        return a;
      else
        return b;
      end if;
      return a;
    end function int_select;
  
    function toFix( d: real; qn : natural; qm : natural ) return signed is
    begin
      return to_signed( integer(d*(2.0**qm)), qn+qm );
    end function;
    
        function toUnFix( d: real; qn : natural; qm : natural ) return unsigned is
    begin
           --to_unsigned( integer( (d*(2.0**qm))+0.5 ), qn+qm );
    return to_unsigned( integer(16319045),qn+qm);--decimal value of 466.164/440, just for test to_unsigned( integer( (d*(2.0**qm))+0.5 ), qn+qm );
    end function;
    
    function getSustainAddr( WaveSize: natural; FS: real; Freq: real; offset: natural) return natural is
        variable    samplesPerPeriod    :   real;
        variable    totalNumPeriods     :   real;
    begin
        samplesPerPeriod    := FS/Freq;
        totalNumPeriods     := real(WaveSize)/samplesPerPeriod;
        
      return integer( ((totalNumPeriods-real(offset))*samplesPerPeriod)+0.5 ) - 1;
    end function;
    
    function getSustainStep( Freq:real; offset: natural) return real is
    begin
        return Freq*real(offset);
    end function;
    
end package body my_common;