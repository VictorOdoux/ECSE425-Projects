library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cache_tb is
end cache_tb;

architecture behavior of cache_tb is

component cache is
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
end component;

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
	
-- test signals 
signal reset : std_logic := '0';
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal s_addr : std_logic_vector (31 downto 0);
signal s_read : std_logic;
signal s_readdata : std_logic_vector (31 downto 0);
signal s_write : std_logic;
signal s_writedata : std_logic_vector (31 downto 0);
signal s_waitrequest : std_logic;

signal m_addr : integer range 0 to 2147483647;
signal m_read : std_logic;
signal m_readdata : std_logic_vector (7 downto 0);
signal m_write : std_logic;
signal m_writedata : std_logic_vector (7 downto 0);
signal m_waitrequest : std_logic; 

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: cache 
port map(
    clock => clk,
    reset => reset,

    s_addr => s_addr,
    s_read => s_read,
    s_readdata => s_readdata,
    s_write => s_write,
    s_writedata => s_writedata,
    s_waitrequest => s_waitrequest,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest
);

MEM : memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);
				

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
-- put your tests here

-- This testbench's work is divided into two; Hongyin is responsible for writing the basic
-- procedures and tasks for the test, whereas Victor is responsible for writing the actual 
-- implementation of the test.

 -- rest procedure
procedure reset_procedure is
begin
	reset <= '1';
	s_read <= '0';
	s_write <= '0';
	s_addr <= (others => '0');
	s_writedata <= (others => '0');
		  
	wait until rising_edge(clk);
	wait until rising_edge(clk); --jthe extra waits are just in case the wait is not long enough for data to update

	reset <= '0';
	wait until rising_edge(clk);
end procedure;

	 
-- CPU transaction
procedure cpu_write_word(
	addr  : in std_logic_vector(31 downto 0);
	wdata : in std_logic_vector(31 downto 0)
) is
	begin
	while s_waitrequest /= '0' loop
        wait until rising_edge(clk);
    end loop;
	 
	s_addr <= addr;
	s_writedata <= wdata;
	s_write <= '1';
	s_read <= '0';

	wait until rising_edge(clk);
	s_write <= '0';
	while s_waitrequest /= '0' loop
        wait until rising_edge(clk);
    end loop;
end procedure;

-- CPU transaction: read word
procedure cpu_read_word(
	addr   : in std_logic_vector(31 downto 0);
	variable rdata : out std_logic_vector(31 downto 0)
) is
	begin
	while s_waitrequest /= '0' loop
        wait until rising_edge(clk);
    end loop;
	 
	s_addr <= addr;
	s_read <= '1';
	s_write <= '0';

	wait until rising_edge(clk);
	s_read <= '0';
	while s_waitrequest /= '0' loop
        wait until rising_edge(clk);
    end loop;
	rdata := s_readdata;
end procedure;

-- check equality
procedure check_equality(
	got : in std_logic_vector(31 downto 0);
	expected : in std_logic_vector(31 downto 0);
	msg: in string
	) is
	begin
	assert got = expected
	report "EXPECT FAIL: " & msg
	severity failure;
end procedure;

-- Expected word
function expected_word(byte_addr : integer) return std_logic_vector is
	variable b0, b1, b2, b3 : integer;
	variable w : std_logic_vector(31 downto 0);
begin
	b0 := byte_addr mod 256;
	b1 := (byte_addr + 1) mod 256;
	b2 := (byte_addr + 2) mod 256;
	b3 := (byte_addr + 3) mod 256;

	w( 7 downto  0) := std_logic_vector(to_unsigned(b0, 8));
	w(15 downto  8) := std_logic_vector(to_unsigned(b1, 8));
	w(23 downto 16) := std_logic_vector(to_unsigned(b2, 8));
	w(31 downto 24) := std_logic_vector(to_unsigned(b3, 8));
	return w;
end function;




variable x: std_logic_vector(31 downto 0);

