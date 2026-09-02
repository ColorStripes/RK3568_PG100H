quit -sim                  
                           
if {[file exists work]} {
  file delete -force work  
}                          
                           
  vlib	work              
  vmap	work work         
                           
set LIB_DIR  E:/PDS/PDS_2022.2-SP6.4/ip/system_ip/ips2l_hmic_s/ips2l_hmic_eval/ips2l_hmic_s-1.10/../../../../../arch/vendor/pango/verilog/simulation
                           
vlib work                  
vlog E:/PDS/PDS_2022.2-SP6.4/ip/system_ip/ips2l_hmic_s/ips2l_hmic_eval/ips2l_hmic_s-1.10/../../../../../arch/vendor/pango/verilog/simulation/modelsim10.2c/adc_e2_source_codes/*.vp
vlog -sv -work work -mfcu -incr -suppress 2902 -f ../modelsim/sim_file_list.f -y $LIB_DIR +libext+.v +incdir+../../example_design/bench/mem/ 
vsim -suppress 3486,3680,3781 +nowarn1 -c -sva -lib work ddr3_test_top_tb -l sim.log
run 600us    
             
