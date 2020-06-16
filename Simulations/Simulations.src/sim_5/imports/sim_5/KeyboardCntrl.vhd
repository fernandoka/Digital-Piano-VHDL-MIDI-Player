----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: KeyboardCntrl - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.4
-- Additional Comments:
--		Keyboard Command format: cmd(7 downto 0) = note code
--					 	cmd(9) = when high, note on	
--						cmd(8) = when high, note off
--						Null command when -> cmd(9 downto 0) = (others=>'0')
-- 
--		Mem Read Request command format: cmd(29 downto 26)=note gen index 
--										 cmd(25 downto 0)=sample addr
--
--		Mem Read Response command format: cmd(15+4 downto 16)=note gen index 
--										 cmd(15 downto 0)=sample 
--
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity KeyboardCntrl is
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;
        cen             			:   in  std_logic;
		emtyCmdKeyboardBuffer		:	in std_logic;	
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
-- Attributes for debug
--attribute   dont_touch    :   string;
--attribute   dont_touch  of  KeyboardCntrl  :   entity  is  "true";
    
end KeyboardCntrl;

use work.my_common.all;

architecture Behavioral of KeyboardCntrl is
----------------------------------------------------------------------------------
-- TYPES DECLARATIONS
----------------------------------------------------------------------------------     
	type	maxInterpolatedSamplesPerNote_t is array(0 to 57) of natural;
	type	offset_t is array(0 to 87) of natural;
	
