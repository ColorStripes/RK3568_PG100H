onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib ov5640_clk_opt

do {wave.do}

view wave
view structure
view signals

do {ov5640_clk.udo}

run -all

quit -force
