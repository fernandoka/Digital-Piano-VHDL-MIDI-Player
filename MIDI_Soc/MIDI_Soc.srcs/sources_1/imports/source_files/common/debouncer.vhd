-------------------------------------------------------------------
--
--  Fichero:
--    debouncer.vhd  15/7/2015
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Elimina los rebotes de una línea binaria 
--
--  Notas de diseño:
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity debouncer is
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
-- Attributes for debug
    attribute   dont_touch    :   string;
    attribute   dont_touch  of  debouncer  :   entity  is  "true";    
end debouncer;

-------------------------------------------------------------------

architecture syn of debouncer is
  
begin

  fsmd:
  process (rst_n, clk, x)
    constant TIMEOUT : natural := (BOUNCE*FREQ)-1;
    type states is (waitingKeyDown, keyDownDebouncing, waitingKeyUp, KeyUpDebouncing); 
    variable state : states;
    variable count : natural range 0 to TIMEOUT;
  begin 
    xDeb <= XPOL;
    if state=keyDownDebouncing or state=waitingKeyUp then
      xDeb <= not XPOL;
    end if;
    if rst_n='0' then
      state := waitingKeyDown;
      count := 0;
    elsif rising_edge(clk) then
      if count/=0 then
        count := count-1;
      else
        case state is
          when waitingKeyDown =>
            if x=not XPOL then
              state := keyDownDebouncing;
              count := TIMEOUT; 
            end if;
          when keyDownDebouncing =>
            state := waitingKeyUp;
          when waitingKeyUp =>
            if x=XPOL then
              state := KeyUpDebouncing;
              count := TIMEOUT; 
            end if;
          when KeyUpDebouncing =>
            state := waitingKeyDown;
        end case;
      end if;
    end if;
  end process;  

end syn;