----------------------------------------------------------------------------------
-- CONSTANTS DECLARATIONS
----------------------------------------------------------------------------------         
    constant    SAMPLES_PER_WAVETABLE   :   natural :=  189644;
    constant    FS                      :   real    :=  48800.0; -- frecuencia de muestreo, Hz

   constant    MAX_INTERPOLATED_SAMPLES_PER_NOTE :   maxInterpolatedSamplesPerNote_t :=(
		  0=>integer( (real(SAMPLES_PER_WAVETABLE)/(29.1353/27.5))+0.5 ), 1=>integer( (real(SAMPLES_PER_WAVETABLE)/(30.8677/27.5))+0.5 ), -- A#0, B0 
		  
		  2=>integer( (real(SAMPLES_PER_WAVETABLE)/(34.6479/32.7032))+0.5 ), 3=>integer( (real(SAMPLES_PER_WAVETABLE)/(36.7081/32.7032))+0.5 ), -- C#1, D1
		  4=>integer( (real(SAMPLES_PER_WAVETABLE)/(41.2035/38.8909))+0.5 ), 5=>integer( (real(SAMPLES_PER_WAVETABLE)/(43.6536/38.8909))+0.5 ), -- E1, F1
		  6=>integer( (real(SAMPLES_PER_WAVETABLE)/(48.9995/46.2493))+0.5 ), 7=>integer( (real(SAMPLES_PER_WAVETABLE)/(51.9130/46.2493))+0.5 ), -- G1, G#1
		  8=>integer( (real(SAMPLES_PER_WAVETABLE)/(58.2705/55.0000))+0.5 ), 9=>integer( (real(SAMPLES_PER_WAVETABLE)/(61.7354/55.0000))+0.5 ), -- A#1, B1
																			 
		  10=>integer( (real(SAMPLES_PER_WAVETABLE)/(69.2957/65.4064))+0.5 ), 11=>integer( (real(SAMPLES_PER_WAVETABLE)/(73.4162/65.4064))+0.5 ), -- C#2, D2
		  12=>integer( (real(SAMPLES_PER_WAVETABLE)/(82.4069/77.7817))+0.5 ), 13=>integer( (real(SAMPLES_PER_WAVETABLE)/(87.3071/77.7817))+0.5 ), -- E2, F2
		  14=>integer( (real(SAMPLES_PER_WAVETABLE)/(97.9989/92.4986))+0.5 ), 15=>integer( (real(SAMPLES_PER_WAVETABLE)/(103.826/92.4986))+0.5 ), -- G2, G#2
		  16=>integer( (real(SAMPLES_PER_WAVETABLE)/(116.541/110.000))+0.5 ), 17=>integer( (real(SAMPLES_PER_WAVETABLE)/(123.471/110.000))+0.5 ), -- A#2, B2
																			 
		  18=>integer( (real(SAMPLES_PER_WAVETABLE)/(138.591/130.813))+0.5 ), 19=>integer( (real(SAMPLES_PER_WAVETABLE)/(146.832/130.813))+0.5 ), -- C#3, D3
		  20=>integer( (real(SAMPLES_PER_WAVETABLE)/(164.814/155.563))+0.5 ), 21=>integer( (real(SAMPLES_PER_WAVETABLE)/(174.614/155.563))+0.5 ), -- E3, F3
		  22=>integer( (real(SAMPLES_PER_WAVETABLE)/(195.998/184.997))+0.5 ), 23=>integer( (real(SAMPLES_PER_WAVETABLE)/(207.652/184.997))+0.5 ), -- G3, G#3
		  24=>integer( (real(SAMPLES_PER_WAVETABLE)/(233.082/220.000))+0.5 ), 25=>integer( (real(SAMPLES_PER_WAVETABLE)/(246.942/220.000))+0.5 ), -- A#3, B3
																			 
		  26=>integer( (real(SAMPLES_PER_WAVETABLE)/(277.183/261.626))+0.5 ), 27=>integer( (real(SAMPLES_PER_WAVETABLE)/(293.665/261.626))+0.5 ), -- C#4, D4
		  28=>integer( (real(SAMPLES_PER_WAVETABLE)/(329.628/311.127))+0.5 ), 29=>integer( (real(SAMPLES_PER_WAVETABLE)/(349.228/311.127))+0.5 ), -- E4, F4
		  30=>integer( (real(SAMPLES_PER_WAVETABLE)/(391.995/369.994))+0.5 ), 31=>integer( (real(SAMPLES_PER_WAVETABLE)/(415.305/369.994))+0.5 ), -- G4, G#4
		  32=>integer( (real(SAMPLES_PER_WAVETABLE)/(466.164/440.000))+0.5 ), 33=>integer( (real(SAMPLES_PER_WAVETABLE)/(493.883/440.000))+0.5 ), -- A#4, B4
																			 
		  34=>integer( (real(SAMPLES_PER_WAVETABLE)/(554.365/523.251))+0.5 ), 35=>integer( (real(SAMPLES_PER_WAVETABLE)/(587.330/523.251))+0.5 ), -- C#5, D5
		  36=>integer( (real(SAMPLES_PER_WAVETABLE)/(659.255/622.254))+0.5 ), 37=>integer( (real(SAMPLES_PER_WAVETABLE)/(698.456/622.254))+0.5 ), -- E5, F5
		  38=>integer( (real(SAMPLES_PER_WAVETABLE)/(783.991/739.989))+0.5 ), 39=>integer( (real(SAMPLES_PER_WAVETABLE)/(830.609/739.989))+0.5 ), -- G5, G#5
		  40=>integer( (real(SAMPLES_PER_WAVETABLE)/(932.328/880.000))+0.5 ), 41=>integer( (real(SAMPLES_PER_WAVETABLE)/(987.767/880.000))+0.5 ), -- A#5, B5
																			 
		  42=>integer( (real(SAMPLES_PER_WAVETABLE)/(1108.73/1046.50))+0.5 ), 43=>integer( (real(SAMPLES_PER_WAVETABLE)/(1174.66/1046.50))+0.5 ), -- C#6, D6
		  44=>integer( (real(SAMPLES_PER_WAVETABLE)/(1318.51/1244.51))+0.5 ), 45=>integer( (real(SAMPLES_PER_WAVETABLE)/(1396.91/1244.51))+0.5 ), -- E6, F6
		  46=>integer( (real(SAMPLES_PER_WAVETABLE)/(1567.98/1479.98))+0.5 ), 47=>integer( (real(SAMPLES_PER_WAVETABLE)/(1661.22/1479.98))+0.5 ), -- G6, G#6
		  48=>integer( (real(SAMPLES_PER_WAVETABLE)/(1864.66/1760.00))+0.5 ), 49=>integer( (real(SAMPLES_PER_WAVETABLE)/(1975.53/1760.00))+0.5 ), -- A#6, B6
																			 
		  50=>integer( (real(SAMPLES_PER_WAVETABLE)/(2217.46/2093.00))+0.5 ), 51=>integer( (real(SAMPLES_PER_WAVETABLE)/(2349.32/2093.00))+0.5 ), -- C#7, D7
		  52=>integer( (real(SAMPLES_PER_WAVETABLE)/(2637.02/2489.02))+0.5 ), 53=>integer( (real(SAMPLES_PER_WAVETABLE)/(2793.83/2489.02))+0.5 ), -- E7, F7
		  54=>integer( (real(SAMPLES_PER_WAVETABLE)/(3135.96/2959.96))+0.5 ), 55=>integer( (real(SAMPLES_PER_WAVETABLE)/(3322.44/2959.96))+0.5 ), -- G7, G#7
		  56=>integer( (real(SAMPLES_PER_WAVETABLE)/(3729.31/3520.00))+0.5 ), 57=>integer( (real(SAMPLES_PER_WAVETABLE)/(3951.07/3520.00))+0.5 ) -- A#7, B7		  

    );

	-------------------------------------------------
	-- Offset values to configure the sustain loop --
	-------------------------------------------------

   constant    SUSTAIN_OFFSET :   offset_t :=(
		0=>15,  1=>9,   2=>9, 	   -- A0, A#0, B0
   
        3=>15, 	4=>9,  5=>9,     -- C1, C#1, D1
        6=>15, 	7=>9,  8=>9,     -- D#1, E1, F1 
        9=>15, 	10=>9, 11=>9,   -- F#1, G1, G#1
        12=>15, 13=>9, 14=>9,  -- A1, A#1, B1

        15=>15, 16=>9, 17=>9,  -- C2, C#2, D2
        18=>15, 19=>9, 20=>9,   -- D#2, E2, F2 
        21=>15, 22=>9, 23=>9,  -- F#2, G2, G#2
        24=>15, 25=>9, 26=>9,  -- A2, A#2, B2

        27=>15, 28=>9, 29=>9,     -- C3, C#3, D3
        30=>15, 31=>9, 32=>9,     -- D#3, E3, F3 
        33=>15, 34=>9, 35=>9,   	 -- F#3, G3, G#3
        36=>15, 37=>9, 38=>9,  	 -- A3, A#3, B3
			
	    39=>12, 40=>12, 41=>9,     ---- C4, C#4, D4
        42=>12, 43=>5, 44=>12,     ---- D#4, E4, F4 
        45=>12, 46=>12, 47=>12,     ---- F#4, G4, G#4
        48=>12, 49=>12, 50=>12,     ---- A4, A#4, B4

        51=>12, 52=>12, 53=>8,  	 ---- C5, C#5, D5
        54=>12, 55=>12, 56=>12,  	 ---- D#5, E5, F5 
        57=>15, 58=>9, 59=>9,     ---- F#5, G5, G#5
        60=>15, 61=>9, 62=>9,     ---- A5, A#5, B5

        63=>15, 64=>9, 65=>9,  	 ---- C6, C#6, D6
        66=>15, 67=>9, 68=>9,  	 ---- D#6, E6, F6 
        69=>15, 70=>9, 71=>9,     ---- F#6, G6, G#6
        72=>15, 73=>9, 74=>9,     ---- A6, A#6, B6

        75=>15, 76=>9, 77=>9,  	 ---- C7, C#7, D7
        78=>15, 79=>9, 80=>9,  	 ---- D#7, E7, F7 
        81=>15, 82=>9, 83=>9,     ---- F#7, G7, G#7
        84=>15, 85=>9, 86=>9,     ---- A7, A#7, B7

        87=>15  	 			  ---- C8
    );	
    

   constant    RELEASE_OFFSET :   offset_t :=(
		0=>10, 1=>10, 2=>10, 	   -- A0, A#0, B0
			
        3=>10, 	4=>10, 	5=>10,     -- C1, C#1, D1
        6=>10, 	7=>10, 	8=>10,     -- D#1, E1, F1 
        9=>10, 	10=>10, 11=>10,   -- F#1, G1, G#1
        12=>10,	13=>10, 14=>10,  -- A1, A#1, B1

        15=>10, 16=>10, 17=>10,  -- C2, C#2, D2
        18=>10, 19=>10, 20=>10,   -- D#2, E2, F2 
        21=>10, 22=>10, 23=>10,  -- F#2, G2, G#2
        24=>10, 25=>10, 26=>10,  -- A2, A#2, B2
							
        27=>10, 28=>10, 29=>10,     -- C3, C#3, D3
        30=>10, 31=>10, 32=>10,     -- D#3, E3, F3 
        33=>10, 34=>10, 35=>10,   	 -- F#3, G3, G#3
        36=>10, 37=>10, 38=>10,  	 -- A3, A#3, B3
							
	    39=>10, 40=>10, 41=>10,     ---- C4, C#4, D4
        42=>10, 43=>10, 44=>10,     ---- D#4, E4, F4 
        45=>10, 46=>10, 47=>10,     ---- F#4, G4, G#4
        48=>10, 49=>10, 50=>10,     ---- A4, A#4, B4
							
        51=>10, 52=>10, 53=>10,  	 ---- C5, C#5, D5
        54=>10, 55=>10, 56=>10,  	 ---- D#5, E5, F5 
        57=>10, 58=>10, 59=>10,     ---- F#5, G5, G#5
        60=>10, 61=>10, 62=>10,     ---- A5, A#5, B5
							
        63=>10, 64=>10, 65=>10,  	 ---- C6, C#6, D6
        66=>10, 67=>10, 68=>10,  	 ---- D#6, E6, F6 
        69=>10, 70=>10, 71=>10,     ---- F#6, G6, G#6
        72=>10, 73=>10, 74=>10,     ---- A6, A#6, B6
							
        75=>10, 76=>10, 77=>10,  	 ---- C7, C#7, D7
        78=>10, 79=>10, 80=>10,  	 ---- D#7, E7, F7 
        81=>10, 82=>10, 83=>10,     ---- F#7, G7, G#7
        84=>10, 85=>10, 86=>10,     ---- A7, A#7, B7

        87=>10  	 			  ---- C8
    );

	------------------------------------------
	-- Addrs intervals of the sustain loop  --
	------------------------------------------
	
	constant    SUSTAIN_START_OFFSET_ADDR :   offset_t :=(
		0=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,27.5,SUSTAIN_OFFSET(0)+RELEASE_OFFSET(0)), 							-- A0 
		1=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(0),FS,29.1353,SUSTAIN_OFFSET(1)+RELEASE_OFFSET(1)),        -- A#0
		2=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(1),FS,30.8677,SUSTAIN_OFFSET(2)+RELEASE_OFFSET(2)),        -- B0
		
		-- Octave 1	                                                                                                                    
		3=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,32.7032,SUSTAIN_OFFSET(3)+RELEASE_OFFSET(3)),					    -- C1 
		4=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(2),FS,34.6479,SUSTAIN_OFFSET(4)+RELEASE_OFFSET(4)), 	    -- C#1
		5=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(3),FS,36.7081,SUSTAIN_OFFSET(5)+RELEASE_OFFSET(5)), 	    -- D1
		
		6=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,38.8909,SUSTAIN_OFFSET(6)+RELEASE_OFFSET(6)),					    -- D#1
		7=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(4),FS,41.2035,SUSTAIN_OFFSET(7)+RELEASE_OFFSET(7)), 	    -- E1
		8=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(5),FS,43.6536,SUSTAIN_OFFSET(8)+RELEASE_OFFSET(8)), 	    -- F1
		
		9=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,46.2493,SUSTAIN_OFFSET(9)+RELEASE_OFFSET(9)),					    -- F#1
		10=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(6),FS,48.9995,SUSTAIN_OFFSET(10)+RELEASE_OFFSET(10)), 	-- G1
		11=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(7),FS,51.9130,SUSTAIN_OFFSET(11)+RELEASE_OFFSET(11)), 	-- G#
		
		12=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,55.0000,SUSTAIN_OFFSET(12)+RELEASE_OFFSET(12)),					-- A1 
		13=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(8),FS,58.2705,SUSTAIN_OFFSET(13)+RELEASE_OFFSET(13)),	    -- A#1
		14=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(9),FS,61.7354,SUSTAIN_OFFSET(14)+RELEASE_OFFSET(14)),	    -- B1
		
		
		-- Octave 2                                                                                                                       
		15 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,65.4064,SUSTAIN_OFFSET(15)+RELEASE_OFFSET(15)),					-- C2
		16 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(10),FS,69.2957,SUSTAIN_OFFSET(16)+RELEASE_OFFSET(16)),	-- C#2
		17 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(11),FS,73.4162,SUSTAIN_OFFSET(17)+RELEASE_OFFSET(17)), 	-- D2
		
		18 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,77.7817,SUSTAIN_OFFSET(18)+RELEASE_OFFSET(18)),					-- D#2
		19 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(12),FS,82.4069,SUSTAIN_OFFSET(19)+RELEASE_OFFSET(19)), 	-- E2
		20 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(13),FS,87.3071,SUSTAIN_OFFSET(20)+RELEASE_OFFSET(20)), 	-- F2
		
		21 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,92.4986,SUSTAIN_OFFSET(21)+RELEASE_OFFSET(21)),					-- F#2	
		22 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(14),FS,97.9989,SUSTAIN_OFFSET(22)+RELEASE_OFFSET(22)), 	-- G2
		23 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(15),FS,103.826,SUSTAIN_OFFSET(23)+RELEASE_OFFSET(23)), 	-- G#2
		
		24 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,110.000,SUSTAIN_OFFSET(24)+RELEASE_OFFSET(24)),					-- A2
		25 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(16),FS,116.541,SUSTAIN_OFFSET(25)+RELEASE_OFFSET(25)), 	-- A#2
		26 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(17),FS,123.471,SUSTAIN_OFFSET(26)+RELEASE_OFFSET(26)), 	-- B2
		
	-- Octave 3                                                                                                                       
		27 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,130.813,SUSTAIN_OFFSET(27)+RELEASE_OFFSET(27)),					 -- C3 
		28 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(18),FS,138.591,SUSTAIN_OFFSET(28)+RELEASE_OFFSET(28)), 	 -- C#3
		29 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(19),FS,146.832,SUSTAIN_OFFSET(29)+RELEASE_OFFSET(29)), 	 -- D3
		
		30 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,155.563,SUSTAIN_OFFSET(30)+RELEASE_OFFSET(30)),					 -- D#3
		31 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(20),FS,164.814,SUSTAIN_OFFSET(31)+RELEASE_OFFSET(31)), 	 -- E3
		32 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(21),FS,174.614,SUSTAIN_OFFSET(32)+RELEASE_OFFSET(32)), 	 -- F3

		33 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,184.997,SUSTAIN_OFFSET(33)+RELEASE_OFFSET(33)),					 -- F#3
		34 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(22),FS,195.998,SUSTAIN_OFFSET(34)+RELEASE_OFFSET(34)), 	 -- G3
		35 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(23),FS,207.652,SUSTAIN_OFFSET(35)+RELEASE_OFFSET(35)), 	 -- G#3

		36 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,220.000,SUSTAIN_OFFSET(36)+RELEASE_OFFSET(36)),					 -- A3
		37 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(24),FS,233.082,SUSTAIN_OFFSET(37)+RELEASE_OFFSET(37)), 	 -- A#3
		38 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(25),FS,246.942,SUSTAIN_OFFSET(38)+RELEASE_OFFSET(38)), 	 -- B3
		

		-- Octave 4                                                                                                                       
		39 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,261.626,SUSTAIN_OFFSET(39)+RELEASE_OFFSET(39)),					 -- C4
		40 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(26),FS,277.183,SUSTAIN_OFFSET(40)+RELEASE_OFFSET(40)), 	 -- C#4
		41 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(27),FS,293.665,SUSTAIN_OFFSET(41)+RELEASE_OFFSET(41)), 	 -- D4
		
		42 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,311.127,SUSTAIN_OFFSET(42)+RELEASE_OFFSET(42)),					 -- D#4
		43 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(28),FS,329.628,SUSTAIN_OFFSET(43)+RELEASE_OFFSET(43)), 	 -- E4
		44 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(29),FS,349.228,SUSTAIN_OFFSET(44)+RELEASE_OFFSET(44)), 	 -- F4
		
		45 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,369.994,SUSTAIN_OFFSET(45)+RELEASE_OFFSET(45)),						 -- F#4
		46 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(30),FS,391.995,SUSTAIN_OFFSET(46)+RELEASE_OFFSET(46)), 	 -- G4
		47 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(31),FS,415.305,SUSTAIN_OFFSET(47)+RELEASE_OFFSET(47)), 	 -- G#4
		
		48 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,440.000,SUSTAIN_OFFSET(48)+RELEASE_OFFSET(48)),					 -- A4
		49 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(32),FS,466.164,SUSTAIN_OFFSET(49)+RELEASE_OFFSET(49)), 	 -- A#4
		50 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(33),FS,493.883,SUSTAIN_OFFSET(50)+RELEASE_OFFSET(50)), 	 -- B4
		

		-- Octave 5                                                                                                            
		51 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,523.251,SUSTAIN_OFFSET(51)+RELEASE_OFFSET(51)),					 -- C5
		52 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(34),FS,554.365,SUSTAIN_OFFSET(52)+RELEASE_OFFSET(52)), 	 -- C#5
		53 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(35),FS,587.330,SUSTAIN_OFFSET(53)+RELEASE_OFFSET(53)), 	 -- D5
		
		54 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,622.254,SUSTAIN_OFFSET(54)+RELEASE_OFFSET(54)),					 -- D#5
		55 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(36),FS,659.255,SUSTAIN_OFFSET(55)+RELEASE_OFFSET(55)), 	 -- E5
		56 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(37),FS,698.456,SUSTAIN_OFFSET(56)+RELEASE_OFFSET(56)), 	 -- F5

		57 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,739.989,SUSTAIN_OFFSET(57)+RELEASE_OFFSET(57)),						 -- F#5
		58 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(38),FS,783.991,SUSTAIN_OFFSET(58)+RELEASE_OFFSET(58)), 	 -- G5
		59 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(39),FS,830.609,SUSTAIN_OFFSET(59)+RELEASE_OFFSET(59)), 	 -- G#5
		
		60 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,880.000,SUSTAIN_OFFSET(60)+RELEASE_OFFSET(60)),					 -- A5
		61 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(40),FS,932.328,SUSTAIN_OFFSET(61)+RELEASE_OFFSET(61)), 	 -- A#5
		62 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(41),FS,987.767,SUSTAIN_OFFSET(62)+RELEASE_OFFSET(62)), 	 -- B5


		-- Octave 6                                                                                                            
		63 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1046.50,SUSTAIN_OFFSET(63)+RELEASE_OFFSET(63)),					 -- C6
		64 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(42),FS,1108.73,SUSTAIN_OFFSET(64)+RELEASE_OFFSET(64)), 	 -- C#6
		65 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(43),FS,1174.66,SUSTAIN_OFFSET(65)+RELEASE_OFFSET(65)), 	 -- D6
		
		66 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1244.51,SUSTAIN_OFFSET(66)+RELEASE_OFFSET(66)),					 -- D#6
		67 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(44),FS,1318.51,SUSTAIN_OFFSET(67)+RELEASE_OFFSET(67)), 	 -- E6
		68 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(45),FS,1396.91,SUSTAIN_OFFSET(68)+RELEASE_OFFSET(68)), 	 -- F6
		
		69 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1479.98,SUSTAIN_OFFSET(69)+RELEASE_OFFSET(69)),					 -- F#6
		70 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(46),FS,1567.98,SUSTAIN_OFFSET(70)+RELEASE_OFFSET(70)), 	 -- G6
		71 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(47),FS,1661.22,SUSTAIN_OFFSET(71)+RELEASE_OFFSET(71)), 	 -- G#6
		
		72 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1760.00,SUSTAIN_OFFSET(72)+RELEASE_OFFSET(72)),					 -- A6
		73 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(48),FS,1864.66,SUSTAIN_OFFSET(73)+RELEASE_OFFSET(73)), 	 -- A#6
		74 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(49),FS,1975.53,SUSTAIN_OFFSET(74)+RELEASE_OFFSET(74)), 	 -- B6
		
		
		-- Octave 7
		75 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2093.00,SUSTAIN_OFFSET(75)+RELEASE_OFFSET(75)),					 -- C7
		76 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(50),FS,2217.46,SUSTAIN_OFFSET(76)+RELEASE_OFFSET(76)), 	 -- C#7
		77 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(51),FS,2349.32,SUSTAIN_OFFSET(77)+RELEASE_OFFSET(77)), 	 -- D7
		
		78 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2489.02,SUSTAIN_OFFSET(78)+RELEASE_OFFSET(78)),					 -- D#7
		79 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(52),FS,2637.02,SUSTAIN_OFFSET(79)+RELEASE_OFFSET(79)), 	 -- E7
		80 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(53),FS,2793.83,SUSTAIN_OFFSET(80)+RELEASE_OFFSET(80)), 	 -- F7
		
		81 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2959.96,SUSTAIN_OFFSET(81)+RELEASE_OFFSET(81)),						 -- F#7
		82 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(54),FS,3135.96,SUSTAIN_OFFSET(82)+RELEASE_OFFSET(82)), 	 -- G7
		83 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(55),FS,3322.44,SUSTAIN_OFFSET(83)+RELEASE_OFFSET(83)), 	 -- G#7
		
		84 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,3520.00,SUSTAIN_OFFSET(84)+RELEASE_OFFSET(84)),					 -- A7
		85 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(56),FS,3729.31,SUSTAIN_OFFSET(85)+RELEASE_OFFSET(85)), 	 -- A#7
		86 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(57),FS,3951.07,SUSTAIN_OFFSET(86)+RELEASE_OFFSET(86)), 	 -- B7
		
		87 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,4186.01,SUSTAIN_OFFSET(87)+RELEASE_OFFSET(87)) 					-- C8
	
	);
    
	
	constant    SUSTAIN_END_OFFSET_ADDR :   offset_t :=(
		0=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,27.5,RELEASE_OFFSET(0)), 							-- A0 
		1=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(0),FS,29.1353,RELEASE_OFFSET(1)),        -- A#0
		2=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(1),FS,30.8677,RELEASE_OFFSET(2)),        -- B0
		
		-- Octave 1	                                                                                                                    
		3=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,32.7032,RELEASE_OFFSET(3)),					    -- C1 
		4=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(2),FS,34.6479,RELEASE_OFFSET(4)), 	    -- C#1
		5=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(3),FS,36.7081,RELEASE_OFFSET(5)), 	    -- D1
		
		6=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,38.8909,RELEASE_OFFSET(6)),					    -- D#1
		7=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(4),FS,41.2035,RELEASE_OFFSET(7)), 	    -- E1
		8=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(5),FS,43.6536,RELEASE_OFFSET(8)), 	    -- F1
		
		9=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,46.2493,RELEASE_OFFSET(9)),					    -- F#1
		10=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(6),FS,48.9995,RELEASE_OFFSET(10)), 	-- G1
		11=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(7),FS,51.9130,RELEASE_OFFSET(11)), 	-- G#
		
		12=> getSustainAddr(SAMPLES_PER_WAVETABLE,FS,55.0000,RELEASE_OFFSET(12)),					-- A1 
		13=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(8),FS,58.2705,RELEASE_OFFSET(13)),	    -- A#1
		14=> getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(9),FS,61.7354,RELEASE_OFFSET(14)),	    -- B1
		
		
		-- Octave 2                                                                                                                       
		15 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,65.4064,RELEASE_OFFSET(15)),					-- C2
		16 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(10),FS,69.2957,RELEASE_OFFSET(16)),	-- C#2
		17 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(11),FS,73.4162,RELEASE_OFFSET(17)), 	-- D2
		
		18 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,77.7817,RELEASE_OFFSET(18)),					-- D#2
		19 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(12),FS,82.4069,RELEASE_OFFSET(19)), 	-- E2
		20 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(13),FS,87.3071,RELEASE_OFFSET(20)), 	-- F2
		
		21 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,92.4986,RELEASE_OFFSET(21)),					-- F#2	
		22 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(14),FS,97.9989,RELEASE_OFFSET(22)), 	-- G2
		23 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(15),FS,103.826,RELEASE_OFFSET(23)), 	-- G#2
		
		24 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,110.000,RELEASE_OFFSET(24)),					-- A2
		25 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(16),FS,116.541,RELEASE_OFFSET(25)), 	-- A#2
		26 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(17),FS,123.471,RELEASE_OFFSET(26)), 	-- B2
		
	-- Octave 3                                                                                                                       
		27 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,130.813,RELEASE_OFFSET(27)),					 -- C3 
		28 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(18),FS,138.591,RELEASE_OFFSET(28)), 	 -- C#3
		29 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(19),FS,146.832,RELEASE_OFFSET(29)), 	 -- D3
		
		30 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,155.563,RELEASE_OFFSET(30)),					 -- D#3
		31 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(20),FS,164.814,RELEASE_OFFSET(31)), 	 -- E3
		32 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(21),FS,174.614,RELEASE_OFFSET(32)), 	 -- F3

		33 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,184.997,RELEASE_OFFSET(33)),					 -- F#3
		34 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(22),FS,195.998,RELEASE_OFFSET(34)), 	 -- G3
		35 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(23),FS,207.652,RELEASE_OFFSET(35)), 	 -- G#3

		36 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,220.000,RELEASE_OFFSET(36)),					 -- A3
		37 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(24),FS,233.082,RELEASE_OFFSET(37)), 	 -- A#3
		38 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(25),FS,246.942,RELEASE_OFFSET(38)), 	 -- B3
		

		-- Octave 4                                                                                                                       
		39 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,261.626,RELEASE_OFFSET(39)),					 -- C4
		40 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(26),FS,277.183,RELEASE_OFFSET(40)), 	 -- C#4
		41 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(27),FS,293.665,RELEASE_OFFSET(41)), 	 -- D4
		
		42 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,311.127,RELEASE_OFFSET(42)),					 -- D#4
		43 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(28),FS,329.628,RELEASE_OFFSET(43)), 	 -- E4
		44 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(29),FS,349.228,RELEASE_OFFSET(44)), 	 -- F4
		
		45 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,369.994,RELEASE_OFFSET(45)),						 -- F#4
		46 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(30),FS,391.995,RELEASE_OFFSET(46)), 	 -- G4
		47 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(31),FS,415.305,RELEASE_OFFSET(47)), 	 -- G#4
		
		48 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,440.000,RELEASE_OFFSET(48)),					 -- A4
		49 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(32),FS,466.164,RELEASE_OFFSET(49)), 	 -- A#4
		50 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(33),FS,493.883,RELEASE_OFFSET(50)), 	 -- B4
		

		-- Octave 5                                                                                                            
		51 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,523.251,RELEASE_OFFSET(51)),					 -- C5
		52 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(34),FS,554.365,RELEASE_OFFSET(52)), 	 -- C#5
		53 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(35),FS,587.330,RELEASE_OFFSET(53)), 	 -- D5
		
		54 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,622.254,RELEASE_OFFSET(54)),					 -- D#5
		55 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(36),FS,659.255,RELEASE_OFFSET(55)), 	 -- E5
		56 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(37),FS,698.456,RELEASE_OFFSET(56)), 	 -- F5

		57 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,739.989,RELEASE_OFFSET(57)),						 -- F#5
		58 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(38),FS,783.991,RELEASE_OFFSET(58)), 	 -- G5
		59 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(39),FS,830.609,RELEASE_OFFSET(59)), 	 -- G#5
		
		60 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,880.000,RELEASE_OFFSET(60)),					 -- A5
		61 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(40),FS,932.328,RELEASE_OFFSET(61)), 	 -- A#5
		62 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(41),FS,987.767,RELEASE_OFFSET(62)), 	 -- B5


		-- Octave 6                                                                                                            
		63 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1046.50,RELEASE_OFFSET(63)),					 -- C6
		64 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(42),FS,1108.73,RELEASE_OFFSET(64)), 	 -- C#6
		65 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(43),FS,1174.66,RELEASE_OFFSET(65)), 	 -- D6
		
		66 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1244.51,RELEASE_OFFSET(66)),					 -- D#6
		67 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(44),FS,1318.51,RELEASE_OFFSET(67)), 	 -- E6
		68 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(45),FS,1396.91,RELEASE_OFFSET(68)), 	 -- F6
		
		69 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1479.98,RELEASE_OFFSET(69)),					 -- F#6
		70 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(46),FS,1567.98,RELEASE_OFFSET(70)), 	 -- G6
		71 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(47),FS,1661.22,RELEASE_OFFSET(71)), 	 -- G#6
		
		72 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,1760.00,RELEASE_OFFSET(72)),					 -- A6
		73 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(48),FS,1864.66,RELEASE_OFFSET(73)), 	 -- A#6
		74 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(49),FS,1975.53,RELEASE_OFFSET(74)), 	 -- B6
		
		
		-- Octave 7
		75 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2093.00,RELEASE_OFFSET(75)),					 -- C7
		76 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(50),FS,2217.46,RELEASE_OFFSET(76)), 	 -- C#7
		77 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(51),FS,2349.32,RELEASE_OFFSET(77)), 	 -- D7
		
		78 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2489.02,RELEASE_OFFSET(78)),					 -- D#7
		79 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(52),FS,2637.02,RELEASE_OFFSET(79)), 	 -- E7
		80 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(53),FS,2793.83,RELEASE_OFFSET(80)), 	 -- F7
		
		81 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,2959.96,RELEASE_OFFSET(81)),						 -- F#7
		82 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(54),FS,3135.96,RELEASE_OFFSET(82)), 	 -- G7
		83 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(55),FS,3322.44,RELEASE_OFFSET(83)), 	 -- G#7
		
		84 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,3520.00,RELEASE_OFFSET(84)),					 -- A7
		85 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(56),FS,3729.31,RELEASE_OFFSET(85)), 	 -- A#7
		86 => getSustainAddr(MAX_INTERPOLATED_SAMPLES_PER_NOTE(57),FS,3951.07,RELEASE_OFFSET(86)), 	 -- B7
		
		87 => getSustainAddr(SAMPLES_PER_WAVETABLE,FS,4186.01,RELEASE_OFFSET(87)) 					-- C8
	
	);	
	
	
