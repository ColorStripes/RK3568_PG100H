module axi_pipe
	#(
		parameter       ID_WIDTH  	= 4		,
		parameter       DATA_WIDTH 	= 128	,
		parameter       KEEP_WIDTH  = DATA_WIDTH / 8	
	)
	(
	input clk,    // Clock
	input rst,    // Synchronous reset active high

	//slave
    input 			[ID_WIDTH - 1:0]    		s_axi_arid 		,
    input 	 		[31:0]  					s_axi_araddr	,
    input 	 		[7:0]                 		s_axi_arlen		,
    input 			[2:0]                 		s_axi_arsize	,
    input 			[1:0]                 		s_axi_arburst	,
    input 			                      		s_axi_arlock	,
    input 			[3:0]                 		s_axi_arcache	,
    input 			[2:0]                 		s_axi_arprot	,
    input                           			s_axi_arvalid	,	
    output                        				s_axi_arready	,
    output 			[ID_WIDTH - 1:0]   			s_axi_rid 		,
    output 			[DATA_WIDTH - 1:0]  		s_axi_rdata		,
    output 			[1:0]                		s_axi_rresp		,
    output                        				s_axi_rlast		,
    output                        				s_axi_rvalid 	,
    input                       				s_axi_rready    ,
	input  			[ID_WIDTH - 1:0]   			s_axi_awid   	,
	input  			[31:0]  					s_axi_awaddr 	,
	input  			[7:0]   					s_axi_awlen  	,
	input 			[2:0]   					s_axi_awsize 	,
	input 			[1:0]   					s_axi_awburst	,
	input 			  	    					s_axi_awlock 	,
	input 			[3:0]   					s_axi_awcache	,
	input 			[2:0]   					s_axi_awprot	,
	input  		        						s_axi_awvalid	,
	output  		 	        				s_axi_awready	,
	input 			[DATA_WIDTH - 1:0] 			s_axi_wdata		,
	input 			[KEEP_WIDTH - 1:0]  		s_axi_wstrb		,
	input 			        					s_axi_wlast		,
	input 			        					s_axi_wvalid	,
	output  			        				s_axi_wready	,
	output  		[ID_WIDTH - 1:0]   			s_axi_bid  		,
	output  		[1:0]   					s_axi_bresp 	,
	output  			        				s_axi_bvalid	,
	input 			        					s_axi_bready	,



	//master
    output 			[ID_WIDTH - 1:0]    		m_axi_arid 		,
    output 	 		[31:0]  					m_axi_araddr	,
    output 	 		[7:0]                 		m_axi_arlen		,
    output 			[2:0]                 		m_axi_arsize	,
    output 			[1:0]                 		m_axi_arburst	,
    output 			                      		m_axi_arlock	,
    output 			[3:0]                 		m_axi_arcache	,
    output 			[2:0]                 		m_axi_arprot	,
    output                           			m_axi_arvalid	,	
    input                        				m_axi_arready	,
    input 			[ID_WIDTH - 1:0]   			m_axi_rid 		,
    input 			[DATA_WIDTH - 1:0]  		m_axi_rdata		,
    input 			[1:0]                		m_axi_rresp		,
    input                        				m_axi_rlast		,
    input                        				m_axi_rvalid 	,
    output                       				m_axi_rready    ,
	output  		[ID_WIDTH - 1:0]   			m_axi_awid   	,
	output  		[31:0]  					m_axi_awaddr 	,
	output  		[7:0]   					m_axi_awlen  	,
	output 			[2:0]   					m_axi_awsize 	,
	output 			[1:0]   					m_axi_awburst	,
	output 		    	    					m_axi_awlock 	,
	output 			[3:0]   					m_axi_awcache	,
	output 			[2:0]   					m_axi_awprot	,
	output  		        					m_axi_awvalid	,
	input  		 	        					m_axi_awready	,
	output 			[DATA_WIDTH - 1:0] 			m_axi_wdata		,
	output 			[KEEP_WIDTH - 1:0]  		m_axi_wstrb		,
	output 			        					m_axi_wlast		,
	output 			        					m_axi_wvalid	,
	input  			        					m_axi_wready	,
	input  			[ID_WIDTH - 1:0]   			m_axi_bid  		,
	input  			[1:0]   					m_axi_bresp 	,
	input  			        					m_axi_bvalid	,
	output 			        					m_axi_bready	
	
);

endmodule 