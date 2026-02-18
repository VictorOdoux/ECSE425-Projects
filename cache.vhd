library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768;
);
port(
	clock : in std_logic;
	reset : in std_logic;
	
	-- Avalon interface --
	s_addr : in std_logic_vector (31 downto 0);
	s_read : in std_logic;
	s_readdata : out std_logic_vector (31 downto 0);
	s_write : in std_logic;
	s_writedata : in std_logic_vector (31 downto 0);
	s_waitrequest : out std_logic; 
    
	m_addr : out integer range 0 to ram_size-1;
	m_read : out std_logic;
	m_readdata : in std_logic_vector (7 downto 0);
	m_write : out std_logic;
	m_writedata : out std_logic_vector (7 downto 0);
	m_waitrequest : in std_logic
);
end cache;

architecture arch of cache is

-- declare signals here
	-- 32 bit addresses, cache data 128 bit blocks 
	type t_cache_data is array(31 downto 0) of std_logic_vector(127 downto 0); 
	
	-- 32 = 2^5, 5 index bits, 4 offset bits (2 of which ignored), so 15 lower bits - 5 - 4 = 6 tag bits
	-- cache info: 1 valid bit, 1 dirty bit, 6 tag bits
	type t_cache_info is array(31 downto 0) of std_logic_vector(7 downto 0); 
	signal data : t_cache_data; -- tag is 14-9, index is 8-4, offset is 3-0, 3-2 ig ignore last 2
	signal info : t_cache_info; -- valid bit 7, dirty bit 6, tag 5-0
	
	type t_state is (main, memwrite, memread, transition); 
	signal state: t_state; 

begin

-- make circuits here

	cache_process : process(clock) 
		variable count : integer range 0 to 15; -- 16B when interacting with mem
		variable index : integer range 0 to 31; 
		variable offset : integer range 0 to 3; 
	
	begin
		if (rising_edge(clock)) then
			if (reset = '1') then
				state <= main; 
				-- clear everything to 0
				if reset = '1' then 
					data <= (others => (others => '0'));
					info <= (others => (others => '0'));
				end if; 
				
				s_waitrequest <= '1'; 
				
				m_addr <= 0; -- integer
				m_read <= '0'; 
				m_write <= '0'; 
				
				s_readdata <= (others => '0'); -- this format for std logic vectors
				m_writedata <= (others => '0'); 
			else -- reset != 1
				case state is
					when main => 
						if (s_write = '1') then
							index := to_integer(unsigned(s_addr(8 downto 4))); 
							-- s_addr is std logic vec so need to convert in two steps
							
							if (info(index)(5 down to 0) = s_addr(14 downto 9) and info(index)(7) = '1') then
								-- write hit b/c tag matches and valid bit = 1
								offset := to_integer(unsigned(s_addr(3 downto 2))); 

								data(index)(offset * 32 + 31 downto offset * 32) <= s_writedata; -- overwrite that word
								info(index)(6) <= '1'; -- dirty bit
								s_waitrequest <= '0'; -- release CPU
								state <= transition; 

							else
								-- decide whether to go to memread or memwrite
								if (info(index)(7) = '1' and info(index)(6) = '1') then
									-- line valid and dirty, must evict
									m_write <= '1';
									m_read <= '0';
									count := 0;
									
									address := to_integer(unsigned(info(index)(5 downto 0)) & unsigned(s_addr(8 downto 4)) & to_unsigned(0,4)); 
									-- old tag, index, offset = 0
									m_addr <= address; 
									
									m_writedata <= data(index)(7 downto 0); 
									state <= memwrite; 
									
								else 
									-- not dirty, just fetch directly
									m_read <= '1'; 
									m_write <= '0'; 
									count := 0; 
									
									address := to_integer(unsigned(s_addr(14 downto 4)) & to_unsigned(0,4)); 
									m_addr <= address; 
									state <= memread; 
									
								end if; 

								
							end if; 
						elsif (s_read = '1') then
							-- more stuff
						end if; 
					
					when memwrite => 
						-- cache miss and line dirty
						-- if m_waitrequest = 0, m_write = 0
						-- if 16B written (count = 15), clear valid and dirty bit
						-- send back to main when done
						
					when memread => 
						-- cache miss and line clean
						-- if m_waitrequest = 0, store the m_readdata
						-- keep reading until count = 15
						-- after done, set valid, clear dirty bit, store tag tag
						-- also send back to main when done
					
					when transition => 
						-- reset waitrequest, return to main
						
					when others => 
						-- reset = 1 behavior? 
						
				end case;
			end if; -- if reset
		end if; -- if clock
	end process; 
end arch;