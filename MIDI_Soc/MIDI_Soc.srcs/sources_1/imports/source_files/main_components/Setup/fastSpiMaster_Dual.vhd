-------------------------------------------------------------------
--
--  Fichero:
--    sioMaster.vhd  13/12/2017
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
-- 
--  Retocado por Fernando Candelario para el desarrollo del TFG
--  Versión: 0.9
--
--  Notas de diseño:
--      Esta hecho solo para que lea
--      Fase de reloj establecida a 1, vuelca en flancos impares y muestrea en pares.
--      Nº de dummyCycles = 8
--  
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;

entity fastSpiMaster_Dual is
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
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  fastSpiMaster_Dual  :   entity  is  "true";  
end fastSpiMaster_Dual;

-------------------------------------------------------------------

architecture syn of fastSpiMaster_Dual is
    
    
  -- Constantes
  constant CPOL : std_logic := '1'; -- polaridad del reloj (valor en inactivo)
  constant CPHA : std_logic := '1';   -- fase del reloj: 1 = vuelca en flancos impares (1,3,7...) y muestrea en pares (2,4,6...), 0 = vuelca en pares y muestrea en impares
  constant DUMMY_CYCLES : natural := 8;
  
  -- Registros
  signal io0Shf_out : std_logic_vector (31 downto 0);
  signal bitPos : natural range 0 to 31;
     
  signal sendFlag : std_logic;
  signal dualModeFlag : std_logic;
  
  signal io0Shf_in: std_logic_vector(3 downto 0);
  signal io1Shf_in : std_logic_vector (7 downto 0);
  
  -- Señales
  signal io0_in : std_logic;
  
