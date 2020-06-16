----------------------------------------------------------------------------------
-- Company: fdi UCM Madrid
-- Engineer: Fernando Candelario Herrero, 
--			 Borja
-- 
-- Create Date: 24.01.2020 10:51:30
-- Design Name: 
-- Module Name: Ram2Ddr - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 2.5
-- Additional Comments:
--		Wirte 2B read 16B.
--		For write addr represet 2B.
--		For read addr represet 16B, the 3 last bits of the addr are not used.
-- 
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity Ram2Ddr is
   port (
      -- Common
      clk_200MHz_i         : in    std_logic; -- 200 MHz system clock
      rstn_i               : in    std_logic; -- active low system reset
      ui_clk_o             : out   std_logic;

      -- RAM interface
      ram_a                : in    std_logic_vector(25 downto 0); -- Mem addr is stable in the whole transaction
      ram_dq_i             : in    std_logic_vector(15 downto 0);
      ram_dq_o			   : out   std_logic_vector(127 downto 0); -- Read all the 128 bits
      ram_cen              : in    std_logic;
      ram_oen              : in    std_logic;
      ram_wen              : in    std_logic;
      ram_ack              : out   std_logic;
	  
      -- DDR2 interface
      ddr2_addr            : out   std_logic_vector(12 downto 0);
      ddr2_ba              : out   std_logic_vector(2 downto 0);
      ddr2_ras_n           : out   std_logic;
      ddr2_cas_n           : out   std_logic;
      ddr2_we_n            : out   std_logic;
      ddr2_ck_p            : out   std_logic_vector(0 downto 0);
      ddr2_ck_n            : out   std_logic_vector(0 downto 0);
      ddr2_cke             : out   std_logic_vector(0 downto 0);
      ddr2_cs_n            : out   std_logic_vector(0 downto 0);
      ddr2_odt             : out   std_logic_vector(0 downto 0);
      ddr2_dq              : inout std_logic_vector(15 downto 0);
      ddr2_dm              : out std_logic_vector(1 downto 0);
      ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
      ddr2_dqs_n           : inout std_logic_vector(1 downto 0)
   );
   
-- Attributes for debug
--    attribute   dont_touch    :   string;
--    attribute   dont_touch  of  Ram2Ddr  :   entity  is  "true";   
end Ram2Ddr;

architecture syn of Ram2Ddr is

------------------------------------------------------------------------
-- Component Declarations
------------------------------------------------------------------------
component ddr
port (
   -- Inouts
   ddr2_dq              : inout std_logic_vector(15 downto 0);
   ddr2_dqs_p           : inout std_logic_vector(1 downto 0);
   ddr2_dqs_n           : inout std_logic_vector(1 downto 0);
   -- Outputs
   ddr2_addr            : out   std_logic_vector(12 downto 0);
   ddr2_ba              : out   std_logic_vector(2 downto 0);
   ddr2_ras_n           : out   std_logic;
   ddr2_cas_n           : out   std_logic;
   ddr2_we_n            : out   std_logic;
   ddr2_ck_p            : out   std_logic_vector(0 downto 0);
   ddr2_ck_n            : out   std_logic_vector(0 downto 0);
   ddr2_cke             : out   std_logic_vector(0 downto 0);
   ddr2_cs_n            : out   std_logic_vector(0 downto 0);
   ddr2_odt             : out   std_logic_vector(0 downto 0);
   ddr2_dm              : out 	std_logic_vector(1 downto 0);
   -- Inputs
   sys_clk_i            : in    std_logic;
   sys_rst              : in    std_logic;
   -- user interface signals
   app_addr             : in    std_logic_vector(26 downto 0);
   app_cmd              : in    std_logic_vector(2 downto 0);
   app_en               : in    std_logic;
   app_wdf_data         : in    std_logic_vector(127 downto 0);
   app_wdf_end          : in    std_logic;
   app_wdf_mask         : in    std_logic_vector(15 downto 0);
   app_wdf_wren         : in    std_logic;
   app_rd_data          : out   std_logic_vector(127 downto 0);
   app_rd_data_end      : out   std_logic;
   app_rd_data_valid    : out   std_logic;
   app_rdy              : out   std_logic;
   app_wdf_rdy          : out   std_logic;
   app_sr_req           : in    std_logic;
   app_sr_active        : out   std_logic;
   app_ref_req          : in    std_logic;
   app_ref_ack          : out   std_logic;
   app_zq_req           : in    std_logic;
   app_zq_ack           : out   std_logic;
   ui_clk               : out   std_logic;
   ui_clk_sync_rst      : out   std_logic;
   init_calib_complete  : out   std_logic);
