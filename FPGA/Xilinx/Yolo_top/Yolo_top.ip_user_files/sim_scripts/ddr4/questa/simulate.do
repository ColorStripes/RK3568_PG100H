onbreak {quit -f}
onerror {quit -f}

vsim -lib xil_defaultlib ddr4_opt

do {wave.do}

view wave
view structure
view signals

do {ddr4.udo}

run -all

quit -force
