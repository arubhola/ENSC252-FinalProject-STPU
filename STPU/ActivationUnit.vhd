LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
USE work.systolic_package.all; 

ENTITY ActivationUnit IS
GENERIC( matrixSize : UNSIGNED := "011" );
PORT( clock, reset, hard_reset, stall, data_start : IN STD_LOGIC;
		y_in0, y_in1, y_in2 : IN UNSIGNED(7 DOWNTO 0); -- there may be more inputs
		done : out STD_LOGIC;
		row0, row1, row2 : OUT bus_type);
END ActivationUnit;

ARCHITECTURE Behaviour OF ActivationUnit IS

COMPONENT StateCounter IS
GENERIC( maxState : UNSIGNED := "11"; wrapBackState : UNSIGNED := "00" );
PORT( clock, reset, enable : IN STD_LOGIC;
		state : out UNSIGNED(maxState'length-1 DOWNTO 0));
END COMPONENT;

SIGNAL sc_reset, sc_enable : STD_LOGIC;
SIGNAL timer : UNSIGNED(2 DOWNTO 0);
TYPE matrix_buffer_type IS ARRAY (0 to 2, 0 to 1) OF UNSIGNED(N-1 DOWNTO 0);
SIGNAL matrix_buffer : matrix_buffer_type;
BEGIN
sc_reset <= reset OR hard_reset;
sc_enable <= data_start AND NOT stall;
sc : StateCounter GENERIC MAP(maxState => matrixSize + 4, wrapBackState => matrixSize + 2)
PORT MAP(clock => clock, reset => sc_reset, enable => sc_enable, state => timer);

buf: FOR r IN 0 TO 2 GENERATE -- store the past 2 values in a cycling buffer
	matrix_buffer(r,0) <= matrix_buffer(r,1) WHEN rising_edge(clock) AND stall = '0';
END GENERATE;

PROCESS(clock) -- add the latest values into the buffer
BEGIN
IF(rising_edge(clock) AND stall = '0') THEN
	matrix_buffer(0,1) <= y_in0;
	matrix_buffer(1,1) <= y_in1;
	matrix_buffer(2,1) <= y_in2;
END IF;
END PROCESS;

PROCESS(clock, reset, hard_reset)
BEGIN
IF(reset = '1' OR hard_reset = '1') THEN
	done <= '0';
ELSIF(rising_edge(clock) AND stall = '0' AND data_start = '1') THEN
	done <= '0';
	-- depending on current state of timer, load data in the buffer and current value into an output row
	IF(timer = matrixSize + 2) THEN
		row0 <= (matrix_buffer(0,0), matrix_buffer(0,1), y_in0);
	ELSIF(timer = matrixSize + 3) THEN
		row1 <= (matrix_buffer(1,0), matrix_buffer(1,1), y_in1);
	ELSIF(timer = matrixSize + 4) THEN
		row2 <= (matrix_buffer(2,0), matrix_buffer(2,1), y_in2);
		done <= '1';
	END IF;
END IF;

END PROCESS;

END Behaviour;