end component;

type states is (idle,
                send_data,
                set_cmd,
                wait_ack);

------------------------------------------------------------------------
-- Constant Declarations
------------------------------------------------------------------------
-- ddr commands
constant CMD_WRITE         : std_logic_vector(2 downto 0) := "000";
constant CMD_READ          : std_logic_vector(2 downto 0) := "001";

------------------------------------------------------------------------
-- Signal Declarations
------------------------------------------------------------------------
-- state machine
signal state      : states; 

-- global signals
signal mem_ui_clk          : std_logic; 
signal mem_ui_rst          : std_logic;
signal rst                 : std_logic;
signal rstn                : std_logic;
signal sreg                : std_logic_vector(1 downto 0);

-- ram internal signals
signal ram_oen_int         : std_logic;
signal ram_wen_int         : std_logic;

-- ddr user interface signals
signal mem_addr            : std_logic_vector(26 downto 0); -- address for current request
signal mem_cmd             : std_logic_vector(2 downto 0); -- command for current request
signal mem_en              : std_logic; -- active-high strobe for 'cmd' and 'addr'
signal mem_rdy             : std_logic;
signal mem_wdf_rdy         : std_logic; -- write data FIFO is ready to receive data (wdf_rdy = 1 & wdf_wren = 1)
signal mem_wdf_data        : std_logic_vector(127 downto 0);
signal mem_wdf_end         : std_logic; -- active-high last 'wdf_data'
signal mem_wdf_mask        : std_logic_vector(15 downto 0);
signal mem_wdf_wren        : std_logic;
signal mem_rd_data         : std_logic_vector(127 downto 0);
signal mem_rd_data_end     : std_logic; -- active-high last 'rd_data'
signal mem_rd_data_valid   : std_logic; -- active-high 'rd_data' valid
signal calib_complete      : std_logic; -- active-high calibration complete


begin
   
  ui_clk_o <= mem_ui_clk;
  rstn <= rstn_i;

  Inst_DDR: ddr
  port map (
    ddr2_dq              => ddr2_dq,
    ddr2_dm              => ddr2_dm,
    ddr2_dqs_p           => ddr2_dqs_p,
    ddr2_dqs_n           => ddr2_dqs_n,
    ddr2_addr            => ddr2_addr,
    ddr2_ba              => ddr2_ba,
    ddr2_ras_n           => ddr2_ras_n,
    ddr2_cas_n           => ddr2_cas_n,
    ddr2_we_n            => ddr2_we_n,
    ddr2_ck_p            => ddr2_ck_p,
    ddr2_ck_n            => ddr2_ck_n,
    ddr2_cke             => ddr2_cke,
    ddr2_cs_n            => ddr2_cs_n,
    ddr2_odt             => ddr2_odt,
    -- Inputs
    sys_clk_i            => clk_200MHz_i,
    sys_rst              => rstn,
    -- user interface signals
    app_addr             => mem_addr,
    app_cmd              => mem_cmd,
    app_en               => mem_en,
    app_wdf_data         => mem_wdf_data,
    app_wdf_end          => mem_wdf_end,
    app_wdf_mask         => mem_wdf_mask,
    app_wdf_wren         => mem_wdf_wren,
    app_rd_data          => mem_rd_data,
    app_rd_data_end      => mem_rd_data_end,
    app_rd_data_valid    => mem_rd_data_valid,
    app_rdy              => mem_rdy,
    app_wdf_rdy          => mem_wdf_rdy,
    app_sr_req           => '0',
    app_sr_active        => open,
    app_ref_req          => '0',
    app_ref_ack          => open,
    app_zq_req           => '0',
    app_zq_ack           => open,
    ui_clk               => mem_ui_clk,
    ui_clk_sync_rst      => mem_ui_rst,
    init_calib_complete  => calib_complete);


