-------------------------------------------------------------------
--
--  Fichero:
--    synchronizer.vhd  12/7/2013
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Sincroniza una entrada binaria
--
--  Notas de diseño:
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity synchronizer is
  generic (
    STAGES  : in natural;      -- número de biestables del sincronizador
    INIT    : in std_logic     -- valor inicial de los biestables 
  );
  port (
    rst_n : in  std_logic;   -- reset asíncrono de entrada (a baja)
    clk   : in  std_logic;   -- reloj del sistema
    x     : in  std_logic;   -- entrada binaria a sincronizar
    xSync : out std_logic    -- salida sincronizada que sique a la entrada
  );
-- Attributes for debug
--  attribute   dont_touch    :   string;
--  attribute   dont_touch  of  synchronizer  :   entity  is  "true";  
end synchronizer;

-------------------------------------------------------------------

architecture syn of synchronizer is 
begin

  process (rst_n, clk)
    variable aux : std_logic_vector(STAGES-1 downto 0); 
  begin
    xSync <= aux(STAGES-1);		
    if rst_n='0' then
      aux := (others => INIT);
    elsif rising_edge(clk) then
      for i in STAGES-1 downto 1 loop
        aux(i) := aux(i-1);
      end loop;
      aux(0) := x;
    end if;
  end process;

end syn;
