----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
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
-- Revision 2.3
-- Additional Comments:
--		Command format: cmd(3 downto 0) = Velocity
--					 	cmd(11 downto 4) = NoteCode
--                      cmd(13 downto 12) = 01, note off	
--						cmd(13 downto 12) = 10, note on 
--                      cmd(14) = SourceIndex, when high, comes from extern interface, otherwise comes from MidiParser component
--
--  NUM_NOTES_GEN = 2**k
-- 
-- mem_CmdReadResponse(NUM_NOTES_GEN-1+log2(NUM_NOTES_GEN) downto 16)= note gen index, mem_CmdReadResponse(15 downto 0) = requested sample
--
-- mem_CmdReadRequest(25+log2(NUM_NOTES_GEN) downto 26)= note gen index, mem_CmdReadRequest(15 downto 0) = requested sample
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use WORK.MY_COMMON.ALL;

entity KeyboardCntrl is
  Generic ( NUM_NOTES_GEN   :   in  natural; 
            REVERB_TIME     :   in  real
  );
  Port ( 
        rst_n           			:   in  std_logic;
        clk             			:   in  std_logic;
        cen               			:   in  std_logic;
        midiParserOnOff             :   in  std_logic;
        externInterfaceStatus       :   in  std_logic;
        aviableCmd		            :	in  std_logic;	
        cmdKeyboard					:	in  std_logic_vector(14 downto 0);
        keyboard_ack				:	out	std_logic;
        
        -- For Reverb component
        reverbStatus                :   in  std_logic;
        
        --IIS side	
        sampleRqt       			:   in  std_logic;
        sampleOut       			:   out std_logic_vector(23 downto 0);
        
        --Keyboard Info
        numGensOn                   :   out std_logic_vector(log2(NUM_NOTES_GEN) downto 0);
        		
        -- Mem side
        mem_emptyBuffer				:	in	std_logic;
        mem_CmdReadResponse    		:   in  std_logic_vector(15+log2(NUM_NOTES_GEN) downto 0); 
        mem_fullBuffer         		:   in  std_logic; 
        mem_CmdReadRequest		    :   out std_logic_vector(25+log2(NUM_NOTES_GEN) downto 0);
        mem_readResponseBuffer		:	out std_logic;
        mem_writeReciveBuffer     	:   out std_logic -- One cycle high to send a new CmdReadRqt
  
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  KeyboardCntrl  :   entity  is  "true";
end KeyboardCntrl;

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
        0=>4,  1=>5,   2=>5,        -- A0, A#0, B0
   
        3=>5,     4=>2,  5=>2,     -- C1, C#1, D1
        6=>5,     7=>5,  8=>5,     -- D#1, E1, F1 
        9=>5,     10=>2, 11=>4,   -- F#1, G1, G#1
        12=>6, 13=>8, 14=>8,  -- A1, A#1, B1

        15=>9, 16=>9, 17=>8,  -- C2, C#2, D2
        18=>9, 19=>10, 20=>10,   -- D#2, E2, F2 
        21=>9, 22=>6, 23=>9,  -- F#2, G2, G#2
        24=>10, 25=>9, 26=>9,  -- A2, A#2, B2

        27=>12, 28=>9, 29=>6,     -- C3, C#3, D3
        30=>12, 31=>9, 32=>6,     -- D#3, E3, F3 
        33=>12, 34=>10, 35=>9,        -- F#3, G3, G#3
        36=>12, 37=>10, 38=>6,       -- A3, A#3, B3
            
        39=>9, 40=>9, 41=>9,     ---- C4, C#4, D4
        42=>12, 43=>5, 44=>6,     ---- D#4, E4, F4 
        45=>12, 46=>12, 47=>12,     ---- F#4, G4, G#4
        48=>12, 49=>12, 50=>6,     ---- A4, A#4, B4

        51=>20, 52=>15, 53=>15,       ---- C5, C#5, D5
        54=>20, 55=>12, 56=>15,       ---- D#5, E5, F5 
        57=>20, 58=>15, 59=>15,     ---- F#5, G5, G#5
        60=>20, 61=>15, 62=>15,     ---- A5, A#5, B5

        63=>25, 64=>25, 65=>20,       ---- C6, C#6, D6
        66=>25, 67=>25, 68=>20,       ---- D#6, E6, F6 
        69=>25, 70=>30, 71=>20,     ---- F#6, G6, G#6
        72=>35, 73=>35, 74=>35,     ---- A6, A#6, B6

        75=>30, 76=>25, 77=>25,       ---- C7, C#7, D7
        78=>30, 79=>25, 80=>25,       ---- D#7, E7, F7 
        81=>30, 82=>25, 83=>25,     ---- F#7, G7, G#7
        84=>30, 85=>25, 86=>25,     ---- A7, A#7, B7

        87=>35                     ---- C8
    );    
    

   constant    RELEASE_OFFSET :   offset_t :=(
        0=>2, 1=>2, 2=>2,        -- A0, A#0, B0
            
        3=>2,     4=>2,     5=>2,     -- C1, C#1, D1
        6=>2,     7=>2,     8=>2,     -- D#1, E1, F1 
        9=>2,     10=>2, 11=>2,   -- F#1, G1, G#1
        12=>2,    13=>2, 14=>2,  -- A1, A#1, B1

        15=>2, 16=>2, 17=>2,  -- C2, C#2, D2
        18=>2, 19=>2, 20=>2,   -- D#2, E2, F2 
        21=>2, 22=>2, 23=>5,  -- F#2, G2, G#2
        24=>5, 25=>2, 26=>2,  -- A2, A#2, B2
                            
        27=>5, 28=>5, 29=>5,     -- C3, C#3, D3
        30=>5, 31=>5, 32=>5,     -- D#3, E3, F3 
        33=>5, 34=>5, 35=>5,        -- F#3, G3, G#3
        36=>5, 37=>5, 38=>5,       -- A3, A#3, B3
                            
        39=>5, 40=>2, 41=>2,     ---- C4, C#4, D4
        42=>5, 43=>5, 44=>2,     ---- D#4, E4, F4 
        45=>5, 46=>5, 47=>5,     ---- F#4, G4, G#4
        48=>5, 49=>5, 50=>5,     ---- A4, A#4, B4
                            
        51=>10, 52=>10, 53=>10,       ---- C5, C#5, D5
        54=>10, 55=>10, 56=>10,       ---- D#5, E5, F5 
        57=>10, 58=>10, 59=>10,     ---- F#5, G5, G#5
        60=>10, 61=>10, 62=>10,     ---- A5, A#5, B5
                            
        63=>10, 64=>10, 65=>10,       ---- C6, C#6, D6
        66=>10, 67=>10, 68=>10,       ---- D#6, E6, F6 
        69=>10, 70=>10, 71=>10,     ---- F#6, G6, G#6
        72=>10, 73=>10, 74=>10,     ---- A6, A#6, B6
                            
        75=>35, 76=>35, 77=>35,       ---- C7, C#7, D7
        78=>35, 79=>35, 80=>35,       ---- D#7, E7, F7 
        81=>35, 82=>35, 83=>35,     ---- F#7, G7, G#7
        84=>35, 85=>35, 86=>35,     ---- A7, A#7, B7

        87=>45                     ---- C8
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
    signal    stepValROM                  :    unsigned(63 downto 0);
	
	-- Signals for notesGen component
	signal	workingNotesGen				:	std_logic_vector(NUM_NOTES_GEN-1 downto 0);
	-- Commented signal for the test
	signal	notesOnOff					:	std_logic_vector(NUM_NOTES_GEN-1 downto 0);
	
	-- Registers
	signal	regStartAddr                :	std_logic_vector(25 downto 0);
	signal	regSustainStartOffsetAddr   :	std_logic_vector(25 downto 0);
	signal	regSustainEndOffsetAddr     :	std_logic_vector(25 downto 0);
	signal	regStepVal                  :	std_logic_vector(63 downto 0);
	signal  regNoteVelocity             :  std_logic_vector(3 downto 0);
	
	-- State of the NoteGenerators
	signal regKeyboardState	:	std_logic_vector(31 downto 0);
	
	-- For Reverb component
	signal sampleOutNoteGen    :   std_logic_vector(23 downto 0);

begin

	
-------------------------------------
			-- ROMs--
-- Hexadecimal values of the notes --
-- Decode note value --
-------------------------------------

-- One entry per three notes	
	startAddr_ROM :
  with cmdKeyboard(11 downto 4) select
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
  with cmdKeyboard(11 downto 4) select
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
  with cmdKeyboard(11 downto 4) select
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
	stepVal_ROM :
  with cmdKeyboard(11 downto 4) select
			stepValROM <=
				
				-- Interpolated notes
				( (to_unsigned( integer(29.1353/27.5),32)& X"00000000") or toUnFix( 29.1353/27.5 ,32,32) )			when X"16",	-- A#0
				( (to_unsigned( integer(30.8677/27.5),32)& X"00000000") or toUnFix( 30.8677/27.5 ,32,32) )			when X"17",	-- B0
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


----------------------------------------------------------------------------------
								-- ROMs End --
----------------------------------------------------------------------------------  

my_countGens: CountGensOn
  generic map( WL => NUM_NOTES_GEN)
  port map( 
        rst_n        => rst_n,
        clk          => clk,
		
		notesOnOff	 => workingNotesGen,
		numGensOn	 => numGensOn
  );


my_gen: NotesGenerator 
  generic map( NUM_NOTES_GEN => NUM_NOTES_GEN)
  port map( 
        rst_n           			=> rst_n,
        clk             			=> clk,
        notes_on        			=> notesOnOff,
        working					    => workingNotesGen,

		--Note params               
		startAddr_In             	=> regStartAddr,
		sustainStartOffsetAddr_In	=> regSustainStartOffsetAddr,
		sustainEndOffsetAddr_In     => regSustainEndOffsetAddr,
		stepVal_In                  => regStepVal,
        noteVelocity                => regNoteVelocity,
        
		--IIS side                  
        sampleRqt       			=> sampleRqt,
        sampleOut       			=> sampleOutNoteGen,

        -- Mem side                 
		mem_emptyResponseBuffer		=> mem_emptyBuffer,
        mem_CmdReadResponse    		=> mem_CmdReadResponse,
        mem_fullReciveBuffer     	=> mem_fullBuffer,
        mem_CmdReadRequest		    => mem_CmdReadRequest,
		mem_readResponseBuffer		=> mem_readResponseBuffer,
        mem_writeReciveBuffer     	=> mem_writeReciveBuffer 
  
  );

-- 9 cycles for Universal generators pipelined operations, log2(NUM_NOTES_GEN) cycles for fix sum operations
-- (48800hz)/1000 * time in ms
Reverb: ReverbComponent
  generic map(FIFO_DEPTH=>integer((FS/1000.0)*REVERB_TIME), NUM_CYCLES_SAMPLE_IN=>log2(NUM_NOTES_GEN)+9)
  port map(
    -- Host side
    rst_n     	 => rst_n,
    clk       	 => clk,
    reverbStatus => reverbStatus,
    sampleRqt 	 => sampleRqt,
	sample_in 	 => sampleOutNoteGen,
	sample_out	 => sampleOut
  );

----------------------------------------------------------------------------------
-- CMD RECIEVER
--		Manage the behaviour with the commands
----------------------------------------------------------------------------------  

fsm:
process(rst_n,clk, cen, aviableCmd, cmdKeyboard, workingNotesGen, externInterfaceStatus)
	type states is (reciveCmd, waitTurnOff);
	type noteState_t is record
		currentNote   :   std_logic_vector(7 downto 0);
        OnOff   	  :   std_logic; -- High On, low Off
        fromBTMid     :   std_logic; -- High, note gen is on as a result of a cmd from external device
                                     -- Low, note gen is on as a result of a cmd from midi parser component
	end record;
	type keyboardState_t 	is array  ( 0 to NUM_NOTES_GEN-1 ) of noteState_t;
	type checkNotes_t		is 	array ( 0 to NUM_NOTES_GEN-1 ) of  unsigned(log2(NUM_NOTES_GEN)-1 downto 0);
	
	variable state      	:   states;
	variable keyboardState	:	keyboardState_t;
	
	variable foundCode		:	std_logic_vector(NUM_NOTES_GEN-1 downto 0);
	variable noteIndexOff	:   checkNotes_t;
	
	variable foundAviable	:	std_logic_vector(NUM_NOTES_GEN-1 downto 0);
	variable noteIndexOn	:   checkNotes_t;
    
    variable cleanExternCmds    :   boolean;
    variable cleanMidiCmds      :   boolean;
    
begin

	-- OutPut info
	for i in 0 to NUM_NOTES_GEN-1 loop
	   notesOnOff(i) <= keyboardState(i).OnOff;
	end loop;
		
	----------------------------------------------------------------------------
	-- "Combinationals Searchs" of note index to slect which note turn on/off --
	----------------------------------------------------------------------------
	--searchFirstAviableNoteGen
	foundAviable(0) :='0';
	noteIndexOn(0) := to_unsigned(0,log2(NUM_NOTES_GEN));
	if keyboardState(0).OnOff='0' then
		foundAviable(0) :='1';
	end if;
    for i in 1 to NUM_NOTES_GEN-1 loop
        foundAviable(i) := foundAviable(i-1);
        noteIndexOn(i) := noteIndexOn(i-1);
        if foundAviable(i-1)='0' and keyboardState(i).OnOff='0' then
            noteIndexOn(i) := unsigned( std_logic_vector(to_unsigned(i,log2(NUM_NOTES_GEN))) );
            foundAviable(i) := '1';
        end if;
    end loop;

	--searchIndexByNoteCode
	foundCode(0) :='0';
	noteIndexOff(0) := to_unsigned(0,log2(NUM_NOTES_GEN));
	if cmdKeyboard(11 downto 4)=keyboardState(0).currentNote then
		foundCode(0) :='1';
	end if;
	for i in 1 to NUM_NOTES_GEN-1 loop
		foundCode(i) := foundCode(i-1);
		noteIndexOff(i) := noteIndexOff(i-1);
		if foundCode(i-1)='0' and cmdKeyboard(11 downto 4)=keyboardState(i).currentNote then
			noteIndexOff(i) := to_unsigned(i,log2(NUM_NOTES_GEN));	
		    foundCode(i) := '1';
		end if;
	end loop;
	
	if rst_n='0' then
		keyboardState :=(others=>(X"00",'0','0'));
		state := reciveCmd;
		cleanExternCmds := false;
		cleanMidiCmds := false;
		-- Note params rst value
		regStartAddr               <= (others=>'0');
        regSustainStartOffsetAddr  <= (others=>'0');
        regSustainEndOffsetAddr    <= (others=>'0');
        regStepVal                 <= (others=>'0');
		keyboard_ack <='0';
		
    elsif rising_edge(clk) then
		keyboard_ack <='0';
		
        if cen='1' then
            -- Stop all notes if It's needed 
            if cleanMidiCmds or cleanExternCmds then
	           	keyboardState :=(others=>(X"00",'0','0'));
                cleanMidiCmds := false;
                cleanExternCmds := false;
            end if;
        
        else           
            -- To stop only the notes from MidiParser
            -- If some note on CMD have been recived from Midi parser, clean note gens     
            if cleanMidiCmds and midiParserOnOff='0' then
                for i in 0 to NUM_NOTES_GEN-1 loop
                    if keyboardState(i).fromBTMid='0' and keyboardState(i).OnOff='1' then
                        keyboardState(i) :=(X"00",'0','0');
                    end if;
                end loop;
                cleanMidiCmds := not cleanMidiCmds;
            end if;
            
            -- To stop only the notes from ExternInterface
            -- If some note on CMD have been recived from external device, clean note gens     
            if cleanExternCmds and externInterfaceStatus='0' then
                for i in 0 to NUM_NOTES_GEN-1 loop
                    if keyboardState(i).fromBTMid='1' and keyboardState(i).OnOff='1' then
                        keyboardState(i) :=(X"00",'0','0');
                    end if;
                end loop;
                cleanExternCmds := not cleanExternCmds;
            end if;
            
            case state is
                
                when reciveCmd =>
                    if aviableCmd='1' and 
                        ( (cmdKeyboard(14)='1' and externInterfaceStatus='1') or (cmdKeyboard(14)='0' and midiParserOnOff='1') ) then			
                            
                            -- Note On
                            -- Turn on a new generator if there is some generator not working (foundAviable(15)='1')
                            -- and if the note requested to turn on is not already on (foundCode='0')
                            if cmdKeyboard(13 downto 12)="10" and foundAviable(NUM_NOTES_GEN-1)='1' and foundCode(NUM_NOTES_GEN-1)='0' then
                                -- Note params setup
                                regStartAddr                 <= std_logic_vector(startAddrROM);
                                regSustainStartOffsetAddr    <= std_logic_vector(sustainStartOffsetAddrROM);
                                regSustainEndOffsetAddr      <= std_logic_vector(sustainEndOffsetAddrROM);
                                regStepVal                   <= std_logic_vector(stepValROM);
                                regNoteVelocity              <= cmdKeyboard(3 downto 0);
                                
                                keyboardState(to_integer(noteIndexOn(NUM_NOTES_GEN-1))) := (cmdKeyboard(11 downto 4),'1',cmdKeyboard(14));
                            
                                if not cleanExternCmds and cmdKeyboard(14)='1' then
                                    cleanExternCmds := not cleanExternCmds;
                                elsif not cleanMidiCmds and cmdKeyboard(14)='0' then
                                    cleanMidiCmds := not cleanMidiCmds;
                                end if;
                                
                                keyboard_ack <='1';
        
                            -- Note Off
                            -- Turn off a note if there is some generator working with that note code
                            elsif cmdKeyboard(13 downto 12)="01" and foundCode(NUM_NOTES_GEN-1)='1' then
                                keyboardState(to_integer(noteIndexOff(NUM_NOTES_GEN-1))).OnOff := '0';
                                state := waitTurnOff;
                            
                            -- This if the command has no effect on the keyboard state,
                            -- it's needed to keep consuming commands from the buffer
                            -- Example (turn on/off a note that is already on/off)
                            else
                               keyboard_ack <='1';
                            end if;                                     
                    end if;-- if aviableCmd='1' ( cmdKeyboard(14)='0' or (cmdKeyboard(14)='1' and externKeyboardOnOff='1') ) then 
                    
                -- Wait until the end of the release phase
                when waitTurnOff =>
                    if workingNotesGen(to_integer(noteIndexOff(NUM_NOTES_GEN-1)))='0' then                     
                        keyboardState(to_integer(noteIndexOff(NUM_NOTES_GEN-1))).currentNote := X"00";
                        state := reciveCmd;
                        keyboard_ack <='1';
                    end if;
                    
            end case;
            
       end if; --cen='0'
       
    end if;--rst_n/rising_edge
end process;
  
end Behavioral;