------------------------------------------------------------------------
-- Decoding the least significant 3 bits of the address and creating
-- accordingly the 'mem_wdf_mask'
------------------------------------------------------------------------

   WR_DATA_MSK: process(mem_ui_clk)
   begin
      if rising_edge(mem_ui_clk) then
         if  state = idle  and (ram_wen ='0' or ram_oen = '0' )then
            case(ram_a(2 downto 0)) is
               when "000" =>
                     mem_wdf_mask <= "1111111111111100";

               when "001" => 
                     mem_wdf_mask <= "1111111111110011";
                     
               when "010" => 
                     mem_wdf_mask <= "1111111111001111";
                     
               when "011" => 
                    mem_wdf_mask <= "1111111100111111";

               when "100" =>
                     mem_wdf_mask <= "1111110011111111";
                     
               when "101" =>
                     mem_wdf_mask <= "1111001111111111";
                     
               when "110" =>
                     mem_wdf_mask <= "1100111111111111";
                     
               when "111" =>
                     mem_wdf_mask <= "0011111111111111";
                     
               when others => null;
               
            end case;
         end if;
      end if;
   end process WR_DATA_MSK;


  state_change : process(mem_ui_rst, mem_ui_clk)
  begin
    if mem_ui_rst = '1' then
      state <= idle;
      
    elsif rising_edge(mem_ui_clk) then
      case state is
         
         -- If calibration is done successfully and CEN is
         -- deasserted then start a new transaction
         when idle =>
            if ram_cen = '0' and calib_complete = '1' then
              if ram_wen = '0' then
                 state <= send_data;
              elsif ram_oen = '0' then
                 state <= set_cmd;
              end if;
            end if;
            
         -- In a write transaction the data it written first
         -- giving higher priority to 'mem_wdf_rdy' frag over
         -- 'mem_rdy'
         when send_data =>
            if mem_wdf_rdy = '1' then
               state <= set_cmd;
            end if;
         
         -- Sending the read command and wait for the 'mem_rdy'
         -- frag to be asserted (in case it's not)
         -- Sending the write command after the data has been
         -- written to the controller FIFO and wait ro the
         -- 'mem_rdy' frag to be asserted (in case it's not)
         when set_cmd =>
            if mem_rdy = '1' then
               state <= wait_ack;
            end if;
         
         -- After sending all the control signals and data, we
         -- wait
         when wait_ack =>
            if (mem_rd_data_valid = '1' and mem_rd_data_end = '1') or -- Ack when reading
               (ram_wen_int = '0') then                               -- Ack when writing
              state <= idle;
            end if;


         when others =>
           state <= idle;            
      end case;
	  
    end if; --rising_edge(clk)
  end process;

-------------------------------------------------------------------------
  ram_access : process (state, mem_ui_rst, mem_ui_clk,ram_wen_int,ram_oen_int) 
  begin
    mem_wdf_wren <= '0';
    mem_wdf_end <= '0';
    
    mem_en <= '0';
    mem_cmd <= (others => '0');
        
    
    case state is
      when idle =>
      when send_data =>
        mem_wdf_wren <= '1';
        mem_wdf_end <= '1';
      when set_cmd =>
        if ram_wen_int = '0' then
          mem_en <= '1';
          mem_cmd <= CMD_WRITE;
        elsif ram_oen_int = '0' then
          mem_en <= '1';
          mem_cmd <= CMD_READ;
        end if;
      when wait_ack =>
      when others =>
    end case;
    
    if mem_ui_rst = '1' then
      mem_wdf_data <= (others=>'0');
      mem_addr <= (others=>'0');
      ram_dq_o <= (others=>'0');
      
      ram_oen_int <= '1';
      ram_wen_int <= '1';
      
      ram_ack <= '0';
    elsif rising_edge(mem_ui_clk) then
      ram_ack <= '0';
      
      case state is
        when idle =>
          
          mem_addr <= ram_a(25 downto 3) & "0000";
          mem_wdf_data <= ram_dq_i & ram_dq_i & ram_dq_i
                          & ram_dq_i & ram_dq_i & ram_dq_i
                          & ram_dq_i & ram_dq_i;
          
          ram_oen_int <= ram_oen;
          ram_wen_int <= ram_wen;
        when send_data =>
        when set_cmd =>
        when wait_ack =>
          if (mem_rd_data_valid = '1' and mem_rd_data_end = '1') or  -- Ack when reading
             (ram_wen_int = '0') then                                -- Ack when writing
            ram_ack <= '1';
          end if;
          
          if mem_rd_data_valid = '1' and mem_rd_data_end = '1' then
            ram_dq_o <= mem_rd_data;
          end if;
       
        when others =>
      end case; -- state
    
    end if; -- rst/rising_edge
  end process;
   
end syn;
