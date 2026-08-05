# 断开 top 内部复位信号 rst 到 ETH 下面复位同步模块输入 reset 的时序分析
#set_false_path -through [get_cells -hierarchical "*async_rst*"]


#set nets_to_module [get_nets -of_objects [get_pins -of_objects [get_cells */async_rst*] -filter {DIRECTION == IN}]]
set_false_path -through [get_nets -of_objects [get_pins -of_objects [get_cells -hierarchical *async_rst*] -filter {DIRECTION == IN}]]

set_false_path -through [get_nets -of_objects [get_pins -of_objects [get_cells -hierarchical *oddr*] -filter {DIRECTION == IN}]]
set_false_path -through [get_nets -of_objects [get_pins -of_objects [get_cells -hierarchical *iddr*] -filter {DIRECTION == IN}]]

## 标记 ETH 下面的复位同步链为跨时钟异步寄存器链，让 Vivado 像处理 IP 一样优化它
#set_property ASYNC_REG TRUE [get_cells -hierarchical -filter "name =~ *async_rst*/sync1*"]
#set_property ASYNC_REG TRUE [get_cells -hierarchical -filter "name =~ *async_rst*/sync2*"]




















































