----------------------------------------------------------------------------------
-- SIGNALS
----------------------------------------------------------------------------------            
    -- NoteParams
	signal	  startAddrROM                  :    unsigned(25 downto 0);
    signal    sustainStartOffsetAddrROM   :    unsigned(25 downto 0);
    signal    sustainEndOffsetAddrROM     :    unsigned(25 downto 0);
    signal    maxSamplesROM               :    unsigned(25 downto 0);
    signal    stepValROM                  :    unsigned(63 downto 0);
    signal    sustainStepStartROM         :    unsigned(63 downto 0);
    signal    sustainStepEndROM           :    unsigned(63 downto 0);
	
	-- Signals for notesGen component
	signal	workingNotesGen				:	std_logic_vector(15 downto 0);
	-- Commented signal for the test
--	signal	notesOnOff					:	std_logic_vector(15 downto 0);
	
	-- Registers
--	signal	regStartAddr                :	std_logic_vector(25 downto 0);
--	signal	regSustainStartOffsetAddr   :	std_logic_vector(25 downto 0);
--	signal	regSustainEndOffsetAddr     :	std_logic_vector(25 downto 0);
--	signal	regMaxSamples               :	std_logic_vector(25 downto 0);
--	signal	regStepVal                  :	std_logic_vector(63 downto 0);
--	signal	regSustainStepStart         :	std_logic_vector(63 downto 0);
--	signal	regSustainStepEnd           :	std_logic_vector(63 downto 0);
	
	-- State of the NoteGenerators
	signal regKeyboardState	:	std_logic_vector(31 downto 0);

begin

	
-------------------------------------
			-- ROMs--
-- Hexadecimal values of the notes --
-- Decode note value --
-------------------------------------

-- One entry per three notes	
	startAddr_ROM :
  with cmdKeyboard(7 downto 0) select
			startAddrROM <=
				
				to_unsigned(SAMPLES_PER_WAVETABLE,26)		when X"18" | X"19" | X"1A", 	-- C1, C#1, D1
				to_unsigned(SAMPLES_PER_WAVETABLE*2,26)		when X"1B" | X"1C" | X"1D", -- D#1, E1, F1
				to_unsigned(SAMPLES_PER_WAVETABLE*3,26)		when X"1E" | X"1F" | X"20", -- F#1, G1, G#1
				to_unsigned(SAMPLES_PER_WAVETABLE*4,26)		when X"21" | X"22" | X"23", -- A1, A#1, B1
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*5,26)		when X"24" | X"25" | X"26", 	-- C2, C#2, D2
				to_unsigned(SAMPLES_PER_WAVETABLE*6,26)		when X"27" | X"28" | X"29", -- D#2, E2, F2
				to_unsigned(SAMPLES_PER_WAVETABLE*7,26)		when X"2A" | X"2B" | X"2C", -- F#2, G2, G#2
				to_unsigned(SAMPLES_PER_WAVETABLE*8,26)		when X"2D" | X"2E" | X"2F", -- A2, A#2, B2
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*9,26)		when X"30" | X"31" | X"32", 	-- C3, C#3, D3
				to_unsigned(SAMPLES_PER_WAVETABLE*10,26)	when X"33" | X"34" | X"35", -- D#3, E3, F3
				to_unsigned(SAMPLES_PER_WAVETABLE*11,26)	when X"36" | X"37" | X"38", -- F#3, G3, G#3
				to_unsigned(SAMPLES_PER_WAVETABLE*12,26)	when X"39" | X"3A" | X"3B", -- A3, A#3, B3
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*13,26)	when X"3C" | X"3D" | X"3E", 	-- C4, C#4, D4
				to_unsigned(SAMPLES_PER_WAVETABLE*14,26)	when X"3F" | X"40" | X"41", -- D#4, E4, F4
				to_unsigned(SAMPLES_PER_WAVETABLE*15,26)	when X"42" | X"43" | X"44", -- F#4, G4, G#4
				to_unsigned(SAMPLES_PER_WAVETABLE*16,26)	when X"45" | X"46" | X"47", -- A4, A#4, B4
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*17,26)	when X"48" | X"49" | X"4A", 	-- C5, C#5, D5
				to_unsigned(SAMPLES_PER_WAVETABLE*18,26)	when X"4B" | X"4C" | X"4D", -- D#5, E5, F5
				to_unsigned(SAMPLES_PER_WAVETABLE*19,26)	when X"4E" | X"4F" | X"50", -- F#5, G5, G#5
				to_unsigned(SAMPLES_PER_WAVETABLE*20,26)	when X"51" | X"52" | X"53", -- A5, A#5, B5
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*21,26)	when X"54" | X"55" | X"56", 	-- C6, C#6, D6
				to_unsigned(SAMPLES_PER_WAVETABLE*22,26)	when X"57" | X"58" | X"59", -- D#6, E6, F6
				to_unsigned(SAMPLES_PER_WAVETABLE*23,26)	when X"5A" | X"5B" | X"5C", -- F#6, G6, G#6
				to_unsigned(SAMPLES_PER_WAVETABLE*24,26)	when X"5D" | X"5E" | X"5F", -- A6, A#6, B6
																					  
				to_unsigned(SAMPLES_PER_WAVETABLE*25,26)	when X"60" | X"61" | X"62", 	-- C7, C#7, D7
				to_unsigned(SAMPLES_PER_WAVETABLE*26,26)	when X"63" | X"64" | X"65", -- D#7, E7, F7
				to_unsigned(SAMPLES_PER_WAVETABLE*27,26)	when X"66" | X"67" | X"68", -- F#7, G7, G#7
				to_unsigned(SAMPLES_PER_WAVETABLE*28,26)	when X"69" | X"6A" | X"6B", -- A7, A#7, B7
				
				to_unsigned(SAMPLES_PER_WAVETABLE*29,26)	when X"6C",  -- C8
				
				to_unsigned(0,26) when others;  -- when X"15" | X"16" | X"17", -- A0, A#0, B0




