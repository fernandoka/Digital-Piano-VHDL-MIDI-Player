----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Fernando Candelario Herrero
-- 
-- Create Date: 14.12.2019 20:22:30
-- Design Name: 
-- Module Name: ByteProvider - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.5
-- Additional Comments:
--		Mem addr refers to one sample.					 		
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ByteProvider is
  Port ( 
        rst_n           	:   in  std_logic;
        clk             	:   in  std_logic;
		addrInVal			:	in	std_logic_vector(26 downto 0); -- Byte addres
		byteRqt				:	in	std_logic; -- One cycle high to request a new byte
		goFirstRead         :   in  std_logic; -- Change state to first read
			
		byteAck				:	out	std_logic; -- One cycle high to notify the reception of a new byte
		nextByte        	:   out	std_logic_vector(7 downto 0);
				
		-- Mem arbitrator side
		dataIn     	        :	in	std_logic_vector(127 downto 0);
        memAckSend       	:	in	std_logic; -- One cycle high
		memAckResponse   	:	in	std_logic;
		addr_out         	:	out std_logic_vector(22 downto 0); 
		memSamplesSendRqt	:	out std_logic
		
  );
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  ByteProvider  :   entity  is  "true"; 
end ByteProvider;

architecture Behavioral of ByteProvider is

begin

fsm:
process(rst_n,clk,byteRqt,memAckResponse,goFirstRead)
    type states is (firstRead, serveBytes, waitCmdAck, getData);	
	variable   state		:	states;
	
	variable   regAddr     :   unsigned(22 downto 0);	
	variable   regData     :   std_logic_vector(127 downto 0);
	variable   readFlag    :   boolean;

begin
    
	addr_out <= std_logic_vector(regAddr);
    
	if rst_n='0' then
		state :=firstRead;
		regAddr :=(others=>'0');
		regData :=(others=>'0');
		readFlag :=false;
		byteAck <='0';
		memSamplesSendRqt <= '0';
		
    elsif rising_edge(clk) then
		byteAck <='0';

        if goFirstRead='1' and state/=firstRead then
            state :=firstRead;
        else
            case state is
            
                when firstRead=>
                    if byteRqt='1' then
                        regAddr := unsigned(addrInVal(26 downto 4));
                        memSamplesSendRqt <= '1';
                        readFlag :=true;
                        state := waitCmdAck;
                    end if;
                
                when serveBytes=>
                    if readFlag or byteRqt='1' then
                        if regAddr/=unsigned(addrInVal(26 downto 4)) then
                            regAddr := unsigned(addrInVal(26 downto 4));
                            memSamplesSendRqt <= '1';
                            readFlag :=true;
                            state := waitCmdAck;
                        else
                            byteAck <= '1';
                            readFlag :=false;
                            case addrInVal(3 downto 0) is
                                when X"0"=>
                                    nextByte <= regData(7 downto 0);
    
                                when X"1"=>
                                    nextByte <= regData(15 downto 8);
    
                                when X"2"=>
                                    nextByte <= regData(23 downto 16);
    
                                when X"3"=>
                                    nextByte <= regData(31 downto 24);
    
                                when X"4"=>
                                    nextByte <= regData(39 downto 32);
    
                                when X"5"=>
                                    nextByte <= regData(47 downto 40);
    
                                when X"6"=>
                                    nextByte <= regData(55 downto 48);
    
                                when X"7"=>
                                    nextByte <= regData(63 downto 56);								
    
                                when X"8"=>
                                    nextByte <= regData(71 downto 64);
    
                                when X"9"=>
                                    nextByte <= regData(79 downto 72);
    
                                when X"A"=>
                                    nextByte <= regData(87 downto 80);
    
                                when X"B"=>
                                    nextByte <= regData(95 downto 88);
    
                                when X"C"=>
                                    nextByte <= regData(103 downto 96);
    
                                when X"D"=>
                                    nextByte <= regData(111 downto 104);
    
                                when X"E"=>
                                    nextByte <= regData(119 downto 112);
    
                                when X"F"=>
                                    nextByte <= regData(127 downto 120);
                                
                                when others=>
                                    nextByte <= (others=>'0');
                            end case;
                            
                        end if;
                    end if; --byteRqt='1'
                
                when waitCmdAck=>
                    if memAckSend='1' then
                        memSamplesSendRqt <= '0';
                        state := getData;
                    end if;
        
                
                when getData =>
                    if memAckResponse='1' then
                        regData := dataIn;
                        state := serveBytes;
                    end if;
    
            end case;
	   end if;	
    end if;
end process;
  
end Behavioral;
