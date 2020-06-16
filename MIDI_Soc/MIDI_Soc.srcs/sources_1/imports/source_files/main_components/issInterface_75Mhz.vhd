---------------------------------------------------------------------
--
--  Fichero:
--    issInterface.vhd  29/7/2015
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Transmite/recibe muestras de sonido por un bus IIS con
--    24 bits, fs=48.8 KHz, fsclk = 64fs y fmclk=256fs
--  
--  Notas de diseño:
--    - Revisi�n aplicacda por Fernando Candelario Herrero para el desarrollo del TFG
--    - Solo válido para 75 MHz de frecuencia de reloj
--    - FUNCIONA !!
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity iisInterface_75Mhz is
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
-- Attributes for debug
--      attribute   dont_touch    :   string;
--      attribute   dont_touch  of  iisInterface_75Mhz  :   entity  is  "true"; 
end iisInterface_75Mhz;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;

architecture syn of iisInterface_75Mhz is

  signal clkCycle : unsigned(4 downto 0);
  signal bitNum   : unsigned(4 downto 0); -- palabras de 32 bits, de esos 32 envio WIDTH 

begin

 
  
  clkGenCounters: 
  process (rst_n, clk)
    variable mclk_cnt : unsigned (1 downto 0);
    variable mclk_TC : std_logic;
    
    variable clkGen_cnt : unsigned (8 downto 0);
    
    variable clkCycle_cnt : unsigned (4 downto 0);
  begin
    
    mclk <= clkGen_cnt(0); -- 12,5 Mhz
    sclk <= clkGen_cnt(2); -- 3,125 Mhz
    lrck <= clkGen_cnt(8); -- 48,8 Khz
    
    leftChannel <= clkGen_cnt(8);
    
    clkCycle <= clkCycle_cnt; -- 24 ciclos por ciclo de sclk
    bitNum <= clkGen_cnt(7 downto 3); -- 32 bits
    
    if mclk_cnt = 2 then
        mclk_TC := '1';
    else
        mclk_TC := '0';  
    end if;
    
    
    if rst_n='0' then 
		mclk_cnt := (others=>'0');
		clkGen_cnt := (others=>'0');
		clkCycle_cnt := (others=>'0'); 
	elsif rising_edge(clk) then
		
		-- mclk counter
		if mclk_cnt < 2 then
		  mclk_cnt := mclk_cnt+1;
		else
          mclk_cnt := (others=>'0');		
		end if;
		
		-- clkGen_cnt counter
		if mclk_TC ='1' then
		  clkGen_cnt := clkGen_cnt+1;
		end if; 
		
		-- clkCycle counter
        if clkCycle_cnt < 23 then
          clkCycle_cnt := clkCycle_cnt+1;
        else
          clkCycle_cnt := (others=>'0');        
        end if;
        	
	end if;
  end process;

  
  ------------- STDI GO TO AUDIO CODEC -----------------

  outSampleRqt <=  '1' when bitNum=0 and clkCycle=23 else '0'; 
                                                              
  outSampleShifter: 
  process (rst_n, clk)
    variable sample: std_logic_vector(23 downto 0);
  begin
	sdti<=sample(23);
	if rst_n='0' then
		sample:=(others=>'0');
	elsif rising_edge(clk) then
		if bitNum=0 and clkCycle=23 then 
		   sample := (others=>'0');
			sample(23 downto 24-WIDTH) := outSample;
		 elsif bitNum > 0 and bitNum < 25 and clkCycle=23 then 
			sample:= sample(22 downto 0) & '0';
		end if;
	end if;
  end process;
  
  ------------- STDOUT COMES FROM AUDIO CODEC ---------------
  
  inSampleRdy <= '1' when bitNum=25 and clkCycle=0 else '0'; 

  inSampleShifter:
  process (rst_n, clk)
    variable sample: std_logic_vector (23 downto 0);
  begin
   inSample<=sample(23 downto 24-WIDTH );
	if rst_n='0' then
		sample:=(others=>'0');
	elsif rising_edge(clk) then
		if bitNum < 25 and bitNum > 0 and clkCycle=12 then -- clkCycle = 12 mitad de la muestra.  
			sample:= sample(22 downto 0 ) & sdto;           
		end if;
	end if;
  end process;
  
end syn;