-- One entry per note
	sustainStartOffsetAddr_ROM :
  with cmdKeyboard(7 downto 0) select
			sustainStartOffsetAddrROM <=
			
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(0),26)	when X"15", -- A0 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(1),26) 	when X"16", -- A#0
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(2),26) 	when X"17", -- B0
				
				-- Octave 1	                                                                                                                    
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(3),26)	when X"18", -- C1 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(4),26) 	when X"19", -- C#1
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(5),26) 	when X"1A", -- D1
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(6),26)	when X"1B", -- D#1 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(7),26) 	when X"1C", -- E1
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(8),26) 	when X"1D", -- F1
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(9),26)	when X"1E", -- F#1 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(10),26) 	when X"1F", -- G1
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(11),26) 	when X"20", -- G#1
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(12),26)	when X"21", -- A1 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(13),26) 	when X"22", -- A#1
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(14),26) 	when X"23", -- B1
				
				
				-- Octave 2                                                                                                                       
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(15),26)	when X"24", -- C2
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(16),26)	when X"25", -- C#2
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(17),26) 	when X"26", -- D2
	
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(18),26)	when X"27", -- D#2 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(19),26) 	when X"28", -- E2
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(20),26) 	when X"29", -- F2
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(21),26)	when X"2A", -- F#2 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(22),26) 	when X"2B", -- G2
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(23),26) 	when X"2C", -- G#2
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(24),26)	when X"2D", -- A2
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(25),26) 	when X"2E", -- A#2
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(26),26) 	when X"2F", -- B2
				
				
				-- Octave 3                                                                                                                       
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(27),26)	when X"30", -- C3 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(28),26) 	when X"31", -- C#3
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(29),26) 	when X"32", -- D3
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(30),26)	when X"33", -- D#3 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(31),26) 	when X"34", -- E3
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(32),26) 	when X"35", -- F3
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(33),26)	when X"36", -- F#3 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(34),26) 	when X"37", -- G3
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(35),26) 	when X"38", -- G#3
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(36),26)	when X"39", -- A3
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(37),26) 	when X"3A", -- A#3
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(38),26) 	when X"3B", -- B3
				
				
				-- Octave 4                                                                                                                       
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(39),26)	when X"3C", -- C4
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(40),26) 	when X"3D", -- C#4
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(41),26) 	when X"3E", -- D4
	
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(42),26)	when X"3F", -- D#4 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(43),26) 	when X"40", -- E4
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(44),26) 	when X"41", -- F4
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(45),26)	when X"42", -- F#4 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(46),26) 	when X"43", -- G4
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(47),26) 	when X"44", -- G#4
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(48),26)	when X"45", -- A4
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(49),26) 	when X"46", -- A#4
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(50),26) 	when X"47", -- B4
				
				
				-- Octave 5                                                                                                                       
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(51),26)	when X"48", -- C5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(52),26) 	when X"49", -- C#5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(53),26) 	when X"4A", -- D5
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(54),26)	when X"4B", -- D#5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(55),26) 	when X"4C", -- E5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(56),26) 	when X"4D", -- F5
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(57),26)	when X"4E", -- F#5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(58),26) 	when X"4F", -- G5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(59),26) 	when X"50", -- G#5
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(60),26)	when X"51", -- A5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(61),26) 	when X"52", -- A#5
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(62),26) 	when X"53", -- B5
				
				
				-- Octave 6                                                                                                                       
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(63),26)	when X"54", -- C6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(64),26) 	when X"55", -- C#6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(65),26) 	when X"56", -- D6
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(66),26)	when X"57", -- D#6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(67),26) 	when X"58", -- E6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(68),26) 	when X"59", -- F6
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(69),26)	when X"5A", -- F#6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(70),26) 	when X"5B", -- G6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(71),26) 	when X"5C", -- G#6
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(72),26)	when X"5D", -- A6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(73),26) 	when X"5E", -- A#6
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(74),26) 	when X"5F", -- B6
				
				
				-- Octave 7                                                                                                                       
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(75),26)	when X"60", -- C7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(76),26) 	when X"61", -- C#7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(77),26) 	when X"62", -- D7

				to_unsigned(SUSTAIN_START_OFFSET_ADDR(78),26)	when X"63", -- D#7 
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(79),26) 	when X"64", -- E7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(80),26) 	when X"65", -- F7

				to_unsigned(SUSTAIN_START_OFFSET_ADDR(81),26)	when X"66", -- F#7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(82),26) 	when X"67", -- G7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(83),26) 	when X"68", -- G#7

				to_unsigned(SUSTAIN_START_OFFSET_ADDR(84),26)	when X"69", -- A7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(85),26) 	when X"6A", -- A#7
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(86),26) 	when X"6B", -- B7
				
				to_unsigned(SUSTAIN_START_OFFSET_ADDR(87),26)	when X"6C", -- C8
				
				to_unsigned(0,26) when others;


-- One entry per note
	sustainEndOffsetAddr_ROM :
  with cmdKeyboard(7 downto 0) select
			sustainEndOffsetAddrROM <=
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(0),26)		when X"15", -- A0 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(1),26) 		when X"16", -- A#0
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(2),26) 		when X"17", -- B0
				
				-- Octave 1	                                                                                                                    
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(3),26)		when X"18", -- C1 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(4),26) 		when X"19", -- C#1
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(5),26) 		when X"1A", -- D1
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(6),26)		when X"1B", -- D#1 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(7),26) 		when X"1C", -- E1
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(8),26) 		when X"1D", -- F1
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(9),26)		when X"1E", -- F#1 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(10),26) 	when X"1F", -- G1
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(11),26) 	when X"20", -- G#1
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(12),26)		when X"21", -- A1 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(13),26) 	when X"22", -- A#1
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(14),26) 	when X"23", -- B1
				
				
				-- Octave 2                                                                                                                       
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(15),26)		when X"24", -- C2
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(16),26)		when X"25", -- C#2
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(17),26) 	when X"26", -- D2
	
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(18),26)		when X"27", -- D#2 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(19),26) 	when X"28", -- E2
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(20),26) 	when X"29", -- F2
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(21),26)		when X"2A", -- F#2 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(22),26) 	when X"2B", -- G2
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(23),26) 	when X"2C", -- G#2
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(24),26)		when X"2D", -- A2
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(25),26) 	when X"2E", -- A#2
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(26),26) 	when X"2F", -- B2
				
				
				-- Octave 3                                                                                                                       
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(27),26)		when X"30", -- C3 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(28),26) 	when X"31", -- C#3
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(29),26) 	when X"32", -- D3
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(30),26)		when X"33", -- D#3 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(31),26) 	when X"34", -- E3
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(32),26) 	when X"35", -- F3
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(33),26)		when X"36", -- F#3 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(34),26) 	when X"37", -- G3
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(35),26) 	when X"38", -- G#3
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(36),26)		when X"39", -- A3
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(37),26) 	when X"3A", -- A#3
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(38),26) 	when X"3B", -- B3
				
				
				-- Octave 4                                                                                                                       
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(39),26)		when X"3C", -- C4
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(40),26) 	when X"3D", -- C#4
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(41),26) 	when X"3E", -- D4
	
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(42),26)		when X"3F", -- D#4 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(43),26) 	when X"40", -- E4
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(44),26) 	when X"41", -- F4
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(45),26)		when X"42", -- F#4 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(46),26) 	when X"43", -- G4
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(47),26) 	when X"44", -- G#4
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(48),26)		when X"45", -- A4
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(49),26) 	when X"46", -- A#4
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(50),26) 	when X"47", -- B4
				
				
				-- Octave 5                                                                                                                       
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(51),26)		when X"48", -- C5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(52),26) 	when X"49", -- C#5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(53),26) 	when X"4A", -- D5
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(54),26)		when X"4B", -- D#5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(55),26) 	when X"4C", -- E5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(56),26) 	when X"4D", -- F5
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(57),26)		when X"4E", -- F#5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(58),26) 	when X"4F", -- G5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(59),26) 	when X"50", -- G#5
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(60),26)		when X"51", -- A5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(61),26) 	when X"52", -- A#5
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(62),26) 	when X"53", -- B5
				
				
				-- Octave 6                                                                                                                       
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(63),26)		when X"54", -- C6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(64),26) 	when X"55", -- C#6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(65),26) 	when X"56", -- D6
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(66),26)		when X"57", -- D#6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(67),26) 	when X"58", -- E6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(68),26) 	when X"59", -- F6
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(69),26)		when X"5A", -- F#6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(70),26) 	when X"5B", -- G6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(71),26) 	when X"5C", -- G#6
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(72),26)		when X"5D", -- A6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(73),26) 	when X"5E", -- A#6
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(74),26) 	when X"5F", -- B6
				
				
				-- Octave 7                                                                                                                       
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(75),26)		when X"60", -- C7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(76),26) 	when X"61", -- C#7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(77),26) 	when X"62", -- D7

				to_unsigned(SUSTAIN_END_OFFSET_ADDR(78),26)		when X"63", -- D#7 
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(79),26) 	when X"64", -- E7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(80),26) 	when X"65", -- F7

				to_unsigned(SUSTAIN_END_OFFSET_ADDR(81),26)		when X"66", -- F#7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(82),26) 	when X"67", -- G7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(83),26) 	when X"68", -- G#7

				to_unsigned(SUSTAIN_END_OFFSET_ADDR(84),26)		when X"69", -- A7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(85),26) 	when X"6A", -- A#7
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(86),26) 	when X"6B", -- B7
				
				to_unsigned(SUSTAIN_END_OFFSET_ADDR(87),26)		when X"6C", -- C8
				
				to_unsigned(0,26) when others;
				



-- One entry per interpolated note
	maxSamples_ROM :
  with cmdKeyboard(7 downto 0) select
			maxSamplesROM <=
				
				-- Interpolated notes
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(0),26)	when X"16",	-- A#0
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(1),26)	when X"17",	-- B0
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(2),26)	when X"19",	-- C#1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(3),26)	when X"1A",	-- D1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(4),26)	when X"1C", -- E1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(5),26)	when X"1D",	-- F1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(6),26)	when X"1F", -- G1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(7),26)	when X"20", -- G#1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(8),26)	when X"22", -- A#1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(9),26)	when X"23", -- B1
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(10),26)	when X"25",	-- C#2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(11),26)	when X"26", -- D2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(12),26)	when X"28",	-- E2 
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(13),26)	when X"29", -- F2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(14),26)	when X"2B",	-- G2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(15),26)	when X"2C",	-- G#2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(16),26)	when X"2E", -- A#2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(17),26)	when X"2F",	-- B2
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(18),26)	when X"31", -- C#3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(19),26)	when X"32", -- D3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(20),26)	when X"34", -- E3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(21),26)	when X"35", -- F3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(22),26)	when X"37", -- G3 
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(23),26)	when X"38", -- G#3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(24),26)	when X"3A", -- A#3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(25),26)	when X"3B", -- B3
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(26),26)	when X"3D", -- C#4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(27),26)	when X"3E", -- D4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(28),26)	when X"40", -- E4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(29),26)	when X"41", -- F4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(30),26)	when X"43", -- G4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(31),26)	when X"44", -- G#4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(32),26)	when X"46", -- A#4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(33),26)	when X"47",	-- B4
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(34),26)	when X"49",	-- C#5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(35),26)	when X"4A", -- D5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(36),26)	when X"4C", -- E5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(37),26)	when X"4D", -- F5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(38),26)	when X"4F", -- G5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(39),26)	when X"50", -- G#5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(40),26)	when X"52", -- A#5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(41),26)	when X"53",	-- B5
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(42),26)	when X"55", -- C#6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(43),26)	when X"56", -- D6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(44),26)	when X"58", -- E6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(45),26)	when X"59", -- F6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(46),26)	when X"5B", -- G6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(47),26)	when X"5C", -- G#6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(48),26)	when X"5E", -- A#6
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(49),26)	when X"5F", -- B6				
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(50),26)	when X"61", -- C#7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(51),26)	when X"62", -- D7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(52),26)	when X"64", -- E7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(53),26)	when X"65", -- F7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(54),26)	when X"67", -- G7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(55),26)	when X"68", -- G#7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(56),26)	when X"6A", -- A#7
				to_unsigned(MAX_INTERPOLATED_SAMPLES_PER_NOTE(57),26)	when X"6B", -- B7					
				
				to_unsigned(SAMPLES_PER_WAVETABLE,26) when others;  -- For all the notes stored in memory, A0, C1,D#1,F#1,A#1, C2,D#2,F#2,A#2, .... C8
			

