


////////////////////////////////////////////
//Task to write into the configuration block of the DUT
////////////////////////////////////////////
task write(input [`REG_ADDRWIDTH-1:0] addr, input [`REG_DATAWIDTH-1:0] data);
 begin
  @(negedge clk);
  PSEL = 1;
  PWRITE = 1;
  PADDR = addr;
  PWDATA = data;
	@(negedge clk);
  PENABLE = 1;
	@(negedge clk);
  PSEL = 0;
  PENABLE = 0;
  PWRITE = 0;
  PADDR = 0;
  PWDATA = 0;
  $display("%t: PADDR %h, PWDATA %h", $time, addr, data);
 end  
endtask

////////////////////////////////////////////
//Task to read from the configuration block of the DUT
////////////////////////////////////////////
task read(input [`REG_ADDRWIDTH-1:0] addr, output [`REG_DATAWIDTH-1:0] data);
begin 
	@(negedge clk);
	PSEL = 1;
	PWRITE = 0;
  PADDR = addr;
	@(negedge clk);
  PENABLE = 1;
	@(negedge clk);
  PSEL = 0;
  PENABLE = 0;
  data = PRDATA;
  PADDR = 0;
	$display("%t: PADDR %h, PRDATA %h",$time, addr,data);
end
endtask


////////////////////////////////////////////
// Main routine. Calls the appropriate tasks
////////////////////////////////////////////
initial begin
  //Reset 
  reset = 1;

  $display("Starting simulation");

  //Bring the design out of reset
  #55 reset = 0;

  //Wait for a clock or two
  #30;

  $display("Start the matmul");
  write(`REG_STRT_ADDR, wdata);
  ....
  
  $display("Wait until done");
  do 
  begin
      read(`REG_DONE_ADDR, rdata);
      done = rdata[15];
  end 
  while (done == 0);
  
  $display("Finishing simulation");
  //A little bit of drain time before we finish
  #200;
  $finish;
end