begin


  io0 <= io0Shf_out(31) when sendFlag='1' else 'Z';
  io0_in <= io0 when sendFlag='0' else 'Z';
  
  dataIn <= io1Shf_in when dualModeFlag='0' else 
            io1Shf_in(3) & io0Shf_in(3) & io1Shf_in(2) & io0Shf_in(2) &
            io1Shf_in(1) & io0Shf_in(1) & io1Shf_in(0) & io0Shf_in(0);


  fsmd :
  process (rst_n, clk, dataOutRdy)
    constant HALFSCK_CYCLES : natural := CLKxBIT/2-1; 
    type state_t is (waiting, selection, firstHalfWR, secondHalfWR, firstDummyHalf, secondDummyHalf,
                    firstHalfRD, secondHalfRD, unselection); 
    type fsmt_state is record
        state   :   state_t;
        count   :   natural range 0 to HALFSCK_CYCLES;
    end record;
    variable state  :   fsmt_state;
    variable stateToEnd  :   state_t;
  begin

    busy <='1';
    
    if state.state=waiting then
      busy <= '0';
    end if;
    
    
    
    if rst_n='0' then
      sck     <= CPOL;  -- se registra para evitar posibles glitches
      ss_n    <= '1';   -- idem
      io1Shf_in <=  (others => '1');
      io0Shf_in <=  (others => '1');
      io0Shf_out <= (others => '1');
      sendFlag <= '1'; -- Este quizas no es necesario
      dualModeFlag <='0'; -- Por  the defecto no esta en quad mode
      bitPos  <= 0;
      state   := (waiting,0);

    elsif rising_edge(clk) then

      dataInRdy_n <='1'; -- Se asegura que solo dure un ciclo
      
      
      if state.count/=0 then
        state.count := state.count-1;
      else 
          case state.state is
            
            -- Espera solicitud de transmisión
            when waiting =>
              sck  <= CPOL;
              ss_n <= '1';
              if dataOutRdy='1' then
                io0Shf_in <=  (others => '1');
                io1Shf_in <= (others => '1');
                sendFlag <= '1';       
                io0Shf_out <= dataOut;
                dualModeFlag <= dualMode;
                state.state   := selection;
              end if;
              
            -- Selecciona esclavo
            when selection =>
              sck  <= CPOL;
              ss_n <= '0';
              bitPos <= 0;
              state  := (firstHalfWR,HALFSCK_CYCLES);
              
            -- Genera flanco impar, como quiero escribir desplazo excepto si bitPos=0.            
            when firstHalfWR =>                           
              sck  <= not CPOL;
              ss_n <= '0';
              state := (secondHalfWR,HALFSCK_CYCLES);
              if bitPos/=0 then
                  io0Shf_out <= io0Shf_out(30 downto 0) & '1';
              end if;

              
            
            -- Genera flanco par, si ya he escrito los 32 bits ( Inst + Addr ) y quad mode esta a 1, salto al estado de ciclos dummy 
            -- poniendo a bitPos a 0 para el siguiente ciclo, si no desplazo   
            when secondHalfWR =>                          
              sck  <= CPOL;
              ss_n <= '0';
              state.count := HALFSCK_CYCLES;
                if bitPos=31 then
                    bitPos <= 0;
                    stateToEnd := firstHalfRD; -- Por defecto empieza en continuo
                    if dualModeFlag='1' then
                        state.state := firstDummyHalf;
                    else
                        state.state := firstHalfRD;
                    end if;
                else
                  bitPos <= bitPos + 1;
                  state.state  := firstHalfWR;
                end if;
                
            
            -- Espero 8 ciclos dummy, para ello uso bit pos contando los flancos de subida, es como si recibiera 1 Byte 
            when firstDummyHalf =>  
                sck  <= not CPOL;
                ss_n <= '0';
                state := (secondDummyHalf,HALFSCK_CYCLES);
              
            when secondDummyHalf =>
                sck  <=  CPOL;
                ss_n <= '0';
                state.count := HALFSCK_CYCLES;
                if bitPos = DUMMY_CYCLES-1 then
                  state.state := firstHalfRD;
                  sendFlag <= '0'; -- Para el triestado     
                  bitPos <= 0;
                else
                    bitPos <= bitPos+1;
                    state.state := firstDummyHalf;
                end if;
    
            -- Genera flanco impar, no hago nada            
            when firstHalfRD =>                           
              sck  <= not CPOL;
              ss_n <= '0';
              state := (secondHalfRD,HALFSCK_CYCLES);
          
            
            -- Genera flanco par, como solo quiero leer no escribo,
            -- como leo de 4 en 4, cuento hasta bitPos = 1, si contMode = 1
            -- continuo leyendo de forma continua, si no paso al estado de deseleccion de esclavo.
            -- En cuanto contMode este a un ciclo a baja, sera la lectura actual sera la ultima a realizar   
            when secondHalfRD =>                          
              sck  <= CPOL;
              ss_n <= '0';
              state.count := HALFSCK_CYCLES;
                         
              if contMode = '0' then
                stateToEnd := unselection;
              end if;
              
              if dualModeFlag='1' then 
                  io0Shf_in <= io0Shf_in(2 downto 0) & io0_in;
                  io1Shf_in(3 downto 0) <= io1Shf_in(2 downto 0) & io1_in;      
                  if bitPos=3 then
                      dataInRdy_n <= '0';
                  end if;
                  
              else
                  io1Shf_in <= io1Shf_in(6 downto 0) & io1_in;
                  
                  if bitPos=7 then
                      dataInRdy_n <= '0';
                  end if;
                                  
              end if;
              
              
              if (dualModeFlag='1' and bitPos=3) or (dualModeFlag='0' and bitPos=7) then
                  bitPos <= 0;
                  state.state := stateToEnd;
              else
                  bitPos <= bitPos + 1;
                  state.state  := firstHalfRD;
              end if;
          
          
            -- Deselecciona esclavo             
            when unselection =>                         
              sck  <= CPOL;
              ss_n <= '1';
              state := (waiting,0);
              
            end case;
            
        end if; -- count
    end if; -- rst/rising_edge()

  end process;
   
end syn;
