/*


-------------------------------------------------------------------------------
-- Arithmetic logic unit
--
-- Ports:
--   - op [in]  : 4-bit instruction opcode
--   - i1 [in]  : operand 1
--   - i2 [in]  : operand 2
--   - o  [out] : result
--   - st [out] : 4-bit status flags
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity alu is
  port ( op : in  std_logic_vector(3 downto 0);
         i1 : in  std_logic_vector(15 downto 0);
         i2 : in  std_logic_vector(15 downto 0);
         o  : out std_logic_vector(15 downto 0);
         st : out std_logic_vector(3 downto 0) );
end entity;

architecture arch of alu is
begin
end architecture;
*/




-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity alu is
  port ( op : in  std_logic_vector(3 downto 0);
         i1 : in  std_logic_vector(15 downto 0);
         i2 : in  std_logic_vector(15 downto 0);
         o  : out std_logic_vector(15 downto 0);
         st : out std_logic_vector(3 downto 0) );
end entity alu;

architecture rtl of alu is
  -- Status bits
  -- st(3) = Z (Zero)
  -- st(2) = N (Negative)
  -- st(1) = C (Carry)
  -- st(0) = V (Overflow)
  
  signal result : std_logic_vector(15 downto 0);
  signal zero_flag : std_logic;
  signal neg_flag : std_logic;
  signal carry_flag : std_logic;
  signal overflow_flag : std_logic;
  
