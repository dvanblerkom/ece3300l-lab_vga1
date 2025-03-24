
module tb_vga1;

   wire [3:0] vgaRed, vgaGreen, vgaBlue;
   wire	      hsync, vsync;
   reg	      clk,rst;

   // Clock generation
   always #5 clk = ~clk; // Generate a clock with a period of 10 ns

   initial begin
      clk = 0;
      rst = 1;
      #21 rst = 0;
      forever
	begin
	   wait(~vsync);
	   $display("xloc: %d, yloc: %d", dut.u_ball_1.xloc, dut.u_ball_1.yloc);
	   wait(vsync);
	end
   end
   
   top_vga dut(
	       // Outputs
	       .vgaRed			(vgaRed[3:0]),
	       .vgaGreen		(vgaGreen[3:0]),
	       .vgaBlue			(vgaBlue[3:0]),
	       .hsync			(hsync),
	       .vsync			(vsync),
	       // Inputs
	       .clk			(clk),
	       .rst			(rst));

endmodule   
