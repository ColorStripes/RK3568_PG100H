//******************************************************************
// Copyright (c) 2015 PANGO MICROSYSTEMS, INC
// ALL RIGHTS REVERVED.
//******************************************************************
`timescale 1ns/1ps
module hsst_rst_sync_v1_0
    (
     input                  clk,
     input                  rst_n,

     input                  sig_async,
     output reg             sig_synced
    );

//
reg                      sig_async_ff;

//single bit
always@(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        sig_async_ff <= 1'b0;
    else
        sig_async_ff <= sig_async;
end

always@(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        sig_synced <= 1'b0;
    else
        sig_synced <= sig_async_ff;
end

endmodule