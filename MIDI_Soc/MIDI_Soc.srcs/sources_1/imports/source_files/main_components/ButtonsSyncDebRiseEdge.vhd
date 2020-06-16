----------------------------------------------------------------------------------
-- Engineer: 
-- 	Fernando Candelario Herrero
--
-- Revision 0.3
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use WORK.MY_COMMON.ALL;

entity ButtonsSyncDebRiseEdge is
  Generic(	FREQ	:	in	natural);
  Port(
    -- Host side
    rst_n                   	:	in	std_logic;  
    clk                     	:	in	std_logic;  
    btnc_i               		:	in	std_logic;
    btnu_i    					:	in	std_logic;
	btnl_i	              		:	in	std_logic;
    btnd_i                      :   in  std_logic;

	xRise_btnc             		:	out	std_logic;
	xRise_btnu             		:	out	std_logic;
	xRise_btnl             		:	out	std_logic;
    xRise_btnd             		:	out	std_logic

  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  ButtonsSyncDebRiseEdge  :   entity  is  "true";  
end ButtonsSyncDebRiseEdge;

architecture Behavioral of ButtonsSyncDebRiseEdge is

signal  btncSync, btncDeb   : std_logic;
signal  btnuSync, btnuDeb   : std_logic;
signal  btnlSync, btnlDeb   : std_logic;
signal  btndSync, btndDeb   : std_logic;

begin	

-- BTNC
  BTNC_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnc_i, xSync => btncSync );

  BTNC_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btncSync, xDeb => btncDeb );
    
  BTNC_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btncDeb, xFall => open, xRise => xRise_btnc );


-- BTNU
  BTNU_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnu_i, xSync => btnuSync );

  BTNU_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btnuSync, xDeb => btnuDeb );
    
  BTNU_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btnuDeb, xFall => open, xRise => xRise_btnu );

    

-- BTNL
  BTNL_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnl_i, xSync => btnlSync );

  BTNL_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btnlSync, xDeb => btnlDeb );
    
  BTNL_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btnlDeb, xFall => open, xRise => xRise_btnl ); 


-- BTND
  BTND_Synchronizer : synchronizer
    generic map ( STAGES => 2, INIT => '0' )
    port map ( rst_n => rst_n, clk => clk, x => btnd_i, xSync => btndSync );

  BTND_Debouncer : debouncer
    generic map ( FREQ => FREQ, XPOL => '0', BOUNCE => 50 )
    port map ( rst_n => rst_n, clk => clk, x => btndSync, xDeb => btndDeb );
    
  BTND_EdgeDetector : edgeDetector
    generic map ( XPOL => '1' )
    port map ( rst_n => rst_n, clk => clk, x => btndDeb, xFall => open, xRise => xRise_btnd ); 

        
end Behavioral;
