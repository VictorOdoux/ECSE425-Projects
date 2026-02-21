library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache is
generic(
	ram_size : INTEGER := 32768
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
	signal data : t_cache_data := (others => (others => '0')); -- tag is 14-9, index is 8-4, offset is 3-0, 3-2 ig ignore last 2
	signal info : t_cache_info := (others => (others => '0')); -- valid bit 7, dirty bit 6, tag 5-0
	
	type t_state is (main, memwrite, memread, transition); 
	signal state: t_state; 
	signal pend_is_write : std_logic := '0';
	signal pend_addr15   : std_logic_vector(14 downto 0) := (others => '0');
	signal pend_wdata    : std_logic_vector(31 downto 0) := (others => '0');

	signal pend_index    : integer range 0 to 31 := 0;
	signal pend_offset   : integer range 0 to 3  := 0;
	signal pend_tag      : std_logic_vector(5 downto 0) := (others => '0');

	signal base_refill_addr : integer range 0 to ram_size-1 := 0; -- new block base (aligned 16B)
	signal base_evict_addr  : integer range 0 to ram_size-1 := 0; -- old block base (aligned 16B)

	signal refill_buf : std_logic_vector(127 downto 0) := (others => '0');
	signal count_reg : integer range 0 to 15 := 0;
	signal rd_issued : std_logic := '0';
	signal wr_issued : std_logic := '0';

begin

-- make circuits here

	cache_process : process(clock) 
		variable index : integer range 0 to 31; 
		variable offset : integer range 0 to 3; 
		variable address : integer range 0 to ram_size - 1; -- forgot to add this lol
		variable tmp15 : std_logic_vector(14 downto 0);
		variable tmp_line : std_logic_vector(127 downto 0);
	
	begin
		if (rising_edge(clock)) then
			if (reset = '1') then
				state <= main; 
				-- clear everything to 0
				data <= (others => (others => '0'));
				info <= (others => (others => '0'));
				
				s_waitrequest <= '1'; 
				
				m_addr <= 0; -- integer
				m_read <= '0'; 
				m_write <= '0'; 
				
				s_readdata <= (others => '0'); -- this format for std logic vectors
				m_writedata <= (others => '0'); 
				pend_is_write <= '0';
				pend_addr15 <= (others => '0');
				pend_wdata <= (others => '0');
				pend_index <= 0;
				pend_offset <= 0;
				pend_tag <= (others => '0');
				base_refill_addr <= 0;
				base_evict_addr <= 0;
				refill_buf <= (others => '0');
				count_reg <= 0;
				rd_issued <= '0';
				wr_issued <= '0';

			else -- reset != 1
				case state is
					when main => 
						m_read <= '0';
						m_write <= '0';
						s_waitrequest <= '1';
						if (s_write = '1') then
							index := to_integer(unsigned(s_addr(8 downto 4))); 
							-- s_addr is std logic vec so need to convert in two steps
							
							if (info(index)(5 downto 0) = s_addr(14 downto 9) and info(index)(7) = '1') then
								-- write hit b/c tag matches and valid bit = 1
								offset := to_integer(unsigned(s_addr(3 downto 2))); 

								data(index)(offset * 32 + 31 downto offset * 32) <= s_writedata; -- overwrite that word
								info(index)(6) <= '1'; -- dirty bit
								s_waitrequest <= '0'; -- release CPU
								state <= transition; 

							else
								-- decide whether to go to memread or memwrite
								pend_is_write <= '1';
								pend_addr15   <= s_addr(14 downto 0);
								pend_wdata    <= s_writedata;
								pend_index    <= index;
								pend_offset   <= to_integer(unsigned(s_addr(3 downto 2)));
								pend_tag      <= s_addr(14 downto 9);
								tmp15 := s_addr(14 downto 4) & "0000";
								address := to_integer(unsigned(tmp15));
								base_refill_addr <= address;

								if (info(index)(7) = '1' and info(index)(6) = '1') then
									-- line valid and dirty, must evict
									tmp15 := info(index)(5 downto 0) & s_addr(8 downto 4) & "0000";
									address := to_integer(unsigned(tmp15));
									base_evict_addr <= address;
									count_reg <= 0;
									wr_issued <= '0';
                                    rd_issued <= '0';
									state <= memwrite; 
									
								else 
									-- not dirty, just fetch directly
									count_reg <= 0;
									refill_buf <= (others => '0');
									rd_issued <= '0';
                                    wr_issued <= '0';
									state <= memread; 
								end if; 
							end if; 
						elsif (s_read = '1') then
							index := to_integer(unsigned(s_addr(8 downto 4)));
							
							if (info(index)(7) = '1' and info(index)(5 downto 0) = s_addr(14 downto 9)) then
								-- read hit
								offset := to_integer(unsigned(s_addr(3 downto 2))); 
								s_readdata <= data(index)((offset * 32 + 31) downto (offset * 32)); -- extract word and return
								s_waitrequest <= '0'; -- release cpu same as before
								state <= transition; 
							else 
								-- read miss
								pend_is_write <= '0';
								pend_addr15   <= s_addr(14 downto 0);
								pend_wdata    <= (others => '0');
								pend_index    <= index;
								pend_offset   <= to_integer(unsigned(s_addr(3 downto 2)));
								pend_tag      <= s_addr(14 downto 9);

								tmp15 := s_addr(14 downto 4) & "0000";
								address := to_integer(unsigned(tmp15));
								base_refill_addr <= address;

								if (info(index)(7) = '1' and info(index)(6) = '1') then 
									-- similar to write miss, line dirty so memwrite
									tmp15 := info(index)(5 downto 0) & s_addr(8 downto 4) & "0000";
									address := to_integer(unsigned(tmp15));
									base_evict_addr <= address;
								    count_reg <= 0;
									wr_issued <= '0';
                                    rd_issued <= '0';
									state <= memwrite;
								
								else 
									-- not dirty, so just fetch directly
									count_reg <= 0;
									refill_buf <= (others => '0');
									rd_issued <= '0';
                                    wr_issued <= '0';
									state <= memread;
								end if; 
							end if; 
						end if; 
					
					when memwrite => 
						m_read <= '0';

                        if (wr_issued = '0') then
                            m_write <= '1';
                            m_addr <= base_evict_addr + count_reg;
                            m_writedata <= data(pend_index)(count_reg*8 + 7 downto count_reg*8);
                            wr_issued <= '1';
                        else
                            m_write <= '0';
                            m_addr <= base_evict_addr + count_reg;
                            m_writedata <= data(pend_index)(count_reg*8 + 7 downto count_reg*8);

                            if (m_waitrequest = '0') then
                                if (count_reg = 15) then
                                    m_write <= '0';
                                    wr_issued <= '0';

                                    count_reg <= 0;
                                    info(pend_index)(6) <= '0';      
                                    refill_buf <= (others => '0');

                                    rd_issued <= '0';
									m_read <= '0';
									state <= memread;
                                else
                                    m_write <= '0';
                                    wr_issued <= '0';
                                    count_reg <= count_reg + 1;
                                end if;
                            end if;
                        end if;
							
					when memread =>
    					m_write <= '0';

					    if (rd_issued = '0') then
					        m_read <= '1';
					        m_addr <= base_refill_addr + count_reg;
					        rd_issued <= '1';
					    else
					        m_read <= '0';
					        m_addr <= base_refill_addr + count_reg;
					
					        if (m_waitrequest = '0') then
					            if (count_reg = 15) then
					                tmp_line := refill_buf;
					                tmp_line(15*8 + 7 downto 15*8) := m_readdata;
					
					                m_read <= '0';
					                rd_issued <= '0';
					
					                data(pend_index) <= tmp_line;
					                info(pend_index)(7) <= '1';
					                info(pend_index)(6) <= '0';
					                info(pend_index)(5 downto 0) <= pend_tag;
					
					                if (pend_is_write = '1') then
					                    tmp_line(pend_offset*32 + 31 downto pend_offset*32) := pend_wdata;
					                    data(pend_index) <= tmp_line;
					                    info(pend_index)(6) <= '1';
					                else
					                    s_readdata <= tmp_line(pend_offset*32 + 31 downto pend_offset*32);
					                end if;
					
					                s_waitrequest <= '0';
					                state <= transition;
					                count_reg <= 0;
					
					            else
					                refill_buf(count_reg*8 + 7 downto count_reg*8) <= m_readdata;
					
					                m_read <= '0';
					                rd_issued <= '0';
					                count_reg <= count_reg + 1;
					            end if;
					        end if;
					    end if;
							
					when transition => 
						s_waitrequest <= '1';
						m_read <= '0';
						m_write <= '0';
						state <= main;
						
					when others => 
						state <= main;
						
				end case;
			end if; -- if reset
		end if; -- if clock
	end process; 
end arch;
