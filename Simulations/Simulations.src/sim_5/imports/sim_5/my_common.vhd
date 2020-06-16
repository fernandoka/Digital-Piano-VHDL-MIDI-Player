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
  
component Ram2Ddr 
   port (
      -- Common
      clk_200MHz_i         : in    std_logic; -- 200 MHz system clock
      rstn_i                : in    std_logic; -- active low system reset
      ui_clk_o             : out   std_logic;
      ui_clk_sync_rst_o    : out   std_logic;

      -- RAM interface
      ram_a                : in    std_logic_vector(25 downto 0);
      ram_dq_i             : in    std_logic_vector(15 downto 0);
      ram_dq_o             : out   std_logic_vector(15 downto 0);
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


  component spiMaster_Quad is
  generic (
    FREQ      : natural;    -- frecuencia de operacion en KHz
    BAUDRATE  : natural    -- velocidad de comunicacion
  );
  port (
    -- host side
    rst_n    : in  std_logic;   -- reset asíncrono del sistema (a baja)
    clk      : in  std_logic;   -- reloj del sistema
    contMode : in  std_logic;   -- indica si la transferencia se hace de modo continuo (es decir, sin deseleccionar el dispositivo su finalización)
    quadMode : in std_logic;    -- indica si la transferencia a realizar es en modo Quad (high) o no (low).    
    dataOutRdy  : in  std_logic;   -- se activa durante 1 ciclo para solicitar la transmisión
    dataIn   : out std_logic_vector (7 downto 0);   -- dato recibido
    dataOut  : in  std_logic_vector (31 downto 0);   -- Se escribe la instruccion y la direccion de inicio ( Inst + Addr )
    dataInRdy_n : out std_logic;   -- Notifica la recepción de cada byte leido
    busy        : out std_logic; -- Activo a 1 si el dispositivo esta funcionando

    -- SPI side
    sck      : out std_logic;   -- reloj serie
    ss_n     : out std_logic;   -- selección de esclavo
    io0      : inout std_logic;   
    io1_in      : in  std_logic; -- Solo leo  
    io2_in      : in std_logic; -- Solo leo
    io3_in      : in std_logic -- Solo leo  
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

component NotesGenerator is
  Generic(
        WL  :   natural;
        NUM_NOTES   :   natural
  );
  Port ( 
        rst_n           :   in  std_logic;
        clk             :   in  std_logic;
        cen             :   in  std_logic;
        notes_on        :   in  std_logic_vector(NUM_NOTES-1 downto 0);
        
        --IIS side
        sampleRqt       :   in  std_logic;
        sampleOut       :   out std_logic_vector(WL-1 downto 0);
        
        
        -- Mem side
        mem_sampleIn    :   in  std_logic_vector(WL-1 downto 0);
        mem_ack         :   in  std_logic;
        mem_addrOut     :   out std_logic_vector(25 downto 0);
        mem_readOut     :   out std_logic
  
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
      return to_unsigned( integer(16319045),qn+qm);--decimal value of 466.164/440, just for test
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