-- One entry per interpolated note
	stepVal_ROM :
  with cmdKeyboard(7 downto 0) select
			stepValROM <=
				
				-- Interpolated notes
				( (to_unsigned( integer(29.1353/27.5),32)& X"00000000") or toUnFix( 29.1353/27.5 ,32,32) )			when X"17",	-- A#0
				( (to_unsigned( integer(30.8677/27.5),32)& X"00000000") or toUnFix( 30.8677/27.5 ,32,32) )			when X"18",	-- B0
                ( (to_unsigned( integer(34.6479/32.7032),32)& X"00000000") or toUnFix( 34.6479/32.7032 ,32,32) )    when X"19",    -- C#1
                ( (to_unsigned( integer(36.7081/32.7032),32)& X"00000000") or toUnFix( 36.7081/32.7032 ,32,32) )    when X"1A",    -- D1
                ( (to_unsigned( integer(41.2035/38.8909),32)& X"00000000") or toUnFix( 41.2035/38.8909 ,32,32) )    when X"1C", -- E1
                ( (to_unsigned( integer(43.6536/38.8909),32)& X"00000000") or toUnFix( 43.6536/38.8909 ,32,32) )    when X"1D",    -- F1
                ( (to_unsigned( integer(48.9995/46.2493),32)& X"00000000") or toUnFix( 48.9995/46.2493 ,32,32) )    when X"1F", -- G1
                ( (to_unsigned( integer(51.9130/46.2493),32)& X"00000000") or toUnFix( 51.9130/46.2493 ,32,32) )    when X"20", -- G#1
                ( (to_unsigned( integer(58.2705/55.0000),32)& X"00000000") or toUnFix( 58.2705/55.0000 ,32,32) )    when X"22", -- A#1
                ( (to_unsigned( integer(61.7354/55.0000),32)& X"00000000") or toUnFix( 61.7354/55.0000 ,32,32) )    when X"23", -- B1
                ( (to_unsigned( integer(69.2957/65.4064),32)& X"00000000") or toUnFix( 69.2957/65.4064 ,32,32) )    when X"25",    -- C#2
                ( (to_unsigned( integer(73.4162/65.4064),32)& X"00000000") or toUnFix( 73.4162/65.4064 ,32,32) )    when X"26", -- D2
                ( (to_unsigned( integer(82.4069/77.7817),32)& X"00000000") or toUnFix( 82.4069/77.7817 ,32,32) )    when X"28",    -- E2 
                ( (to_unsigned( integer(87.3071/77.7817),32)& X"00000000") or toUnFix( 87.3071/77.7817 ,32,32) )    when X"29", -- F2
                ( (to_unsigned( integer(97.9989/92.4986),32)& X"00000000") or toUnFix( 97.9989/92.4986 ,32,32) )    when X"2B",    -- G2
                ( (to_unsigned( integer(103.826/92.4986),32)& X"00000000") or toUnFix( 103.826/92.4986 ,32,32) )    when X"2C",    -- G#2
                ( (to_unsigned( integer(116.541/110.000),32)& X"00000000") or toUnFix( 116.541/110.000 ,32,32) )    when X"2E", -- A#2
                ( (to_unsigned( integer(123.471/110.000),32)& X"00000000") or toUnFix( 123.471/110.000 ,32,32) )    when X"2F",    -- B2
                ( (to_unsigned( integer(138.591/130.813),32)& X"00000000") or toUnFix( 138.591/130.813 ,32,32) )    when X"31", -- C#3
                ( (to_unsigned( integer(146.832/130.813),32)& X"00000000") or toUnFix( 146.832/130.813 ,32,32) )    when X"32", -- D3
                ( (to_unsigned( integer(164.814/155.563),32)& X"00000000") or toUnFix( 164.814/155.563 ,32,32) )    when X"34", -- E3
                ( (to_unsigned( integer(174.614/155.563),32)& X"00000000") or toUnFix( 174.614/155.563 ,32,32) )    when X"35", -- F3
                ( (to_unsigned( integer(195.998/184.997),32)& X"00000000") or toUnFix( 195.998/184.997 ,32,32) )    when X"37", -- G3 
                ( (to_unsigned( integer(207.652/184.997),32)& X"00000000") or toUnFix( 207.652/184.997 ,32,32) )    when X"38", -- G#3
                ( (to_unsigned( integer(233.082/220.000),32)& X"00000000") or toUnFix( 233.082/220.000 ,32,32) )    when X"3A", -- A#3
                ( (to_unsigned( integer(246.942/220.000),32)& X"00000000") or toUnFix( 246.942/220.000 ,32,32) )    when X"3B", -- B3
                ( (to_unsigned( integer(277.183/261.626),32)& X"00000000") or toUnFix( 277.183/261.626 ,32,32) )    when X"3D", -- C#4
                ( (to_unsigned( integer(293.665/261.626),32)& X"00000000") or toUnFix( 293.665/261.626 ,32,32) )    when X"3E", -- D4
                ( (to_unsigned( integer(329.628/311.127),32)& X"00000000") or toUnFix( 329.628/311.127 ,32,32) )    when X"40", -- E4
                ( (to_unsigned( integer(349.228/311.127),32)& X"00000000") or toUnFix( 349.228/311.127 ,32,32) )    when X"41", -- F4
                ( (to_unsigned( integer(391.995/369.994),32)& X"00000000") or toUnFix( 391.995/369.994 ,32,32) )    when X"43", -- G4
                ( (to_unsigned( integer(415.305/369.994),32)& X"00000000") or toUnFix( 415.305/369.994 ,32,32) )    when X"44", -- G#4
                ( (to_unsigned( integer(466.164/440.000),32)& X"00000000") or toUnFix( 466.164/440.000 ,32,32) )    when X"46", -- A#4
                ( (to_unsigned( integer(493.883/440.000),32)& X"00000000") or toUnFix( 493.883/440.000 ,32,32) )    when X"47",    -- B4
                ( (to_unsigned( integer(554.365/523.251),32)& X"00000000") or toUnFix( 554.365/523.251 ,32,32) )    when X"49",    -- C#5
                ( (to_unsigned( integer(587.330/523.251),32)& X"00000000") or toUnFix( 587.330/523.251 ,32,32) )    when X"4A", -- D5
                ( (to_unsigned( integer(659.255/622.254),32)& X"00000000") or toUnFix( 659.255/622.254 ,32,32) )    when X"4C", -- E5
                ( (to_unsigned( integer(698.456/622.254),32)& X"00000000") or toUnFix( 698.456/622.254 ,32,32) )    when X"4D", -- F5
                ( (to_unsigned( integer(783.991/739.989),32)& X"00000000") or toUnFix( 783.991/739.989 ,32,32) )    when X"4F", -- G5
                ( (to_unsigned( integer(830.609/739.989),32)& X"00000000") or toUnFix( 830.609/739.989 ,32,32) )    when X"50", -- G#5
                ( (to_unsigned( integer(932.328/880.000),32)& X"00000000") or toUnFix( 932.328/880.000 ,32,32) )    when X"52", -- A#5
                ( (to_unsigned( integer(987.767/880.000),32)& X"00000000") or toUnFix( 987.767/880.000 ,32,32) )    when X"53",    -- B5
                ( (to_unsigned( integer(1108.73/1046.50),32)& X"00000000") or toUnFix( 1108.73/1046.50 ,32,32) )    when X"55", -- C#6
                ( (to_unsigned( integer(1174.66/1046.50),32)& X"00000000") or toUnFix( 1174.66/1046.50 ,32,32) )    when X"56", -- D6
                ( (to_unsigned( integer(1318.51/1244.51),32)& X"00000000") or toUnFix( 1318.51/1244.51 ,32,32) )    when X"58", -- E6
                ( (to_unsigned( integer(1396.91/1244.51),32)& X"00000000") or toUnFix( 1396.91/1244.51 ,32,32) )    when X"59", -- F6
                ( (to_unsigned( integer(1567.98/1479.98),32)& X"00000000") or toUnFix( 1567.98/1479.98 ,32,32) )    when X"5B", -- G6
                ( (to_unsigned( integer(1661.22/1479.98),32)& X"00000000") or toUnFix( 1661.22/1479.98 ,32,32) )    when X"5C", -- G#6
                ( (to_unsigned( integer(1864.66/1760.00),32)& X"00000000") or toUnFix( 1864.66/1760.00 ,32,32) )    when X"5E", -- A#6
                ( (to_unsigned( integer(1975.53/1760.00),32)& X"00000000") or toUnFix( 1975.53/1760.00 ,32,32) )    when X"5F", -- B6                
                ( (to_unsigned( integer(2217.46/2093.00),32)& X"00000000") or toUnFix( 2217.46/2093.00 ,32,32) )    when X"61", -- C#7
                ( (to_unsigned( integer(2349.32/2093.00),32)& X"00000000") or toUnFix( 2349.32/2093.00 ,32,32) )    when X"62", -- D7
                ( (to_unsigned( integer(2637.02/2489.02),32)& X"00000000") or toUnFix( 2637.02/2489.02 ,32,32) )    when X"64", -- E7
                ( (to_unsigned( integer(2793.83/2489.02),32)& X"00000000") or toUnFix( 2793.83/2489.02 ,32,32) )    when X"65", -- F7
                ( (to_unsigned( integer(3135.96/2959.96),32)& X"00000000") or toUnFix( 3135.96/2959.96 ,32,32) )    when X"67", -- G7
                ( (to_unsigned( integer(3322.44/2959.96),32)& X"00000000") or toUnFix( 3322.44/2959.96 ,32,32) )    when X"68", -- G#7
                ( (to_unsigned( integer(3729.31/3520.00),32)& X"00000000") or toUnFix( 3729.31/3520.00 ,32,32) )    when X"6A", -- A#7
                ( (to_unsigned( integer(3951.07/3520.00),32)& X"00000000") or toUnFix( 3951.07/3520.00 ,32,32) )    when X"6B", -- B7			
				
				X"0000000100000000" when others;  -- For all the notes stored in memory, A0, C1,D#1,F#1,A#1, C2,D#2,F#2,A#2, .... C8
				

