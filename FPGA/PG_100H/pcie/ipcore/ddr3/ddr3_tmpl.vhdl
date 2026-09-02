-- Created by IP Generator (Version 2022.2-SP6.4 build 146967)
-- Instantiation Template
--
-- Insert the following codes into your VHDL file.
--   * Change the_instance_name to your own instance name.
--   * Change the net names in the port map.


COMPONENT ddr3
  PORT (
    resetn : IN STD_LOGIC;
    core_clk : OUT STD_LOGIC;
    pll_lock : OUT STD_LOGIC;
    phy_pll_lock : OUT STD_LOGIC;
    gpll_lock : OUT STD_LOGIC;
    rst_gpll_lock : OUT STD_LOGIC;
    ddrphy_cpd_lock : OUT STD_LOGIC;
    ddr_init_done : OUT STD_LOGIC;
    axi_awaddr : IN STD_LOGIC_VECTOR(27 DOWNTO 0);
    axi_awuser_ap : IN STD_LOGIC;
    axi_awuser_id : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_awlen : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_awready : OUT STD_LOGIC;
    axi_awvalid : IN STD_LOGIC;
    axi_wdata : IN STD_LOGIC_VECTOR(127 DOWNTO 0);
    axi_wstrb : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    axi_wready : OUT STD_LOGIC;
    axi_wusero_id : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_wusero_last : OUT STD_LOGIC;
    axi_araddr : IN STD_LOGIC_VECTOR(27 DOWNTO 0);
    axi_aruser_ap : IN STD_LOGIC;
    axi_aruser_id : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_arlen : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_arready : OUT STD_LOGIC;
    axi_arvalid : IN STD_LOGIC;
    axi_rdata : OUT STD_LOGIC_VECTOR(127 DOWNTO 0);
    axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    axi_rlast : OUT STD_LOGIC;
    axi_rvalid : OUT STD_LOGIC;
    apb_clk : IN STD_LOGIC;
    apb_rst_n : IN STD_LOGIC;
    apb_sel : IN STD_LOGIC;
    apb_enable : IN STD_LOGIC;
    apb_addr : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    apb_write : IN STD_LOGIC;
    apb_ready : OUT STD_LOGIC;
    apb_wdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    apb_rdata : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    mem_cs_n : OUT STD_LOGIC;
    mem_rst_n : OUT STD_LOGIC;
    mem_ck : OUT STD_LOGIC;
    mem_ck_n : OUT STD_LOGIC;
    mem_cke : OUT STD_LOGIC;
    mem_ras_n : OUT STD_LOGIC;
    mem_cas_n : OUT STD_LOGIC;
    mem_we_n : OUT STD_LOGIC;
    mem_odt : OUT STD_LOGIC;
    mem_a : OUT STD_LOGIC_VECTOR(14 DOWNTO 0);
    mem_ba : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    mem_dqs : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    mem_dqs_n : INOUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    mem_dq : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    mem_dm : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    dbg_gate_start : IN STD_LOGIC;
    dbg_cpd_start : IN STD_LOGIC;
    dbg_ddrphy_rst_n : IN STD_LOGIC;
    dbg_gpll_scan_rst : IN STD_LOGIC;
    samp_position_dyn_adj : IN STD_LOGIC;
    init_samp_position_even : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    init_samp_position_odd : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    wrcal_position_dyn_adj : IN STD_LOGIC;
    init_wrcal_position : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
    force_read_clk_ctrl : IN STD_LOGIC;
    init_slip_step : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    init_read_clk_ctrl : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    debug_calib_ctrl : OUT STD_LOGIC_VECTOR(33 DOWNTO 0);
    dbg_slice_status : OUT STD_LOGIC_VECTOR(33 DOWNTO 0);
    dbg_slice_state : OUT STD_LOGIC_VECTOR(43 DOWNTO 0);
    debug_data : OUT STD_LOGIC_VECTOR(137 DOWNTO 0);
    dbg_dll_upd_state : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    debug_gpll_dps_phase : OUT STD_LOGIC_VECTOR(8 DOWNTO 0);
    dbg_rst_dps_state : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    dbg_tran_err_rst_cnt : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
    dbg_ddrphy_init_fail : OUT STD_LOGIC;
    debug_cpd_offset_adj : IN STD_LOGIC;
    debug_cpd_offset_dir : IN STD_LOGIC;
    debug_cpd_offset : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
    debug_dps_cnt_dir0 : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    debug_dps_cnt_dir1 : OUT STD_LOGIC_VECTOR(9 DOWNTO 0);
    ck_dly_en : IN STD_LOGIC;
    init_ck_dly_step : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    ck_dly_set_bin : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    align_error : OUT STD_LOGIC;
    debug_rst_state : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    debug_cpd_state : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END COMPONENT;


the_instance_name : ddr3
  PORT MAP (
    resetn => resetn,
    core_clk => core_clk,
    pll_lock => pll_lock,
    phy_pll_lock => phy_pll_lock,
    gpll_lock => gpll_lock,
    rst_gpll_lock => rst_gpll_lock,
    ddrphy_cpd_lock => ddrphy_cpd_lock,
    ddr_init_done => ddr_init_done,
    axi_awaddr => axi_awaddr,
    axi_awuser_ap => axi_awuser_ap,
    axi_awuser_id => axi_awuser_id,
    axi_awlen => axi_awlen,
    axi_awready => axi_awready,
    axi_awvalid => axi_awvalid,
    axi_wdata => axi_wdata,
    axi_wstrb => axi_wstrb,
    axi_wready => axi_wready,
    axi_wusero_id => axi_wusero_id,
    axi_wusero_last => axi_wusero_last,
    axi_araddr => axi_araddr,
    axi_aruser_ap => axi_aruser_ap,
    axi_aruser_id => axi_aruser_id,
    axi_arlen => axi_arlen,
    axi_arready => axi_arready,
    axi_arvalid => axi_arvalid,
    axi_rdata => axi_rdata,
    axi_rid => axi_rid,
    axi_rlast => axi_rlast,
    axi_rvalid => axi_rvalid,
    apb_clk => apb_clk,
    apb_rst_n => apb_rst_n,
    apb_sel => apb_sel,
    apb_enable => apb_enable,
    apb_addr => apb_addr,
    apb_write => apb_write,
    apb_ready => apb_ready,
    apb_wdata => apb_wdata,
    apb_rdata => apb_rdata,
    mem_cs_n => mem_cs_n,
    mem_rst_n => mem_rst_n,
    mem_ck => mem_ck,
    mem_ck_n => mem_ck_n,
    mem_cke => mem_cke,
    mem_ras_n => mem_ras_n,
    mem_cas_n => mem_cas_n,
    mem_we_n => mem_we_n,
    mem_odt => mem_odt,
    mem_a => mem_a,
    mem_ba => mem_ba,
    mem_dqs => mem_dqs,
    mem_dqs_n => mem_dqs_n,
    mem_dq => mem_dq,
    mem_dm => mem_dm,
    dbg_gate_start => dbg_gate_start,
    dbg_cpd_start => dbg_cpd_start,
    dbg_ddrphy_rst_n => dbg_ddrphy_rst_n,
    dbg_gpll_scan_rst => dbg_gpll_scan_rst,
    samp_position_dyn_adj => samp_position_dyn_adj,
    init_samp_position_even => init_samp_position_even,
    init_samp_position_odd => init_samp_position_odd,
    wrcal_position_dyn_adj => wrcal_position_dyn_adj,
    init_wrcal_position => init_wrcal_position,
    force_read_clk_ctrl => force_read_clk_ctrl,
    init_slip_step => init_slip_step,
    init_read_clk_ctrl => init_read_clk_ctrl,
    debug_calib_ctrl => debug_calib_ctrl,
    dbg_slice_status => dbg_slice_status,
    dbg_slice_state => dbg_slice_state,
    debug_data => debug_data,
    dbg_dll_upd_state => dbg_dll_upd_state,
    debug_gpll_dps_phase => debug_gpll_dps_phase,
    dbg_rst_dps_state => dbg_rst_dps_state,
    dbg_tran_err_rst_cnt => dbg_tran_err_rst_cnt,
    dbg_ddrphy_init_fail => dbg_ddrphy_init_fail,
    debug_cpd_offset_adj => debug_cpd_offset_adj,
    debug_cpd_offset_dir => debug_cpd_offset_dir,
    debug_cpd_offset => debug_cpd_offset,
    debug_dps_cnt_dir0 => debug_dps_cnt_dir0,
    debug_dps_cnt_dir1 => debug_dps_cnt_dir1,
    ck_dly_en => ck_dly_en,
    init_ck_dly_step => init_ck_dly_step,
    ck_dly_set_bin => ck_dly_set_bin,
    align_error => align_error,
    debug_rst_state => debug_rst_state,
    debug_cpd_state => debug_cpd_state
  );
