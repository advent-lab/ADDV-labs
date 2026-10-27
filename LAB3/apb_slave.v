
`define REG_ADDRWIDTH 10
`define REG_DATAWIDTH 5
`define REG_STRT_ADDR 1
`define REG_DONE_ADDR 2

module apb_slave(
    input                             PCLK,
    input                             PRESETn,
    input        [`REG_ADDRWIDTH-1:0] PADDR,
    input                             PWRITE,
    input                             PSEL,
    input                             PENABLE,
    input        [`REG_DATAWIDTH-1:0] PWDATA,
    output reg   [`REG_DATAWIDTH-1:0] PRDATA,
    output reg                        PREADY,
    output reg start,
	.....
    input done
	.....
);

//Recommend using ENUMs
reg [1:0] State;
//States will be IDLE, SETUP, READ_ACCESS and WRITE_ACCESS

always @(posedge PCLK) begin
  if (PRESETn == 0) begin
    State <= `IDLE;
    .....
  end

  else begin
    case (State)
       ....
	   
      `WRITE_ACCESS : begin
        if (PWRITE && PENABLE) begin
          case (PADDR)
          `REG_STRT_ADDR  : begin
                                start <= PWDATA[0];                   
                            end
          
          .....
          endcase
          
        end
        
      end

      `READ_ACCESS : begin
        if (!PWRITE && PENABLE) begin
          
          case (PADDR)
          `REG_DONE_ADDR  : PRDATA <= {done, 15'b0};
          
          ....
          endcase
        end
        
      end
      ....
     
    endcase
  end
end 

endmodule
