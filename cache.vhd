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
	signal data : t_cache_data; 
	signal info : t_cache_info; 
	
	type t_state is (main, memwrite, memread, transition); 
	signal state: t_state; 

begin

-- make circuits here

	cache_process : process(clock) 
		variable count : integer range 0 to 15; -- 16B when interacting with mem
		-- probably add to this
	
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
						-- stuff happens, probably check cache miss vs hit here
					
					when memwrite => 
						-- more stuff, send back to main when done
						
					when memread => 
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