-- One entry per note
	sustainStepStart_ROM :
  with cmdKeyboard(7 downto 0) select
			sustainStepStartROM <=

				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(0), 32)& X"00000000")																																		when X"15", --A0		
				( (to_unsigned( integer( getSustainStep(29.1353/27.5, SUSTAIN_START_OFFSET_ADDR(1)) ),32)& X"00000000") or 	toUnFix( getSustainStep(29.1353/27.5, SUSTAIN_START_OFFSET_ADDR(1) ),32,32) )			when X"16",	-- A#0
				( (to_unsigned( integer( getSustainStep(30.8677/27.5, SUSTAIN_START_OFFSET_ADDR(2)) ),32)& X"00000000") or 	toUnFix( getSustainStep(30.8677/27.5, SUSTAIN_START_OFFSET_ADDR(2) ),32,32) )			when X"17",	-- B0
				
				--Octave 1
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(3) ,32)& X"00000000")																																		when X"18", --C1		
				( (to_unsigned( integer( getSustainStep(34.6479/32.7032, SUSTAIN_START_OFFSET_ADDR(4)) ),32)& X"00000000") or  toUnFix( getSustainStep(34.6479/32.7032, SUSTAIN_START_OFFSET_ADDR(4)  ),32,32) )	when X"19",	-- C#1
                ( (to_unsigned( integer( getSustainStep(36.7081/32.7032, SUSTAIN_START_OFFSET_ADDR(5)) ),32)& X"00000000") or  toUnFix( getSustainStep(36.7081/32.7032, SUSTAIN_START_OFFSET_ADDR(5)  ),32,32) )    when X"1A",    -- D1
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(6), 32)& X"00000000")																																		when X"1B", --D#1		
				( (to_unsigned( integer( getSustainStep(41.2035/38.8909, SUSTAIN_START_OFFSET_ADDR(7)) ),32)& X"00000000") or  toUnFix( getSustainStep(41.2035/38.8909, SUSTAIN_START_OFFSET_ADDR(7)  ),32,32) )	when X"1C", -- E1
                ( (to_unsigned( integer( getSustainStep(43.6536/38.8909, SUSTAIN_START_OFFSET_ADDR(8)) ),32)& X"00000000") or  toUnFix( getSustainStep(43.6536/38.8909, SUSTAIN_START_OFFSET_ADDR(8)  ),32,32) )    when X"1D",    -- F1
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(9), 32)& X"00000000")																																		when X"1E", --F#1		
				( (to_unsigned( integer( getSustainStep(48.9995/46.2493, SUSTAIN_START_OFFSET_ADDR(10)) ),32)& X"00000000") or toUnFix( getSustainStep(48.9995/46.2493, SUSTAIN_START_OFFSET_ADDR(10) ),32,32) )	when X"1F", -- G1
                ( (to_unsigned( integer( getSustainStep(51.9130/46.2493, SUSTAIN_START_OFFSET_ADDR(11)) ),32)& X"00000000") or toUnFix( getSustainStep(51.9130/46.2493, SUSTAIN_START_OFFSET_ADDR(11) ),32,32) )    when X"20", -- G#1
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(12), 32)& X"00000000")																																		when X"21", --A1		
				( (to_unsigned( integer( getSustainStep(58.2705/55.0000, SUSTAIN_START_OFFSET_ADDR(13)) ),32)& X"00000000") or toUnFix( getSustainStep(58.2705/55.0000, SUSTAIN_START_OFFSET_ADDR(13) ),32,32) )	when X"22", -- A#1
                ( (to_unsigned( integer( getSustainStep(61.7354/55.0000, SUSTAIN_START_OFFSET_ADDR(14)) ),32)& X"00000000") or toUnFix( getSustainStep(61.7354/55.0000, SUSTAIN_START_OFFSET_ADDR(14) ),32,32) )    when X"23", -- B1
				
				--Octave 2
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(15), 32)& X"00000000")																																		when X"24", --C2		
				( (to_unsigned( integer( getSustainStep(69.2957/65.4064, SUSTAIN_START_OFFSET_ADDR(16)) ),32)& X"00000000") or toUnFix( getSustainStep(69.2957/65.4064, SUSTAIN_START_OFFSET_ADDR(16) ),32,32) )	when X"25",	-- C#2
                ( (to_unsigned( integer( getSustainStep(73.4162/65.40614, SUSTAIN_START_OFFSET_ADDR(17)) ),32)& X"00000000") or toUnFix( getSustainStep(73.4162/65.4064, SUSTAIN_START_OFFSET_ADDR(17) ),32,32) )   when X"26", -- D2
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(18), 32)& X"00000000")																																		when X"27", --D#2		
				( (to_unsigned( integer( getSustainStep(82.4069/77.7817, SUSTAIN_START_OFFSET_ADDR(19)) ),32)& X"00000000") or toUnFix( getSustainStep(82.4069/77.7817, SUSTAIN_START_OFFSET_ADDR(19) ),32,32) )	when X"28",	-- E2 
                ( (to_unsigned( integer( getSustainStep(87.3071/77.7817, SUSTAIN_START_OFFSET_ADDR(20)) ),32)& X"00000000") or toUnFix( getSustainStep(87.3071/77.7817, SUSTAIN_START_OFFSET_ADDR(20) ),32,32) )    when X"29", -- F2
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(21), 32)& X"00000000")																																		when X"2A", --F#2		
				( (to_unsigned( integer( getSustainStep(97.9989/92.4986, SUSTAIN_START_OFFSET_ADDR(22)) ),32)& X"00000000") or toUnFix( getSustainStep(97.9989/92.4986, SUSTAIN_START_OFFSET_ADDR(22) ),32,32) )	when X"2B",	-- G2
                ( (to_unsigned( integer( getSustainStep(103.826/92.4986, SUSTAIN_START_OFFSET_ADDR(23)) ),32)& X"00000000") or toUnFix( getSustainStep(103.826/92.4986, SUSTAIN_START_OFFSET_ADDR(23) ),32,32) )    when X"2C",    -- G#2
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(24), 32)& X"00000000")																																		when X"2D", --A2		
				( (to_unsigned( integer( getSustainStep(116.541/110.000, SUSTAIN_START_OFFSET_ADDR(25)) ),32)& X"00000000") or toUnFix( getSustainStep(116.541/110.000, SUSTAIN_START_OFFSET_ADDR(25) ),32,32) )	when X"2E", -- A#2
                ( (to_unsigned( integer( getSustainStep(123.471/110.000, SUSTAIN_START_OFFSET_ADDR(26)) ),32)& X"00000000") or toUnFix( getSustainStep(123.471/110.000, SUSTAIN_START_OFFSET_ADDR(26) ),32,32) )    when X"2F",    -- B2
				
				--Octave 3
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(27), 32)& X"00000000")																																		when X"30", --C3		
				( (to_unsigned( integer( getSustainStep(138.591/130.813, SUSTAIN_START_OFFSET_ADDR(28)) ),32)& X"00000000") or toUnFix( getSustainStep(138.591/130.813, SUSTAIN_START_OFFSET_ADDR(28) ),32,32) )	when X"31", -- C#3
                ( (to_unsigned( integer( getSustainStep(146.832/130.813, SUSTAIN_START_OFFSET_ADDR(29)) ),32)& X"00000000") or toUnFix( getSustainStep(146.832/130.813, SUSTAIN_START_OFFSET_ADDR(29) ),32,32) )    when X"32", -- D3
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(30), 32)& X"00000000")																																		when X"33", --D#3		
				( (to_unsigned( integer( getSustainStep(164.814/155.563, SUSTAIN_START_OFFSET_ADDR(31)) ),32)& X"00000000") or toUnFix( getSustainStep(164.814/155.563, SUSTAIN_START_OFFSET_ADDR(31) ),32,32) )	when X"34", -- E3
                ( (to_unsigned( integer( getSustainStep(174.614/155.563, SUSTAIN_START_OFFSET_ADDR(32)) ),32)& X"00000000") or toUnFix( getSustainStep(174.614/155.563, SUSTAIN_START_OFFSET_ADDR(32) ),32,32) )    when X"35", -- F3
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(33), 32)& X"00000000")																																		when X"36", --F#3						
				( (to_unsigned( integer( getSustainStep(195.998/184.997, SUSTAIN_START_OFFSET_ADDR(34)) ),32)& X"00000000") or toUnFix( getSustainStep(195.998/184.997, SUSTAIN_START_OFFSET_ADDR(34) ),32,32) )	when X"37", -- G3 
                ( (to_unsigned( integer( getSustainStep(207.652/184.997, SUSTAIN_START_OFFSET_ADDR(35)) ),32)& X"00000000") or toUnFix( getSustainStep(207.652/184.997, SUSTAIN_START_OFFSET_ADDR(35) ),32,32) )    when X"38", -- G#3
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(36), 32)& X"00000000")																																		when X"39", --A3		
				( (to_unsigned( integer( getSustainStep(233.082/220.000, SUSTAIN_START_OFFSET_ADDR(37)) ),32)& X"00000000") or toUnFix( getSustainStep(233.082/220.000, SUSTAIN_START_OFFSET_ADDR(37) ),32,32) )	when X"3A", -- A#3
                ( (to_unsigned( integer( getSustainStep(246.942/220.000, SUSTAIN_START_OFFSET_ADDR(38)) ),32)& X"00000000") or toUnFix( getSustainStep(246.942/220.000, SUSTAIN_START_OFFSET_ADDR(38) ),32,32) )    when X"3B", -- B3
				
				--Octave 4
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(39), 32)& X"00000000")																																		when X"3C", --C4		
				( (to_unsigned( integer( getSustainStep(277.183/261.626, SUSTAIN_START_OFFSET_ADDR(40)) ),32)& X"00000000") or toUnFix( getSustainStep(277.183/261.626, SUSTAIN_START_OFFSET_ADDR(40) ),32,32) )	when X"3D", -- C#4
                ( (to_unsigned( integer( getSustainStep(293.665/261.626, SUSTAIN_START_OFFSET_ADDR(41)) ),32)& X"00000000") or toUnFix( getSustainStep(293.665/261.626, SUSTAIN_START_OFFSET_ADDR(41) ),32,32) )    when X"3E", -- D4
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(42), 32)& X"00000000")																																		when X"3F", --D#1		
				( (to_unsigned( integer( getSustainStep(329.628/311.127, SUSTAIN_START_OFFSET_ADDR(43)) ),32)& X"00000000") or toUnFix( getSustainStep(329.628/311.127, SUSTAIN_START_OFFSET_ADDR(43) ),32,32) )	when X"40", -- E4
                ( (to_unsigned( integer( getSustainStep(349.228/311.127, SUSTAIN_START_OFFSET_ADDR(44)) ),32)& X"00000000") or toUnFix( getSustainStep(349.228/311.127, SUSTAIN_START_OFFSET_ADDR(44) ),32,32) )    when X"41", -- F4
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(45), 32)& X"00000000")																																		when X"42", --F#4		
				( (to_unsigned( integer( getSustainStep(391.995/369.994, SUSTAIN_START_OFFSET_ADDR(46)) ),32)& X"00000000") or toUnFix( getSustainStep(391.995/369.994, SUSTAIN_START_OFFSET_ADDR(46) ),32,32) )	when X"43", -- G4
                ( (to_unsigned( integer( getSustainStep(415.305/369.994, SUSTAIN_START_OFFSET_ADDR(47)) ),32)& X"00000000") or toUnFix( getSustainStep(415.305/369.994, SUSTAIN_START_OFFSET_ADDR(47) ),32,32) )    when X"44", -- G#4
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(48), 32)& X"00000000")																																		when X"45", --A4		
				( (to_unsigned( integer( getSustainStep(466.164/440.000, SUSTAIN_START_OFFSET_ADDR(49)) ),32)& X"00000000") or toUnFix( getSustainStep(466.164/440.000, SUSTAIN_START_OFFSET_ADDR(49) ),32,32) )	when X"46", -- A#4
                ( (to_unsigned( integer( getSustainStep(493.883/440.000, SUSTAIN_START_OFFSET_ADDR(50)) ),32)& X"00000000") or toUnFix( getSustainStep(493.883/440.000, SUSTAIN_START_OFFSET_ADDR(50) ),32,32) )    when X"47",    -- B4
				
				--Octave 5
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(51), 32)& X"00000000")																																		when X"48", --C5		
				( (to_unsigned( integer( getSustainStep(554.365/523.251, SUSTAIN_START_OFFSET_ADDR(52)) ),32)& X"00000000") or toUnFix( getSustainStep(554.365/523.251, SUSTAIN_START_OFFSET_ADDR(52) ),32,32) )	when X"49",	-- C#5
                ( (to_unsigned( integer( getSustainStep(587.330/523.251, SUSTAIN_START_OFFSET_ADDR(53)) ),32)& X"00000000") or toUnFix( getSustainStep(587.330/523.251, SUSTAIN_START_OFFSET_ADDR(53) ),32,32) )    when X"4A", -- D5
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(54), 32)& X"00000000")																																		when X"4B", --D#5		
				( (to_unsigned( integer( getSustainStep(659.255/622.254, SUSTAIN_START_OFFSET_ADDR(55)) ),32)& X"00000000") or toUnFix( getSustainStep(659.255/622.254, SUSTAIN_START_OFFSET_ADDR(55) ),32,32) )	when X"4C", -- E5
                ( (to_unsigned( integer( getSustainStep(698.456/622.254, SUSTAIN_START_OFFSET_ADDR(56)) ),32)& X"00000000") or toUnFix( getSustainStep(698.456/622.254, SUSTAIN_START_OFFSET_ADDR(56) ),32,32) )    when X"4D", -- F5
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(57), 32)& X"00000000")																																		when X"4E", --F#5		
				( (to_unsigned( integer( getSustainStep(783.991/739.989, SUSTAIN_START_OFFSET_ADDR(58)) ),32)& X"00000000") or toUnFix( getSustainStep(783.991/739.989, SUSTAIN_START_OFFSET_ADDR(58) ),32,32) )	when X"4F", -- G5
                ( (to_unsigned( integer( getSustainStep(830.609/739.989, SUSTAIN_START_OFFSET_ADDR(59)) ),32)& X"00000000") or toUnFix( getSustainStep(830.609/739.989, SUSTAIN_START_OFFSET_ADDR(59) ),32,32) )    when X"50", -- G#5
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(60), 32)& X"00000000")																																		when X"51", --A5						
				( (to_unsigned( integer( getSustainStep(932.328/880.000, SUSTAIN_START_OFFSET_ADDR(61)) ),32)& X"00000000") or toUnFix( getSustainStep(932.328/880.000, SUSTAIN_START_OFFSET_ADDR(61) ),32,32) )	when X"52", -- A#5
                ( (to_unsigned( integer( getSustainStep(987.767/880.000, SUSTAIN_START_OFFSET_ADDR(62)) ),32)& X"00000000") or toUnFix( getSustainStep(987.767/880.000, SUSTAIN_START_OFFSET_ADDR(62) ),32,32) )    when X"53",    -- B5
				
				--Octave 6
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(63), 32)& X"00000000")																																		when X"54", --C6						
				( (to_unsigned( integer( getSustainStep(1108.73/1046.50, SUSTAIN_START_OFFSET_ADDR(64)) ),32)& X"00000000") or toUnFix( getSustainStep(1108.73/1046.50, SUSTAIN_START_OFFSET_ADDR(64) ),32,32) )	when X"55", -- C#6
                ( (to_unsigned( integer( getSustainStep(1174.66/1046.50, SUSTAIN_START_OFFSET_ADDR(65)) ),32)& X"00000000") or toUnFix( getSustainStep(1174.66/1046.50, SUSTAIN_START_OFFSET_ADDR(65) ),32,32) )    when X"56", -- D6
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(66), 32)& X"00000000")																																		when X"57", --D#6		
				( (to_unsigned( integer( getSustainStep(1318.51/1244.51, SUSTAIN_START_OFFSET_ADDR(67)) ),32)& X"00000000") or toUnFix( getSustainStep(1318.51/1244.51, SUSTAIN_START_OFFSET_ADDR(67) ),32,32) )	when X"58", -- E6
                ( (to_unsigned( integer( getSustainStep(1396.91/1244.51, SUSTAIN_START_OFFSET_ADDR(68)) ),32)& X"00000000") or toUnFix( getSustainStep(1396.91/1244.51, SUSTAIN_START_OFFSET_ADDR(68) ),32,32) )    when X"59", -- F6
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(69), 32)& X"00000000")																																		when X"5A", --F#6		
				( (to_unsigned( integer( getSustainStep(1567.98/1479.98, SUSTAIN_START_OFFSET_ADDR(70)) ),32)& X"00000000") or toUnFix( getSustainStep(1567.98/1479.98, SUSTAIN_START_OFFSET_ADDR(70) ),32,32) )	when X"5B", -- G6
                ( (to_unsigned( integer( getSustainStep(1661.22/1479.98, SUSTAIN_START_OFFSET_ADDR(71)) ),32)& X"00000000") or toUnFix( getSustainStep(1661.22/1479.98, SUSTAIN_START_OFFSET_ADDR(71) ),32,32) )    when X"5C", -- G#6
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(72), 32)& X"00000000")																																		when X"5D", --A6		
				( (to_unsigned( integer( getSustainStep(1864.66/1760.00, SUSTAIN_START_OFFSET_ADDR(73)) ),32)& X"00000000") or toUnFix( getSustainStep(1864.66/1760.00, SUSTAIN_START_OFFSET_ADDR(73) ),32,32) )	when X"5E", -- A#6
                ( (to_unsigned( integer( getSustainStep(1975.53/1760.00, SUSTAIN_START_OFFSET_ADDR(74)) ),32)& X"00000000") or toUnFix( getSustainStep(1975.53/1760.00, SUSTAIN_START_OFFSET_ADDR(74) ),32,32) )    when X"5F", -- B6
				
				--Octave 7
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(75), 32)& X"00000000")																																		when X"60", --C7						
				( (to_unsigned( integer( getSustainStep(2217.46/2093.00, SUSTAIN_START_OFFSET_ADDR(76)) ),32)& X"00000000") or toUnFix( getSustainStep(2217.46/2093.00, SUSTAIN_START_OFFSET_ADDR(76) ),32,32) )	when X"61", -- C#7
                ( (to_unsigned( integer( getSustainStep(2349.32/2093.00, SUSTAIN_START_OFFSET_ADDR(77)) ),32)& X"00000000") or toUnFix( getSustainStep(2349.32/2093.00, SUSTAIN_START_OFFSET_ADDR(77) ),32,32) )    when X"62", -- D7
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(78), 32)& X"00000000")																																		when X"63", --D#7						
				( (to_unsigned( integer( getSustainStep(2637.02/2489.02, SUSTAIN_START_OFFSET_ADDR(79)) ),32)& X"00000000") or toUnFix( getSustainStep(2637.02/2489.02, SUSTAIN_START_OFFSET_ADDR(79) ),32,32) )	when X"64", -- E7
                ( (to_unsigned( integer( getSustainStep(2793.83/2489.02, SUSTAIN_START_OFFSET_ADDR(80)) ),32)& X"00000000") or toUnFix( getSustainStep(2793.83/2489.02, SUSTAIN_START_OFFSET_ADDR(80) ),32,32) )    when X"65", -- F7
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(81), 32)& X"00000000")																																		when X"66", --F#7		
				( (to_unsigned( integer( getSustainStep(3135.96/2959.96, SUSTAIN_START_OFFSET_ADDR(82)) ),32)& X"00000000") or toUnFix( getSustainStep(3135.96/2959.96, SUSTAIN_START_OFFSET_ADDR(82) ),32,32) )	when X"67", -- G7
                ( (to_unsigned( integer( getSustainStep(3322.44/2959.96, SUSTAIN_START_OFFSET_ADDR(83)) ),32)& X"00000000") or toUnFix( getSustainStep(3322.44/2959.96, SUSTAIN_START_OFFSET_ADDR(83) ),32,32) )    when X"68", -- G#7
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(84), 32)& X"00000000")																																		when X"69", --A7		
                ( (to_unsigned( integer( getSustainStep(3729.31/3520.00, SUSTAIN_START_OFFSET_ADDR(85)) ),32)& X"00000000") or toUnFix( getSustainStep(3729.31/3520.00, SUSTAIN_START_OFFSET_ADDR(85) ),32,32) )    when X"6A", -- A#7
				
				(to_unsigned( SUSTAIN_START_OFFSET_ADDR(87), 32)& X"00000000")																																		when X"6C", --C8		
				to_unsigned( 0, 64)																																													when others;														
	
