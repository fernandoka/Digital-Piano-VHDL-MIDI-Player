----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 0.5
-- Comments:
--      Freq in Khz
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use WORK.MY_COMMON.ALL;


entity RgbLed is
  Generic(FREQ  :   in  natural);
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;
	fileOk 						: 	in 	std_logic;
    externInterfaceStatus 		: 	in 	std_logic;
    playSong                    : 	in 	std_logic;
	mainControllerStatus		:	in	std_logic_vector(4 downto 0);
	
	-- LD16 PWM output signals
	pwm1_red_o 					: 	out std_logic;
	pwm1_green_o 				: 	out std_logic;
	pwm1_blue_o 				: 	out std_logic;
	
	-- LD17 PWM output signals	
	pwm2_red_o 					: 	out std_logic;
	pwm2_green_o 				: 	out std_logic;
	pwm2_blue_o 				: 	out std_logic
	
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  RgbLed  :   entity  is  "true";  
end RgbLed;

architecture Behavioral of RgbLed is

	signal	red_1, green_1			:	std_logic_vector(7 downto 0);
	signal	red_2, green_2, blue_2	:	std_logic_vector(7 downto 0);

begin	

-- PWM generators for led 1:
   PwmRed_1: Pwm
   port map(
      rst_n    => rst_n,
      clk    => clk,
      data_i   => red_1,
      pwm_o    => pwm1_red_o);

   PwmGreen_1: Pwm
   port map(
      rst_n    => rst_n,
      clk    => clk,
      data_i   => green_1,
      pwm_o    => pwm1_green_o);
   
	pwm1_blue_o <= '0'; -- No use of colour blue

-- PWM generators for led 2:
   PwmRed_2: Pwm
   port map(
      rst_n    => rst_n,
      clk    => clk,
      data_i   => red_2,
      pwm_o    => pwm2_red_o);

   PwmGreen_2: Pwm
   port map(
      rst_n    => rst_n,
      clk    => clk,
      data_i   => green_2,
      pwm_o    => pwm2_green_o);
   
   PwmBlue_2: Pwm
   port map(
      rst_n    => rst_n,
      clk    => clk,
      data_i   => blue_2,
      pwm_o    => pwm2_blue_o);


process(rst_n, clk, externInterfaceStatus, playSong, fileOk)
    constant    MAX_LED_2           :   natural :=  FREQ*1000/2;
    constant    MAX_LED_1           :   natural :=  MAX_LED_2/2;
    
    variable    tempLed2            :    natural    range 0 to MAX_LED_2;
    variable    tempLed1            :    natural    range 0 to MAX_LED_1;
        
    variable    flagLed1, flagLed2  :    boolean;
    variable    auxR, auxG, auxB    :   std_logic_vector(7 downto 0);
    
begin
  
if rst_n='0' then
  red_1     <= (others=>'0');
  green_1    <= (others=>'0');
  red_2     <= (others=>'0');
  green_2    <= (others=>'0');
  blue_2    <= (others=>'0');
  tempLed2  := 0;
  tempLed1  := 0;
  flagLed1  := false;
  flagLed2  := false;
  
elsif rising_edge(clk) then
      
        -- Purple when externalKeyboard is enabled
        if externInterfaceStatus='1' then
            auxR := "00000111";
            auxG := (others=>'0');
            auxB := "00000111";
        -- Otherwise green
        else
            auxR := (others=>'0');
            auxG := "00000111";
            auxB := (others=>'0');
        end if;
          
        -- Bahaviour for mainControllerStatus signal
        case mainControllerStatus is
          -- Red when setup
          when "00001" =>
              red_2     <= "00000111";
              green_2    <= (others=>'0');
              blue_2    <= (others=>'0');
        
          when "00010" =>
              if tempLed2 < MAX_LED_2 then 
                  tempLed2 := tempLed2+1;
              else
                  flagLed2 := not flagLed2;
                  tempLed2 := 0;
              end if;
              
              green_2    <= (others=>'0');
              blue_2    <= (others=>'0');                
              if flagLed2 then
                  red_2     <= "00000111";
              else
                  red_2     <= (others=>'0');
              end if;
          
          --  Blinking when is playing a song
          when "00100" =>
            red_2     <= auxR;
            green_2   <= auxG;
            blue_2    <= auxB;
            
          when "01000" =>
              if tempLed2 < MAX_LED_2 then 
                  tempLed2 := tempLed2+1;
              else
                  flagLed2 := not flagLed2;
                  tempLed2 := 0;
              end if;
              
              
              if flagLed2 then
                red_2     <= auxR;
                green_2   <= auxG;
                blue_2    <= auxB;
              else
                red_2     <= (others=>'0');
                green_2   <= (others=>'0');
                blue_2    <= (others=>'0');
              end if;
              
          -- Blue when BL is active
          when "10000" =>
              if tempLed2 < MAX_LED_2 then 
                  tempLed2 := tempLed2+1;
              else
                  flagLed2 := not flagLed2;
                  tempLed2 := 0;
              end if;
              
              green_2    <= (others=>'0');                
              red_2     <= (others=>'0');
              if flagLed2 then
                  blue_2    <= "00000111";
              else
                  blue_2    <= (others=>'0');
              end if; 
              
            when others =>
                green_2    <= (others=>'0');                
                red_2     <= (others=>'0');
                blue_2    <= (others=>'0');
        end case;
        
        -- Bahaviour for fileOk signal        
        if playSong='1' then
            flagLed1 := not flagLed1;
            tempLed1 := 0;
        end if;
        
        if tempLed1 < MAX_LED_1 then 
            tempLed1 := tempLed1+1;
        else
            flagLed1 := not flagLed1;
        end if;

        if flagLed1 then
            if fileOk='1' then
              green_1  <= "00000111";
              red_1    <= (others=>'0');
            else
              green_1  <= (others=>'0');
              red_1    <= "00000111";
            end if;
        else
            green_1  <= (others=>'0');
            red_1    <= (others=>'0');
        end if; 
             
    end if; -- rst_n/rising_edge(clk)
end process;


end Behavioral;