begin
  process(op, i1, i2)
    variable temp_result : std_logic_vector(15 downto 0);
    variable temp_carry : std_logic;
    variable temp_overflow : std_logic;
    variable shift_amount : integer;
  begin
    -- Default values
    temp_result := (others => '0');
    temp_carry := '0';
    temp_overflow := '0';
    
    case op is
      -- AND
      when "0000" =>
        temp_result := i1 and i2;
      
      -- OR
      when "0001" =>
        temp_result := i1 or i2;
      
      -- XOR
      when "0010" =>
        temp_result := i1 xor i2;
      
      -- NOT
      when "0011" =>
        temp_result := not i1;
      
      -- ADD
      when "0100" =>
        temp_result := i1 + i2;
        
        -- Simple carry detection - carry occurs when sum is less than either operand
        if (temp_result < i1) or (temp_result < i2) then
          temp_carry := '1';
        end if;
        
        -- Overflow detection for signed addition
        -- Overflow occurs when both operands have same sign but result has different sign
        if ((i1(15) = '0' and i2(15) = '0' and temp_result(15) = '1') or
            (i1(15) = '1' and i2(15) = '1' and temp_result(15) = '0')) then
          temp_overflow := '1';
        end if;
      
      -- SUB
      when "0101" =>
        temp_result := i1 - i2;
        
        -- Carry for subtraction - set when no borrow needed (i1 >= i2)
        if i1 >= i2 then
          temp_carry := '1';
        end if;
        
        -- Overflow detection for signed subtraction
        -- Occurs when operands have different signs and result has sign of subtrahend
        if ((i1(15) = '0' and i2(15) = '1' and temp_result(15) = '1') or
            (i1(15) = '1' and i2(15) = '0' and temp_result(15) = '0')) then
          temp_overflow := '1';
        end if;
      
      -- LSL (Logical Shift Left)
      when "0110" =>
        -- Determine shift amount (positive = left, negative = right)
        if i2(15) = '0' then  -- Positive shift amount
          shift_amount := conv_integer(i2(4 downto 0));
          if shift_amount > 0 then
            if shift_amount >= 16 then
              -- If shift amount >= 16, result is 0
              temp_result := (others => '0');
              -- Carry is set if any bits in i1 were '1'
              for i in 0 to 15 loop
                if i1(i) = '1' then
                  temp_carry := '1';
                  exit;
                end if;
              end loop;
            else
              -- Check if the sign bit changes during shift
              if i1(15) /= i1(15 - shift_amount) then
                temp_overflow := '1';
              end if;
              
              -- Check if any bit shifted out is 1 for carry
              for i in 16-shift_amount to 15 loop
                if i < 16 and i >= 0 and i1(i) = '1' then
                  temp_carry := '1';
                end if;
              end loop;
              
              -- Perform shift left
              temp_result := i1(15-shift_amount downto 0) & (shift_amount-1 downto 0 => '0');
            end if;
          else
            temp_result := i1;  -- No shift
          end if;
        else  -- Negative shift amount (right)
          shift_amount := 16 - conv_integer(not i2(3 downto 0) + 1);
          
          if shift_amount > 0 and shift_amount < 16 then
            -- This will be a right shift
            temp_result := (shift_amount-1 downto 0 => '0') & i1(15 downto shift_amount);
            
            -- Set overflow if sign bit changes
            if i1(15) = '1' and temp_result(15) = '0' then
              temp_overflow := '1';
            end if;
          elsif shift_amount <= 0 then
            temp_result := (others => '0');
          else
            temp_result := i1;  -- No shift
          end if;
        end if;
      
      -- LSR (Logical Shift Right)
      when "0111" =>
        if i2(15) = '0' then  -- Positive shift amount
          shift_amount := conv_integer(i2(4 downto 0));
          
          if shift_amount > 0 then
            if shift_amount >= 16 then
              temp_result := (others => '0');
              -- Carry is set if any bits in i1 were '1'
              for i in 0 to 15 loop
                if i1(i) = '1' then
                  temp_carry := '1';
                  exit;
                end if;
              end loop;
            else
              -- Check if sign bit changes
              if i1(15) = '1' then
                temp_overflow := '1'; -- Sign bit changes from 1 to 0
              end if;
              
              -- Check if any bit shifted out is 1 for carry
              for i in 0 to shift_amount-1 loop
                if i < 16 and i >= 0 and i1(i) = '1' then
                  temp_carry := '1';
                end if;
              end loop;
              
              -- Perform shift right
              temp_result := (shift_amount-1 downto 0 => '0') & i1(15 downto shift_amount);
            end if;
          else
            temp_result := i1;  -- No shift
          end if;
        else  -- Negative shift amount (left)
          shift_amount := 16 - conv_integer(not i2(3 downto 0) + 1);
          
          if shift_amount > 0 and shift_amount < 16 then
            -- This will be a left shift
            -- Check if sign bit changes
            if i1(15) /= i1(15 - shift_amount) then
              temp_overflow := '1';
            end if;
            
            -- Check if any bit shifted out is 1 for carry
            for i in 16-shift_amount to 15 loop
              if i < 16 and i >= 0 and i1(i) = '1' then
                temp_carry := '1';
              end if;
            end loop;
            
            -- Perform shift left
            temp_result := i1(15-shift_amount downto 0) & (shift_amount-1 downto 0 => '0');
          elsif shift_amount <= 0 then
            temp_result := (others => '0');
          else
            temp_result := i1;  -- No shift
          end if;
        end if;
      
      -- MTA (Move to accumulator)
      when "1010" =>
        temp_result := i2;
      
      -- MTR (Move to register)
      when "1011" =>
        temp_result := i1;
      
      -- JRP (Jump Relative Positive)
      when "1100" =>
        if i1(15) = '0' then  -- If i1 is positive
          temp_result := i1 + i2;
        else
          temp_result := i2;  -- Just pass through i2
        end if;
      
      -- JRN (Jump Relative Negative)
      when "1101" =>
        if i1(15) = '1' then  -- If i1 is negative
          temp_result := i1 + i2;
        else
          temp_result := i2;  -- Just pass through i2
        end if;
      
      -- JPR (Jump to Register)
      when "1110" =>
        temp_result := i2;
      
      -- CAL (Call)
      when "1111" =>
        temp_result := i2;
      
      -- Unknown opcode
      when others =>
        temp_result := (others => '0');
    
    end case;
    
    -- Assign the result
    result <= temp_result;
    
    -- Set status flags
    carry_flag <= temp_carry;
    overflow_flag <= temp_overflow;
    
    -- Set Zero flag
    if temp_result = "0000000000000000" then
      zero_flag <= '1';
    else
      zero_flag <= '0';
    end if;
    
    -- Set Negative flag
    neg_flag <= temp_result(15);
    
  end process;
  
  -- Assign outputs
  o <= result;
  st <= zero_flag & neg_flag & carry_flag & overflow_flag;
  
end architecture rtl;