-- One entry per note
	sustainStepEnd_ROM :
  with cmdKeyboard(7 downto 0) select
			sustainStepEndROM <=
				
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(0), 32)& X"00000000")																																		when X"15", --A0		
				( (to_unsigned( integer( getSustainStep(29.1353/27.5, SUSTAIN_END_OFFSET_ADDR(1)) ),32)& X"00000000") or 	toUnFix( getSustainStep(29.1353/27.5, SUSTAIN_END_OFFSET_ADDR(1) ),32,32) )			when X"16",	-- A#0
                ( (to_unsigned( integer( getSustainStep(30.8677/27.5, SUSTAIN_END_OFFSET_ADDR(2)) ),32)& X"00000000") or     toUnFix( getSustainStep(30.8677/27.5, SUSTAIN_END_OFFSET_ADDR(2) ),32,32) )        when X"17",    -- B0
				
				--Octave 1
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(3) ,32)& X"00000000")																																		when X"18", --C1		
				( (to_unsigned( integer( getSustainStep(34.6479/32.7032, SUSTAIN_END_OFFSET_ADDR(4)) ),32)& X"00000000") or  toUnFix( getSustainStep(34.6479/32.7032, SUSTAIN_END_OFFSET_ADDR(4)  ),32,32) )	when X"19",	-- C#1
                ( (to_unsigned( integer( getSustainStep(36.7081/32.7032, SUSTAIN_END_OFFSET_ADDR(5)) ),32)& X"00000000") or  toUnFix( getSustainStep(36.7081/32.7032, SUSTAIN_END_OFFSET_ADDR(5)  ),32,32) )    when X"1A",    -- D1
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(6), 32)& X"00000000")																																		when X"1B", --D#1		
				( (to_unsigned( integer( getSustainStep(41.2035/38.8909, SUSTAIN_END_OFFSET_ADDR(7)) ),32)& X"00000000") or  toUnFix( getSustainStep(41.2035/38.8909, SUSTAIN_END_OFFSET_ADDR(7)  ),32,32) )	when X"1C", -- E1
                ( (to_unsigned( integer( getSustainStep(43.6536/38.8909, SUSTAIN_END_OFFSET_ADDR(8)) ),32)& X"00000000") or  toUnFix( getSustainStep(43.6536/38.8909, SUSTAIN_END_OFFSET_ADDR(8)  ),32,32) )    when X"1D",    -- F1
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(9), 32)& X"00000000")																																		when X"1E", --F#1		
				( (to_unsigned( integer( getSustainStep(48.9995/46.2493, SUSTAIN_END_OFFSET_ADDR(10)) ),32)& X"00000000") or toUnFix( getSustainStep(48.9995/46.2493, SUSTAIN_END_OFFSET_ADDR(10) ),32,32) )	when X"1F", -- G1
                ( (to_unsigned( integer( getSustainStep(51.9130/46.2493, SUSTAIN_END_OFFSET_ADDR(11)) ),32)& X"00000000") or toUnFix( getSustainStep(51.9130/46.2493, SUSTAIN_END_OFFSET_ADDR(11) ),32,32) )    when X"20", -- G#1
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(12), 32)& X"00000000")																																	when X"21", --A1		
				( (to_unsigned( integer( getSustainStep(58.2705/55.0000, SUSTAIN_END_OFFSET_ADDR(13)) ),32)& X"00000000") or toUnFix( getSustainStep(58.2705/55.0000, SUSTAIN_END_OFFSET_ADDR(13) ),32,32) )	when X"22", -- A#1
                ( (to_unsigned( integer( getSustainStep(61.7354/55.0000, SUSTAIN_END_OFFSET_ADDR(14)) ),32)& X"00000000") or toUnFix( getSustainStep(61.7354/55.0000, SUSTAIN_END_OFFSET_ADDR(14) ),32,32) )    when X"23", -- B1
				
				--Octave 2
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(15), 32)& X"00000000")																																	when X"24", --C2		
				( (to_unsigned( integer( getSustainStep(69.2957/65.4064, SUSTAIN_END_OFFSET_ADDR(16)) ),32)& X"00000000") or toUnFix( getSustainStep(69.2957/65.4064, SUSTAIN_END_OFFSET_ADDR(16) ),32,32) )	when X"25",	-- C#2
                ( (to_unsigned( integer( getSustainStep(73.4162/65.4064, SUSTAIN_END_OFFSET_ADDR(17)) ),32)& X"00000000") or toUnFix( getSustainStep(73.4162/65.4064, SUSTAIN_END_OFFSET_ADDR(17) ),32,32) )    when X"26", -- D2
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(18), 32)& X"00000000")																																	when X"27", --D#2		
				( (to_unsigned( integer( getSustainStep(82.4069/77.7817, SUSTAIN_END_OFFSET_ADDR(19)) ),32)& X"00000000") or toUnFix( getSustainStep(82.4069/77.7817, SUSTAIN_END_OFFSET_ADDR(19) ),32,32) )	when X"28",	-- E2 
                ( (to_unsigned( integer( getSustainStep(87.3071/77.7817, SUSTAIN_END_OFFSET_ADDR(20)) ),32)& X"00000000") or toUnFix( getSustainStep(87.3071/77.7817, SUSTAIN_END_OFFSET_ADDR(20) ),32,32) )    when X"29", -- F2
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(21), 32)& X"00000000")																																	when X"2A", --F#2		
				( (to_unsigned( integer( getSustainStep(97.9989/92.4986, SUSTAIN_END_OFFSET_ADDR(22)) ),32)& X"00000000") or toUnFix( getSustainStep(97.9989/92.4986, SUSTAIN_END_OFFSET_ADDR(22) ),32,32) )	when X"2B",	-- G2
                ( (to_unsigned( integer( getSustainStep(103.826/92.4986, SUSTAIN_END_OFFSET_ADDR(23)) ),32)& X"00000000") or toUnFix( getSustainStep(103.826/92.4986, SUSTAIN_END_OFFSET_ADDR(23) ),32,32) )    when X"2C",    -- G#2
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(24), 32)& X"00000000")																																	when X"2D", --A2		
				( (to_unsigned( integer( getSustainStep(116.541/110.000, SUSTAIN_END_OFFSET_ADDR(25)) ),32)& X"00000000") or toUnFix( getSustainStep(116.541/110.000, SUSTAIN_END_OFFSET_ADDR(25) ),32,32) )	when X"2E", -- A#2
                ( (to_unsigned( integer( getSustainStep(123.471/110.000, SUSTAIN_END_OFFSET_ADDR(26)) ),32)& X"00000000") or toUnFix( getSustainStep(123.471/110.000, SUSTAIN_END_OFFSET_ADDR(26) ),32,32) )    when X"2F",    -- B2
				
				--Octave 3
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(27), 32)& X"00000000")																																	when X"30", --C3		
				( (to_unsigned( integer( getSustainStep(138.591/130.813, SUSTAIN_END_OFFSET_ADDR(28)) ),32)& X"00000000") or toUnFix( getSustainStep(138.591/130.813, SUSTAIN_END_OFFSET_ADDR(28) ),32,32) )	when X"31", -- C#3
                ( (to_unsigned( integer( getSustainStep(146.832/130.813, SUSTAIN_END_OFFSET_ADDR(29)) ),32)& X"00000000") or toUnFix( getSustainStep(146.832/130.813, SUSTAIN_END_OFFSET_ADDR(29) ),32,32) )    when X"32", -- D3
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(30), 32)& X"00000000")																																	when X"33", --D#3		
				( (to_unsigned( integer( getSustainStep(164.814/155.563, SUSTAIN_END_OFFSET_ADDR(31)) ),32)& X"00000000") or toUnFix( getSustainStep(164.814/155.563, SUSTAIN_END_OFFSET_ADDR(31) ),32,32) )	when X"34", -- E3
                ( (to_unsigned( integer( getSustainStep(174.614/155.563, SUSTAIN_END_OFFSET_ADDR(32)) ),32)& X"00000000") or toUnFix( getSustainStep(174.614/155.563, SUSTAIN_END_OFFSET_ADDR(32) ),32,32) )    when X"35", -- F3
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(33), 32)& X"00000000")																																	when X"36", --F#3						
				( (to_unsigned( integer( getSustainStep(195.998/184.997, SUSTAIN_END_OFFSET_ADDR(34)) ),32)& X"00000000") or toUnFix( getSustainStep(195.998/184.997, SUSTAIN_END_OFFSET_ADDR(34) ),32,32) )	when X"37", -- G3 
                ( (to_unsigned( integer( getSustainStep(207.652/184.997, SUSTAIN_END_OFFSET_ADDR(35)) ),32)& X"00000000") or toUnFix( getSustainStep(207.652/184.997, SUSTAIN_END_OFFSET_ADDR(35) ),32,32) )    when X"38", -- G#3
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(36), 32)& X"00000000")																																	when X"39", --A3		
				( (to_unsigned( integer( getSustainStep(233.082/220.000, SUSTAIN_END_OFFSET_ADDR(37)) ),32)& X"00000000") or toUnFix( getSustainStep(233.082/220.000, SUSTAIN_END_OFFSET_ADDR(37) ),32,32) )	when X"3A", -- A#3
                ( (to_unsigned( integer( getSustainStep(246.942/220.000, SUSTAIN_END_OFFSET_ADDR(38)) ),32)& X"00000000") or toUnFix( getSustainStep(246.942/220.000, SUSTAIN_END_OFFSET_ADDR(38) ),32,32) )    when X"3B", -- B3
				
				--Octave 4
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(39), 32)& X"00000000")																																	when X"3C", --C4		
				( (to_unsigned( integer( getSustainStep(277.183/261.626, SUSTAIN_END_OFFSET_ADDR(40)) ),32)& X"00000000") or toUnFix( getSustainStep(277.183/261.626, SUSTAIN_END_OFFSET_ADDR(40) ),32,32) )	when X"3D", -- C#4
                ( (to_unsigned( integer( getSustainStep(293.665/261.626, SUSTAIN_END_OFFSET_ADDR(41)) ),32)& X"00000000") or toUnFix( getSustainStep(293.665/261.626, SUSTAIN_END_OFFSET_ADDR(41) ),32,32) )    when X"3E", -- D4
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(42), 32)& X"00000000")																																	when X"3F", --D#1		
				( (to_unsigned( integer( getSustainStep(329.628/311.127, SUSTAIN_END_OFFSET_ADDR(43)) ),32)& X"00000000") or toUnFix( getSustainStep(329.628/311.127, SUSTAIN_END_OFFSET_ADDR(43) ),32,32) )	when X"40", -- E4
                ( (to_unsigned( integer( getSustainStep(349.228/311.127, SUSTAIN_END_OFFSET_ADDR(44)) ),32)& X"00000000") or toUnFix( getSustainStep(349.228/311.127, SUSTAIN_END_OFFSET_ADDR(44) ),32,32) )    when X"41", -- F4
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(45), 32)& X"00000000")																																	when X"42", --F#4		
				( (to_unsigned( integer( getSustainStep(391.995/369.994, SUSTAIN_END_OFFSET_ADDR(46)) ),32)& X"00000000") or toUnFix( getSustainStep(391.995/369.994, SUSTAIN_END_OFFSET_ADDR(46) ),32,32) )	when X"43", -- G4
                ( (to_unsigned( integer( getSustainStep(415.305/369.994, SUSTAIN_END_OFFSET_ADDR(47)) ),32)& X"00000000") or toUnFix( getSustainStep(415.305/369.994, SUSTAIN_END_OFFSET_ADDR(47) ),32,32) )    when X"44", -- G#4
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(48), 32)& X"00000000")																																	when X"45", --A4		
				( (to_unsigned( integer( getSustainStep(466.164/440.000, SUSTAIN_END_OFFSET_ADDR(49)) ),32)& X"00000000") or toUnFix( getSustainStep(466.164/440.000, SUSTAIN_END_OFFSET_ADDR(49) ),32,32) )	when X"46", -- A#4
                ( (to_unsigned( integer( getSustainStep(493.883/440.000, SUSTAIN_END_OFFSET_ADDR(50)) ),32)& X"00000000") or toUnFix( getSustainStep(493.883/440.000, SUSTAIN_END_OFFSET_ADDR(50) ),32,32) )    when X"47",    -- B4
				
				--Octave 5
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(51), 32)& X"00000000")																																	when X"48", --C5		
				( (to_unsigned( integer( getSustainStep(554.365/523.251, SUSTAIN_END_OFFSET_ADDR(52)) ),32)& X"00000000") or toUnFix( getSustainStep(554.365/523.251, SUSTAIN_END_OFFSET_ADDR(52) ),32,32) )	when X"49",	-- C#5
                ( (to_unsigned( integer( getSustainStep(587.330/523.251, SUSTAIN_END_OFFSET_ADDR(53)) ),32)& X"00000000") or toUnFix( getSustainStep(587.330/523.251, SUSTAIN_END_OFFSET_ADDR(53) ),32,32) )    when X"4A", -- D5
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(54), 32)& X"00000000")																																	when X"4B", --D#5		
				( (to_unsigned( integer( getSustainStep(659.255/622.254, SUSTAIN_END_OFFSET_ADDR(55)) ),32)& X"00000000") or toUnFix( getSustainStep(659.255/622.254, SUSTAIN_END_OFFSET_ADDR(55) ),32,32) )	when X"4C", -- E5
                ( (to_unsigned( integer( getSustainStep(698.456/622.254, SUSTAIN_END_OFFSET_ADDR(56)) ),32)& X"00000000") or toUnFix( getSustainStep(698.456/622.254, SUSTAIN_END_OFFSET_ADDR(56) ),32,32) )    when X"4D", -- F5
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(57), 32)& X"00000000")																																	when X"4E", --F#5		
				( (to_unsigned( integer( getSustainStep(783.991/739.989, SUSTAIN_END_OFFSET_ADDR(58)) ),32)& X"00000000") or toUnFix( getSustainStep(783.991/739.989, SUSTAIN_END_OFFSET_ADDR(58) ),32,32) )	when X"4F", -- G5
                ( (to_unsigned( integer( getSustainStep(830.609/739.989, SUSTAIN_END_OFFSET_ADDR(59)) ),32)& X"00000000") or toUnFix( getSustainStep(830.609/739.989, SUSTAIN_END_OFFSET_ADDR(59) ),32,32) )    when X"50", -- G#5
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(60), 32)& X"00000000")																																	when X"51", --A5						
				( (to_unsigned( integer( getSustainStep(932.328/880.000, SUSTAIN_END_OFFSET_ADDR(61)) ),32)& X"00000000") or toUnFix( getSustainStep(932.328/880.000, SUSTAIN_END_OFFSET_ADDR(61) ),32,32) )	when X"52", -- A#5
                ( (to_unsigned( integer( getSustainStep(987.767/880.000, SUSTAIN_END_OFFSET_ADDR(62)) ),32)& X"00000000") or toUnFix( getSustainStep(987.767/880.000, SUSTAIN_END_OFFSET_ADDR(62) ),32,32) )    when X"53",    -- B5
				
				--Octave 6
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(63), 32)& X"00000000")																																	when X"54", --C6						
				( (to_unsigned( integer( getSustainStep(1108.73/1046.50, SUSTAIN_END_OFFSET_ADDR(64)) ),32)& X"00000000") or toUnFix( getSustainStep(1108.73/1046.50, SUSTAIN_END_OFFSET_ADDR(64) ),32,32) )	when X"55", -- C#6
                ( (to_unsigned( integer( getSustainStep(1174.66/1046.50, SUSTAIN_END_OFFSET_ADDR(65)) ),32)& X"00000000") or toUnFix( getSustainStep(1174.66/1046.50, SUSTAIN_END_OFFSET_ADDR(65) ),32,32) )    when X"56", -- D6
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(66), 32)& X"00000000")																																	when X"57", --D#6		
				( (to_unsigned( integer( getSustainStep(1318.51/1244.51, SUSTAIN_END_OFFSET_ADDR(67)) ),32)& X"00000000") or toUnFix( getSustainStep(1318.51/1244.51, SUSTAIN_END_OFFSET_ADDR(67) ),32,32) )	when X"58", -- E6
                ( (to_unsigned( integer( getSustainStep(1396.91/1244.51, SUSTAIN_END_OFFSET_ADDR(68)) ),32)& X"00000000") or toUnFix( getSustainStep(1396.91/1244.51, SUSTAIN_END_OFFSET_ADDR(68) ),32,32) )    when X"59", -- F6
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(69), 32)& X"00000000")																																	when X"5A", --F#6		
				( (to_unsigned( integer( getSustainStep(1567.98/1479.98, SUSTAIN_END_OFFSET_ADDR(70)) ),32)& X"00000000") or toUnFix( getSustainStep(1567.98/1479.98, SUSTAIN_END_OFFSET_ADDR(70) ),32,32) )	when X"5B", -- G6
                ( (to_unsigned( integer( getSustainStep(1661.22/1479.98, SUSTAIN_END_OFFSET_ADDR(71)) ),32)& X"00000000") or toUnFix( getSustainStep(1661.22/1479.98, SUSTAIN_END_OFFSET_ADDR(71) ),32,32) )    when X"5C", -- G#6
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(72), 32)& X"00000000")																																	when X"5D", --A6		
				( (to_unsigned( integer( getSustainStep(1864.66/1760.00, SUSTAIN_END_OFFSET_ADDR(73)) ),32)& X"00000000") or toUnFix( getSustainStep(1864.66/1760.00, SUSTAIN_END_OFFSET_ADDR(73) ),32,32) )	when X"5E", -- A#6
                ( (to_unsigned( integer( getSustainStep(1975.53/1760.00, SUSTAIN_END_OFFSET_ADDR(74)) ),32)& X"00000000") or toUnFix( getSustainStep(1975.53/1760.00, SUSTAIN_END_OFFSET_ADDR(74) ),32,32) )    when X"5F", -- B6
				
				--Octave 7
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(75), 32)& X"00000000")																																	when X"60", --C7						
				( (to_unsigned( integer( getSustainStep(2217.46/2093.00, SUSTAIN_END_OFFSET_ADDR(76)) ),32)& X"00000000") or toUnFix( getSustainStep(2217.46/2093.00, SUSTAIN_END_OFFSET_ADDR(76) ),32,32) )	when X"61", -- C#7
                ( (to_unsigned( integer( getSustainStep(2349.32/2093.00, SUSTAIN_END_OFFSET_ADDR(77)) ),32)& X"00000000") or toUnFix( getSustainStep(2349.32/2093.00, SUSTAIN_END_OFFSET_ADDR(77) ),32,32) )    when X"62", -- D7
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(78), 32)& X"00000000")																																	when X"63", --D#7						
				( (to_unsigned( integer( getSustainStep(2637.02/2489.02, SUSTAIN_END_OFFSET_ADDR(79)) ),32)& X"00000000") or toUnFix( getSustainStep(2637.02/2489.02, SUSTAIN_END_OFFSET_ADDR(79) ),32,32) )	when X"64", -- E7
                ( (to_unsigned( integer( getSustainStep(2793.83/2489.02, SUSTAIN_END_OFFSET_ADDR(80)) ),32)& X"00000000") or toUnFix( getSustainStep(2793.83/2489.02, SUSTAIN_END_OFFSET_ADDR(80) ),32,32) )    when X"65", -- F7
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(81), 32)& X"00000000")																																	when X"66", --F#7		
				( (to_unsigned( integer( getSustainStep(3135.96/2959.96, SUSTAIN_END_OFFSET_ADDR(82)) ),32)& X"00000000") or toUnFix( getSustainStep(3135.96/2959.96, SUSTAIN_END_OFFSET_ADDR(82) ),32,32) )	when X"67", -- G7
                ( (to_unsigned( integer( getSustainStep(3322.44/2959.96, SUSTAIN_END_OFFSET_ADDR(83)) ),32)& X"00000000") or toUnFix( getSustainStep(3322.44/2959.96, SUSTAIN_END_OFFSET_ADDR(83) ),32,32) )    when X"68", -- G#7
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(84), 32)& X"00000000")																																	when X"69", --A7		
				( (to_unsigned( integer( getSustainStep(3729.31/3520.00, SUSTAIN_END_OFFSET_ADDR(85)) ),32)& X"00000000") or toUnFix( getSustainStep(3729.31/3520.00, SUSTAIN_END_OFFSET_ADDR(85) ),32,32) )	when X"6A", -- A#7
                ( (to_unsigned( integer( getSustainStep(3951.07/3520.00, SUSTAIN_END_OFFSET_ADDR(86)) ),32)& X"00000000") or toUnFix( getSustainStep(3951.07/3520.00, SUSTAIN_END_OFFSET_ADDR(86) ),32,32) )    when X"6B", -- B7            
				
				(to_unsigned( SUSTAIN_END_OFFSET_ADDR(87), 32)& X"00000000")																																	when X"6C", --C8		
				to_unsigned( 0, 64)																																												when others;														


