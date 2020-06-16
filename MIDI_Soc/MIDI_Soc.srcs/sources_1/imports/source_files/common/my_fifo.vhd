-------------------------------------------------------------------
--
--  Fichero:
--    fifo.vhd  1/10/2015
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Buffer de tipo FIFO
--
--  Notas de diseño:
--    - Está implementada como un banco de registros
--    - Si la FIFO está llena, los nuevos datos que se intenten 
--      almacenar se ignoran
--    - Si la FIFO está vacía, las lecturas devuelven valores no
--      validos
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity my_fifo is
  generic (
    WIDTH : natural;   -- anchura de la palabra de fifo
    DEPTH : natural    -- numero de palabras en fifo
  );
  port (
    rst_n   : in  std_logic;   -- reset asíncrono del sistema (a baja)
    clk     : in  std_logic;   -- reloj del sistema
    wrE     : in  std_logic;   -- se activa durante 1 ciclo para escribir un dato en la fifo
    dataIn  : in  std_logic_vector(WIDTH-1 downto 0);   -- dato a escribir
    rdE     : in  std_logic;   -- se activa durante 1 ciclo para leer un dato de la fifo
    dataOut : out std_logic_vector(WIDTH-1 downto 0);   -- dato a leer
    full    : out std_logic;   -- indicador de fifo llena
    empty   : out std_logic    -- indicador de fifo vacia
  );
-- Attributes for debug
--  attribute   dont_touch    :   string;
--  attribute   dont_touch  of  my_fifo  :   entity  is  "true";
end my_fifo;

-------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.my_common.all;

architecture syn of my_fifo is

  constant maxValue : natural := DEPTH-1;

  type   regFileType is array (0 to maxValue) of std_logic_vector(WIDTH-1 downto 0);

  -- Registros
  signal regFile : regFileType;
  signal wrPointer, rdPointer : natural range 0 to maxValue;
  signal isFull : std_logic;
  signal isEmpty : std_logic;
  -- Señales  
  signal nextWrPointer, nextRdPointer : natural range 0 to maxValue;
  signal rdFifo  : std_logic;
  signal wrFifo : std_logic;
  
begin

  registerFile :
  process (rst_n, clk, rdPointer, regFile)
  begin
    dataOut <= regFile(rdPointer);
    if rst_n='0' then
      regFile <= (others => (others => '0'));
    elsif rising_edge(clk) then
      if wrFifo='1' then 
        regFile(wrPointer)<=dataIn;
      end if;
    end if;
  end process;
 
  wrFifo <= wrE and not isFull;
  rdFifo <= rdE and not isEmpty;
  
  nextWrPointer <= wrPointer + 1 when wrPointer<maxValue else 0;
  nextRdPointer <= rdPointer + 1 when rdPointer<maxValue else 0;


  fsmd :
  process (rst_n, clk) 
  begin     
    if rst_n='0' then
      wrPointer <= 0;
      rdPointer <= 0;
      isFull    <= '0';
      isEmpty   <= '1';
    elsif rising_edge(clk) then
      if wrFifo='1' then
        isEmpty <= '0';
		  wrPointer <= nextWrPointer;
		 if nextWrPointer=rdPointer and rdFifo='0' then 
			isFull <= '1'; 
		 end if;
      end if;
      if rdFifo='1' then
        isFull <= '0';
		  rdPointer <= nextRdPointer;
		if nextRdPointer = wrPointer and wrFifo='0' then 
			isEmpty<= '1'; 
		end if;
      end if;
    end if;
  end process;
  
	full  <= isFull;
	empty <= isEmpty;
	
end syn;
