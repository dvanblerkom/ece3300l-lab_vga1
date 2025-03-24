
module top_vga(
			   input wire	     clk, // 100 MHz board clock on Nexys A7
			   input wire	     rst, // Active-high reset
			   // VGA outputs
			   output wire [3:0] vgaRed,
			   output wire [3:0] vgaGreen,
			   output wire [3:0] vgaBlue,
			   output wire	     hsync,
			   output wire	     vsync
			   );

   wire [9:0] hcount;
   wire [9:0] vcount;
   wire	      hblank;
   wire	      vblank;
   wire	      pixpulse;
   wire	      is_a_wall, empty, draw_ball;
   wire	      draw_ball2;
   wire	      move;
   reg [11:0] current_pixel;
   reg vblank_d1;

   localparam WALL_COLOR = 12'h00f;
   localparam BALL_COLOR = 12'h0f0;
   localparam EMPTY_COLOR = 12'h700;
   
   //---------------------------------------------
   // VGA Timing Generator
   //---------------------------------------------
   vga_timing vga_gen (
		       .clk    (clk),
		       .pixpulse (pixpulse),
		       .rst    (rst),  //active high
		       .hcount (hcount[9:0]),
		       .vcount (vcount[9:0]),
		       .hsync  (hsync),
		       .vsync  (vsync),
		       .hblank (hblank),
		       .vblank (vblank)
		       );

   ball #(100,30,0,0) u_ball_1 ( 
		  // Outputs
		  .draw_ball		(draw_ball),
		  .xloc			(),
		  .yloc			(),
		  // Inputs
		  .clk			(clk),
		  .pixpulse             (pixpulse),
		  .rst			(rst),
		  .hcount		(hcount[9:0]),
		  .vcount		(vcount[9:0]),
		  .empty		(empty & ~draw_ball2),
		  .move			(move));
   
   assign is_a_wall = ((hcount < 5) | (hcount > 625) | (vcount < 5) | (vcount > 475));

   assign empty = ~is_a_wall;

   assign move = (vblank & ~vblank_d1);  // move balls at start of vertical blanking

   always @(posedge clk or posedge rst) begin
      if (rst) begin
	 vblank_d1 <= 0;
      end else if (pixpulse) begin
         vblank_d1 <= vblank;
      end
   end
   
   // Register the current pixel
   always @(posedge clk) begin
      if (pixpulse)
        current_pixel <= (is_a_wall) ? WALL_COLOR : ( (draw_ball | draw_ball2) ? BALL_COLOR : EMPTY_COLOR );
   end

   // Map 12-bit to 4:4:4
   assign vgaRed   = (~hblank && ~vblank) ? current_pixel[11:8] : 4'b0;
   assign vgaGreen = (~hblank && ~vblank) ? current_pixel[7:4] : 4'b0;
   assign vgaBlue  = (~hblank && ~vblank) ? current_pixel[3:0] : 4'b0;
   
endmodule
   
