`timescale 1ns/1ps

module stream_pipe #(
  parameter       DATA_WIDTH 	= 128	
) (
  input                          dataIn_valid,
  output                         dataIn_ready,
  input      [DATA_WIDTH - 1:0]  dataIn_payload,
  output                         dataOut_valid,
  input                          dataOut_ready,
  output     [DATA_WIDTH - 1:0]  dataOut_payload,
  input                          clk,
  input                          reset
);

  wire                           dataIn_s2mPipe_valid;
  reg                            dataIn_s2mPipe_ready;
  wire       [DATA_WIDTH - 1:0]  dataIn_s2mPipe_payload;
  reg                            dataIn_rValidN;
  reg        [DATA_WIDTH - 1:0]  dataIn_rData;
  wire                           dataIn_s2mPipe_m2sPipe_valid;
  wire                           dataIn_s2mPipe_m2sPipe_ready;
  wire       [DATA_WIDTH - 1:0]  dataIn_s2mPipe_m2sPipe_payload;
  reg                            dataIn_s2mPipe_rValid;
  reg        [DATA_WIDTH - 1:0]  dataIn_s2mPipe_rData;
  wire                           when_Stream_l369;

  assign dataIn_ready = dataIn_rValidN;
  assign dataIn_s2mPipe_valid = (dataIn_valid || (! dataIn_rValidN));
  assign dataIn_s2mPipe_payload = (dataIn_rValidN ? dataIn_payload : dataIn_rData);
  always @(*) begin
    dataIn_s2mPipe_ready = dataIn_s2mPipe_m2sPipe_ready;
    if(when_Stream_l369) begin
      dataIn_s2mPipe_ready = 1'b1;
    end
  end

  assign when_Stream_l369 = (! dataIn_s2mPipe_m2sPipe_valid);
  assign dataIn_s2mPipe_m2sPipe_valid = dataIn_s2mPipe_rValid;
  assign dataIn_s2mPipe_m2sPipe_payload = dataIn_s2mPipe_rData;
  assign dataOut_valid = dataIn_s2mPipe_m2sPipe_valid;
  assign dataIn_s2mPipe_m2sPipe_ready = dataOut_ready;
  assign dataOut_payload = dataIn_s2mPipe_m2sPipe_payload;
  always @(posedge clk) begin
    if(reset) begin
      dataIn_rValidN <= 1'b1;
      dataIn_s2mPipe_rValid <= 1'b0;
    end else begin
      if(dataIn_valid) begin
        dataIn_rValidN <= 1'b0;
      end
      if(dataIn_s2mPipe_ready) begin
        dataIn_rValidN <= 1'b1;
      end
      if(dataIn_s2mPipe_ready) begin
        dataIn_s2mPipe_rValid <= dataIn_s2mPipe_valid;
      end
    end
  end

  always @(posedge clk) begin
    if(dataIn_ready) begin
      dataIn_rData <= dataIn_payload;
    end
    if(dataIn_s2mPipe_ready) begin
      dataIn_s2mPipe_rData <= dataIn_s2mPipe_payload;
    end
  end


endmodule
