

// 3x3 ball drawing and movement control 

module ball #(parameter xloc_start=320,
	      parameter yloc_start=240,
	      parameter xdir_start=0,
	      parameter ydir_start=0)
   (
    input	     clk, // 100 MHz system clock
    input	     pixpulse, // every 4 clocks for 25MHz pixel rate
    input	     rst,
    input [9:0]	     hcount, // x-location where we are drawing
    input [9:0]	     vcount, // y-location where we are drawing
    input	     empty, // is this pixel empty
    input	     move, // signal to update the location of the ball
    output	     draw_ball, // is the ball being drawn here?
    output reg [9:0] xloc, // x-location of the ball
    output reg [9:0] yloc // y-location of the ball
    );

   reg [4:0]			 occupied_lft;
   reg [4:0]			 occupied_rgt;
   reg [4:0]			 occupied_bot;
   reg [4:0]			 occupied_top;
   reg				 xdir, ydir;

   wire				 blk_lft_up, blk_lft_dn, blk_rgt_up, blk_rgt_dn;
   wire				 blk_up_lft, blk_up_rgt, blk_dn_lft, blk_dn_rgt;
   wire				 corner_lft_up, corner_rgt_up, corner_lft_dn, corner_rgt_dn;
   
   // are we pointing at a pixel in the ball?
   // this will make a square ball...
   assign draw_ball = (hcount <= xloc+1) & (hcount >= xloc-1) & (vcount <= yloc+1) & (vcount >= yloc-1) ?  1 : 0;

   // hcount goes from 0=left to 640=right
   // vcount goes from 0=top to 480=bottom
   
   // keep track of the neighboring pixels to detect a collision
   always @(posedge clk or posedge rst)
     begin
	if (rst) begin
	   occupied_lft <= 5'b0;
	   occupied_rgt <= 5'b0;
	   occupied_bot <= 5'b0;
	   occupied_top <= 5'b0;
	end else if (pixpulse) begin  // only make changes when pixpulse is high

	      if (vcount >= yloc-2 && vcount <= yloc+2) 
		if (hcount == xloc+2)
			occupied_rgt[(yloc-vcount+2)] <= ~empty;  // LSB is at bottom
		else if (hcount == xloc-2)
			occupied_lft[(yloc-vcount+2)] <= ~empty;
	      
	      if (hcount >= xloc-2 && hcount <= xloc+2) 
		if (vcount == yloc+2)
			occupied_bot[(xloc-hcount+2)] <= ~empty;  // LSB is at right
		else if (vcount == yloc-2)
			occupied_top[(xloc-hcount+2)] <= ~empty;

	end
     end	      


   assign blk_lft_up = |occupied_lft[3:2];  // upper left pixels are blocked
   assign blk_lft_dn = |occupied_lft[2:1];  // lower left pixels are blocked
   assign blk_rgt_up = |occupied_rgt[3:2];  // upper right pixels are blocked
   assign blk_rgt_dn = |occupied_rgt[2:1];  // lower right pixels are blocked

   assign blk_up_lft = |occupied_top[3:2];  // left-side top pixels are blocked
   assign blk_up_rgt = |occupied_top[2:1];  // right-side top pixels are blocked
   assign blk_dn_lft = |occupied_bot[3:2];  // left-side bottom pixels are blocked
   assign blk_dn_rgt = |occupied_bot[2:1];  // right-side bottom pixels are blocked

   assign corner_lft_up = occupied_lft[4] & ~blk_up_lft & ~blk_lft_up;   // only left top corner is blocked
   assign corner_rgt_up = occupied_rgt[4] & ~blk_up_rgt & ~blk_rgt_up;   // only right top corner is blocked
   assign corner_lft_dn = occupied_lft[0] & ~blk_dn_lft & ~blk_lft_dn;   // only left bottom corner is blocked
   assign corner_rgt_dn = occupied_rgt[0] & ~blk_dn_rgt & ~blk_rgt_dn;   // only right bottom corner is blocked
   
   always @(posedge clk or posedge rst)
     begin
	if (rst) begin
	   xloc <= xloc_start;
	   yloc <= yloc_start;
	   xdir <= xdir_start;
	   ydir <= ydir_start;
	end else if (pixpulse) begin
	   if (move) begin

	      case ({xdir,ydir})
		2'b00: begin  // heading to the left and up
		   if (blk_lft_up | corner_lft_up) begin
		      xloc <= xloc + 1;
		      xdir <= ~xdir;
		   end else begin
		      xloc <= xloc - 1;
		   end
		   if (blk_up_lft | corner_lft_up) begin
		      yloc <= yloc + 1;
		      ydir <= ~ydir;
		   end else begin
		      yloc <= yloc - 1;
		   end
		end
		2'b01: begin  // heading to the left and down
		   // complete this code
		end
		2'b10: begin  // heading to the right and up
		   // complete this code
		end
		2'b11: begin  // heading to the right and down
		   // complete this code
		end
	      endcase 

	   end 
	end 
     end
   
endmodule // ball