begin
    reset_procedure;
    cpu_read_word(x"00000010", x);
    check_equality(x, expected_word(16), "smoke: read @0x10 should match initialized memory word");

    -- =========================================================
    -- ===================== SCENARIOS =========================
    -- =========================================================

    -- === Person B place-holder: begin ===

        ------------------------------------------------------------------------
    -- Person B: Test scenarios / sequences
    -- Uses Person A procedures exactly as written.
    ------------------------------------------------------------------------

    -- Address choices:
    -- index = addr[8:4]. Adding 0x200 changes tag but keeps index.
    -- We'll use A = 0x0010 (index=1) and B = 0x0210 (same index=1, different tag)
    -- Also use E = 0x0020 / F = 0x0220 (index=2) for clean-eviction path.
    -- And C = 0x0030 (index=3) for write-miss-allocate.

    -- ========== Scenario 1: read miss -> fill -> hit ==========
    cpu_read_word(x"00000010", x);
    check_equality(x, expected_word(16#010#), "S1a: read miss/fill @0x0010 returns init");

    cpu_read_word(x"00000010", x);
    check_equality(x, expected_word(16#010#), "S1b: read hit @0x0010 returns init");

    -- ========== Scenario 2: write hit -> dirty set -> read hit ==========
    -- Write word1 within same block: 0x0014
    cpu_write_word(x"00000014", x"A1A2A3A4");

    cpu_read_word(x"00000014", x);
    check_equality(x, x"A1A2A3A4", "S2: write hit then read hit @0x0014");

    -- ========== Scenario 3: conflict miss (same index, different tag) ==========
    -- Read conflicting address word1: 0x0214
    -- If tag compare is wrong, you might incorrectly get A1A2A3A4 here.
    cpu_read_word(x"00000214", x);
    check_equality(x, expected_word(16#214#), "S3: conflict miss @0x0214 returns init (tests tag compare)");

    -- ========== Scenario 4: dirty eviction -> verify write-back ==========
    -- After S3, the dirty line containing 0x0010..0x001F should have been evicted and written back.
    -- Reading 0x0014 again should retrieve A1A2A3A4 from memory (via refill).
    cpu_read_word(x"00000014", x);
    check_equality(x, x"A1A2A3A4", "S4: write-back persisted after dirty eviction @0x0014");

    -- ========== Scenario 5: clean eviction path ==========
    -- Fill E (clean), conflict with F (should evict clean, no writeback needed), then re-read E
    cpu_read_word(x"00000020", x);
    check_equality(x, expected_word(16#020#), "S5a: read miss/fill @0x0020");

    cpu_read_word(x"00000220", x);
    check_equality(x, expected_word(16#220#), "S5b: conflict miss (clean victim) @0x0220");

    cpu_read_word(x"00000020", x);
    check_equality(x, expected_word(16#020#), "S5c: re-read @0x0020 after clean eviction");

    -- ========== Scenario 6: write miss allocate into an invalid line ==========
    cpu_write_word(x"00000030", x"11223344");

    cpu_read_word(x"00000030", x);
    check_equality(x, x"11223344", "S6: write miss allocate then read hit @0x0030");

    -- ========== Scenario 7: read-after-write, same line different word ==========
    cpu_write_word(x"00000034", x"55667788");

    cpu_read_word(x"00000030", x);
    check_equality(x, x"11223344", "S7a: word0 preserved @0x0030");

    cpu_read_word(x"00000034", x);
    check_equality(x, x"55667788", "S7b: word1 updated @0x0034");

    -- ========== Scenario 8: reset corner case ==========
    -- Cache should clear its valid/dirty bits on reset; memory should NOT magically revert.
    -- Since 0x0030 writes were likely still only in cache (dirty but not evicted),
    -- after reset a read should return the original initialized memory contents.
    reset_procedure;

    cpu_read_word(x"00000030", x);
    check_equality(x, expected_word(16#030#), "S8: after reset, cache cleared; memory still init @0x0030 (no flush)");

    report "All Person-B scenarios passed." severity note;
    -- === Person B place-holder: end ===

    
    wait;
	 
end process;
	
end;