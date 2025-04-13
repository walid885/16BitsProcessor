library ieee;
use ieee.std_logic_1164.all;

entity control is
  port ( clk : in  std_logic;
         rst : in  std_logic;

         status     : in  std_logic_vector(3 downto 0);
         instr_cond : in  std_logic_vector(3 downto 0);
         instr_op   : in  std_logic_vector(3 downto 0);
         instr_updt : in  std_logic;

         instr_ce  : out std_logic;
         status_ce : out std_logic;
         acc_ce    : out std_logic;
         pc_ce     : out std_logic;
         rpc_ce    : out std_logic;
         rx_ce     : out std_logic;

         ram_we : out std_logic;

         sel_ram_addr : out std_logic;
         sel_op1      : out std_logic;
         sel_rf_din   : out std_logic_vector(1 downto 0) );
end entity;

architecture arch of control is
  type state is (st_fetch1, st_fetch2, st_decode, st_exec, st_store);

  signal state_0 : state;
  signal state_r : state := st_fetch1;
  
  -- Signal to determine if instruction should be executed based on condition code
  signal execute_instr : std_logic;
begin

  -- State machine (FSM) transition logic
  state_0 <= st_fetch2 when state_r = st_fetch1 else
             st_decode when state_r = st_fetch2 else
             st_exec   when state_r = st_decode else
             st_store  when state_r = st_exec   else
             st_fetch1 when state_r = st_store  else
             state_r;

  -- FSM state register with synchronous reset
  process(clk, rst)
  begin
    if rst = '1' then
      state_r <= st_fetch1;
    elsif rising_edge(clk) then
      state_r <= state_0;
    end if;
  end process;

  -- Condition execution evaluation based on status and instr_cond
  execute_instr <= '1' when (instr_cond = "0000") or                        -- Always (T)
                         (instr_cond = "0001" and status = "0000") or       -- False (F)
                         (instr_cond = "0010" and status(3) = '1') or       -- Zero (Z)
                         (instr_cond = "0011" and status(3) = '0') or       -- Not Zero (NZ)
                         (instr_cond = "0100" and status(3) = '0' and status(2) = '0') or -- Positive (P)
                         (instr_cond = "0101" and status(2) = '1') or       -- Negative (N)
                         (instr_cond = "0110" and status(1) = '1') or       -- Carry (C)
                         (instr_cond = "0111" and status(1) = '0') or       -- Not Carry (NC)
                         (instr_cond = "1000" and status(0) = '1') or       -- Overflow (V)
                         (instr_cond = "1001" and status(0) = '0') or       -- Not Overflow (NV)
                         (instr_cond = "1010" and (status(2) = '1' or status(3) = '1')) or -- Less or Equal (LE)
                         (instr_cond = "1011" and status(2) = '0' and status(3) = '0')    -- Greater (G)
                  else '0';

  -- Control signals generation based on current state and instruction
  process(state_r, execute_instr, instr_op, instr_updt)
  begin
    -- Default assignments
    instr_ce     <= '0';
    status_ce    <= '0';
    acc_ce       <= '0';
    pc_ce        <= '0';
    rpc_ce       <= '0';
    rx_ce        <= '0';
    ram_we       <= '0';
    sel_ram_addr <= '0';
    sel_op1      <= '0';
    sel_rf_din   <= "00";
    
    case state_r is
      when st_fetch1 =>
        -- No control signals active, preparing to fetch instruction
        null;
        
      when st_fetch2 =>
        -- Enable instruction register to store fetched instruction
        instr_ce <= '1';
        
      when st_decode =>
        -- Set operand selection based on instruction
        if (instr_op = "1100" or instr_op = "1101") then  -- CAL and JMP instructions
          sel_op1 <= '1';  -- Select PC as operand 1
        else
          sel_op1 <= '0';  -- Select accumulator as operand 1
        end if;
        
      when st_exec =>
        if execute_instr = '1' then
          -- If instruction is to be executed
          if instr_op = "1111" then  -- RET instruction
            rpc_ce <= '1';  -- Enable RPC for return
          elsif instr_op = "1000" then  -- LDR instruction
            pc_ce <= '1';
            sel_ram_addr <= '1';  -- Memory address from operand 2
            sel_rf_din <= "10";  -- Increment PC
          elsif instr_op = "1001" then  -- STR instruction
            pc_ce <= '1';
            ram_we <= '1';  -- Write to memory
            sel_ram_addr <= '1';  -- Memory address from operand 2
            sel_rf_din <= "10";  -- Increment PC
          elsif instr_op = "1100" or instr_op = "1101" or instr_op = "1110" then  -- CAL, JMP, BRA instructions
            -- No PC increment for these instructions
            null;
          else
            -- ALU operations with status update if needed
            pc_ce <= '1';  -- Increment PC
            sel_rf_din <= "10";  -- Select incremented PC for register file input
            if instr_updt = '1' then
              status_ce <= '1';  -- Update status register if updt flag is set
            end if;
          end if;
        else
          -- If condition not met, just increment PC
          pc_ce <= '1';
          sel_rf_din <= "10";  -- Select incremented PC for register file input
        end if;
        
      when st_store =>
        if execute_instr = '1' then
          if instr_op = "1011" then  -- MTR instruction
            rx_ce <= '1';  -- Enable register file write for MTR
            sel_rf_din <= "00";  -- ALU result to register
          elsif instr_op = "1000" then  -- LDR instruction
            acc_ce <= '1';  -- Enable accumulator for LDR
            sel_rf_din <= "01";  -- Memory data to register
          elsif instr_op = "1001" then  -- STR instruction
            -- Nothing to do, memory write already done in exec
            null;
          elsif instr_op = "1100" or instr_op = "1101" or instr_op = "1110" or instr_op = "1111" then
            -- For control flow instructions (CAL, JMP, BRA, RET), continue incrementing PC
            pc_ce <= '1';
            sel_rf_din <= "00";  -- ALU result to register (new PC value)
          elsif instr_op /= "1001" and instr_op /= "1011" then  -- Not STR or MTR
            -- ALU operations store result in accumulator
            acc_ce <= '1';
            sel_rf_din <= "00";  -- ALU result to register
          end if;
        end if;
        
    end case;
  end process;
end architecture;