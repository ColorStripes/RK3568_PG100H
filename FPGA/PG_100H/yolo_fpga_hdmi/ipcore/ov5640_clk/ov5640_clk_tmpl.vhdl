-- Created by IP Generator (Version 2022.2-SP6.4 build 146967)
-- Instantiation Template
--
-- Insert the following codes into your VHDL file.
--   * Change the_instance_name to your own instance name.
--   * Change the net names in the port map.


COMPONENT ov5640_clk
  PORT (
    clkout0 : OUT STD_LOGIC;
    clkout1 : OUT STD_LOGIC;
    clkout2 : OUT STD_LOGIC;
    lock : OUT STD_LOGIC;
    clkin1 : IN STD_LOGIC
  );
END COMPONENT;


the_instance_name : ov5640_clk
  PORT MAP (
    clkout0 => clkout0,
    clkout1 => clkout1,
    clkout2 => clkout2,
    lock => lock,
    clkin1 => clkin1
  );