----------------------------------------------------------------------------------
								-- ROMs End --
----------------------------------------------------------------------------------  
--Debug
workingNotesGen <=(others=>'0'); 
--

--notesGen: NotesGenerator 
--  port map( 
--        rst_n           			=> rst_n,
--        clk             			=> clk,
--        notes_on        			=> notesOnOff,
--        working					=> workingNotesGen,

--		--Note params               
--		startAddr_In             	=> regStartAddr             ,
--		sustainStartOffsetAddr_In	=> regSustainStartOffsetAddr,
--		sustainEndOffsetAddr_In     => regSustainEndOffsetAddr  ,
--		maxSamples_In               => regMaxSamples            ,
--		stepVal_In                  => regStepVal               ,
--		sustainStepStart_In         => regSustainStepStart      ,
--		sustainStepEnd_In           => regSustainStepEnd        ,

--		--IIS side                  
--        sampleRqt       			=> sampleRqt,
--        sampleOut       			=> sampleOut,

--        -- Mem side                 
--		mem_emptyBuffer				=> mem_emptyBuffer		 ,
--        mem_CmdReadResponse    		=> mem_CmdReadResponse   ,
--        mem_fullBuffer         		=> mem_fullBuffer        ,
--        mem_CmdReadRequest		    => mem_CmdReadRequest	 ,
--		mem_readResponseBuffer		=> mem_readResponseBuffer,
--        mem_writeReciveBuffer     	=> mem_writeReciveBuffer 
  
--  );




----------------------------------------------------------------------------------
-- CMD RECIEVER
--		Manage the behaviour with the commands
----------------------------------------------------------------------------------  

fsm:
process(rst_n,clk,cen,emtyCmdKeyboardBuffer,cmdKeyboard,workingNotesGen)
	type states is ( reciveCmd, waitTurnOff);
	type noteState_t is record
		currentNote   :   std_logic_vector(7 downto 0);
        OnOff   	  :   std_logic; -- High On, low Off
	end record;
	type keyboardState_t 	is array ( 0 to 15 ) of noteState_t;
	type checkNotes_t		is 	array (0 to 15) of  unsigned(4 downto 0);
	
	variable state      	:   states;
	variable keyboardState	:	keyboardState_t;
	
	variable foundCode		:	std_logic_vector(15 downto 0);
	variable noteIndexOff 	:   checkNotes_t;
	
	variable foundAviable	:	std_logic_vector(15 downto 0);
	variable noteIndexOn	:   checkNotes_t;
	
begin
	
	for i in 0 to 15 loop
	   notesOnOff(i) <= keyboardState(i).OnOff;
	end loop;
	
	--------------------------------------------------------------------------
	-- "Combinational Search" of note index to slect which note turn on/off --
	--------------------------------------------------------------------------
	--searchFirstAviableNoteGen
	foundAviable(0) :='0';
	noteIndexOn(0) := to_unsigned(0,5);
	if keyboardState(0).OnOff='0' then
		foundAviable(0) :='1';
	end if;
    for i in 1 to 15 loop
        foundAviable(i) := foundAviable(i-1);
        noteIndexOn(i) := noteIndexOn(i-1);
        if foundAviable(i-1)='0' and keyboardState(i).OnOff='0' then
            noteIndexOn(i) := unsigned( std_logic_vector(to_unsigned(i,5)) );
            foundAviable(i) := '1';
        end if;
    end loop;

	--searchIndexByNoteCode
	foundCode(0) :='0';
	noteIndexOff(0) := to_unsigned(0,5);
	if cmdKeyboard(7 downto 0)=keyboardState(0).currentNote then
		foundCode(0) :='1';
	end if;
	for i in 1 to 15 loop
		foundCode(i) := foundCode(i-1);
		noteIndexOff(i) := noteIndexOff(i-1);
		if foundCode(i-1)='0' and cmdKeyboard(7 downto 0)=keyboardState(i).currentNote then
			noteIndexOff(i) := to_unsigned(i,5);	
		    foundCode(i) := '1';
		end if;
	end loop;
	
	
	if rst_n='0' then
		keyboardState :=(others=>(X"00",'0'));
		state := reciveCmd;
		-- Note params rst value
		regStartAddr               <= (others=>'0');
        regSustainStartOffsetAddr  <= (others=>'0');
        regSustainEndOffsetAddr    <= (others=>'0');
        regMaxSamples              <= (others=>'0');
        regStepVal                 <= (others=>'0');
        regSustainStepStart        <= (others=>'0');
        regSustainStepEnd          <= (others=>'0');
		keyboard_ack <='0';
		
    elsif rising_edge(clk) then
		keyboard_ack <='0';
		
		case state is
            when reciveCmd =>
				if cen='1' and emtyCmdKeyboardBuffer='0' then			
					
					-- Note On
					-- Turn on a new generator if there is some generator not working (foundAviable(15)='1')
					-- and if the note requested to turn on is not already on (foundCode='0')
					if cmdKeyboard(9 downto 8)="10" and foundAviable(15)='1' and foundCode(15)='0' then
                        -- Note params setup
                        regStartAddr                  <= std_logic_vector(startAddrROM);
                        regSustainStartOffsetAddr    <= std_logic_vector(sustainStartOffsetAddrROM);
                        regSustainEndOffsetAddr      <= std_logic_vector(sustainEndOffsetAddrROM);
                        regMaxSamples                <= std_logic_vector(maxSamplesROM);
                        regStepVal                   <= std_logic_vector(stepValROM);
                        regSustainStepStart          <= std_logic_vector(sustainStepStartROM);
                        regSustainStepEnd            <= std_logic_vector(sustainStepEndROM);

						keyboardState(to_integer(noteIndexOn(15))) := (cmdKeyboard(7 downto 0),'1');
						keyboard_ack <='1';

					-- Note Off
					-- Turn off a note if there is some generator working with that note code
					elsif cmdKeyboard(9 downto 8)="01" and foundCode(15)='1' then
						keyboardState(to_integer(noteIndexOff(15))) := (X"00",'0');
						state := waitTurnOff;
					
					-- This if the command has no effect on the keyboard state,
					-- it's needed to keep consuming commands from the buffer
					-- Example (turn on/off a note that is already on/off)
					else
					   keyboard_ack <='1';
					end if;
				end if;
			
			-- Wait until the end of the release phase
			when waitTurnOff =>
				if workingNotesGen(to_integer(noteIndexOff(15)))='0' then
					keyboard_ack <='1';
					state := reciveCmd;
				end if;
		end case;
    end if;
end process;
  
end Behavioral;
