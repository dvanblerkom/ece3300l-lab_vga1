

// 3x3 ball drawing and movement control

module ball #(parameter xloc_start=320,
              parameter yloc_start=240,
              parameter xdir_start=0,
              parameter ydir_start=0)
   (
    input            clk,        // 100 MHz system clock
    input            pixpulse,   // every 4 clocks for 25MHz pixel rate
    input            rst,
    // Paint ports (driven by vga_timing raster scan)
    input [9:0]      hcount,     // x-location being painted
    input [9:0]      vcount,     // y-location being painted
    // Collision ports (driven by the active sprite's scanner via top-level mux)
    input [9:0]      hcount_col, // collision scan x
    input [9:0]      vcount_col, // collision scan y
    input            empty_col,  // is the collision scan pixel empty?
    // Scan arbitration
    input            scan_grant,       // one-cycle pulse: my turn to scan
    output reg       scan_done,        // one-cycle pulse: scan complete
    output reg [9:0] hcount_col_out,   // my scan x (selected by top-level mux)
    output reg [9:0] vcount_col_out,   // my scan y
    output reg       scan_active,
    // Movement
    input            move,       // one-cycle pulse: update position
    input            frame_start, // one-pixpulse pulse at start of vblank
    // Outputs
    output           draw_ball,     // paint this pixel as ball
    output           draw_ball_col, // is ball at collision scan coords?
    output reg [9:0] xloc,
    output reg [9:0] yloc
    );

   localparam RADIUS      = 1;  // half-width of ball body
   localparam SCAN_BORDER = 2;  // RADIUS + 1: perimeter distance
   localparam SCAN_WIDTH  = 5;  // 2*RADIUS + 3: pixels per perimeter side

   reg [4:0]  occupied_lft;
   reg [4:0]  occupied_rgt;
   reg [4:0]  occupied_bot;
   reg [4:0]  occupied_top;
   reg        xdir, ydir;

   wire       blk_lft_up, blk_lft_dn, blk_rgt_up, blk_rgt_dn;
   wire       blk_up_lft, blk_up_rgt, blk_dn_lft, blk_dn_rgt;
   wire       corner_lft_up, corner_rgt_up, corner_lft_dn, corner_rgt_dn;

   // Perimeter scanner state
   reg [1:0]  scan_side;    // 0=right, 1=left, 2=bottom, 3=top
   reg [2:0]  scan_offset;  // 0 .. SCAN_WIDTH-1 = 4

   //------------------------------------------------------------
   // Paint: is the raster pointing at this ball?
   //------------------------------------------------------------
   // xloc/yloc change mid-frame, so paint from a copy latched once per
   // frame (at vblank).  Otherwise the top and bottom rows of the ball can
   // be drawn at different positions (tearing).  Collision still uses the
   // live xloc/yloc.
   reg [9:0] disp_x, disp_y;
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         disp_x <= xloc_start;
         disp_y <= yloc_start;
      end else if (pixpulse && frame_start) begin
         disp_x <= xloc;
         disp_y <= yloc;
      end
   end

   wire draw_now = (hcount <= disp_x + RADIUS) & (hcount >= disp_x - RADIUS) &
                   (vcount <= disp_y + RADIUS) & (vcount >= disp_y - RADIUS);

   
   assign draw_ball = draw_now;

   //------------------------------------------------------------
   // Collision: is the ball body at the current collision scan coords?
   //------------------------------------------------------------
   assign draw_ball_col = (hcount_col <= xloc + RADIUS) & (hcount_col >= xloc - RADIUS) &
                          (vcount_col <= yloc + RADIUS) & (vcount_col >= yloc - RADIUS);

   //------------------------------------------------------------
   // Collision scan coordinate generation (combinatorial)
   // side 0: right column  hcount=xloc+SCAN_BORDER, vcount sweeps top-to-bottom
   // side 1: left  column  hcount=xloc-SCAN_BORDER, vcount sweeps top-to-bottom
   // side 2: bottom row    vcount=yloc+SCAN_BORDER, hcount sweeps left-to-right
   // side 3: top    row    vcount=yloc-SCAN_BORDER, hcount sweeps left-to-right
   //------------------------------------------------------------
   always @(*) begin
      case (scan_side)
         2'b00: begin
            hcount_col_out = xloc + SCAN_BORDER;
            vcount_col_out = yloc - SCAN_BORDER + scan_offset;
         end
         2'b01: begin
            hcount_col_out = xloc - SCAN_BORDER;
            vcount_col_out = yloc - SCAN_BORDER + scan_offset;
         end
         2'b10: begin
            hcount_col_out = xloc - SCAN_BORDER + scan_offset;
            vcount_col_out = yloc + SCAN_BORDER;
         end
         2'b11: begin
            hcount_col_out = xloc - SCAN_BORDER + scan_offset;
            vcount_col_out = yloc - SCAN_BORDER;
         end
      endcase
   end

   //------------------------------------------------------------
   // Occupied register update + scan control
   //
   // Index mapping: index SCAN_WIDTH-1-offset = 4 at top (yloc-SCAN_BORDER)
   //                                           = 0 at bottom (yloc+SCAN_BORDER)
   // 
   //------------------------------------------------------------
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         occupied_lft <= 5'b0;
         occupied_rgt <= 5'b0;
         occupied_bot <= 5'b0;
         occupied_top <= 5'b0;
         scan_side    <= 2'b0;
         scan_offset  <= 3'b0;
         scan_active  <= 1'b0;
         scan_done    <= 1'b0;
      end else if (pixpulse) begin
         scan_done <= 1'b0; // default: pulse for one pixpulse only

         if (scan_grant && !scan_active) begin
            // Start a fresh scan: clear occupied registers and begin
            occupied_lft <= 5'b0;
            occupied_rgt <= 5'b0;
            occupied_bot <= 5'b0;
            occupied_top <= 5'b0;
            scan_active  <= 1'b1;
            scan_side    <= 2'b0;
            scan_offset  <= 3'b0;

         end else if (scan_active) begin
            // Sample the current perimeter pixel
            if (!empty_col) begin
               case (scan_side)
                  2'b00: occupied_rgt[SCAN_WIDTH-1-scan_offset] <= 1'b1;
                  2'b01: occupied_lft[SCAN_WIDTH-1-scan_offset] <= 1'b1;
                  2'b10: occupied_bot[SCAN_WIDTH-1-scan_offset] <= 1'b1;
                  2'b11: occupied_top[SCAN_WIDTH-1-scan_offset] <= 1'b1;
               endcase
            end

            // Advance the scan counter
            if (scan_offset == SCAN_WIDTH - 1) begin
               scan_offset <= 3'b0;
               if (scan_side == 2'b11) begin
                  scan_active <= 1'b0;
                  scan_done   <= 1'b1;
               end else begin
                  scan_side <= scan_side + 1'b1;
               end
            end else begin
               scan_offset <= scan_offset + 1'b1;
            end
         end
      end
   end

   //------------------------------------------------------------
   // Collision detection wires
   //------------------------------------------------------------
   assign blk_lft_up = |occupied_lft[3:2];
   assign blk_lft_dn = |occupied_lft[2:1];
   assign blk_rgt_up = |occupied_rgt[3:2];
   assign blk_rgt_dn = |occupied_rgt[2:1];

   assign blk_up_lft = |occupied_top[3:2];
   assign blk_up_rgt = |occupied_top[2:1];
   assign blk_dn_lft = |occupied_bot[3:2];
   assign blk_dn_rgt = |occupied_bot[2:1];

   assign corner_lft_up = occupied_lft[4] & ~blk_up_lft & ~blk_lft_up;
   assign corner_rgt_up = occupied_rgt[4] & ~blk_up_rgt & ~blk_rgt_up;
   assign corner_lft_dn = occupied_lft[0] & ~blk_dn_lft & ~blk_lft_dn;
   assign corner_rgt_dn = occupied_rgt[0] & ~blk_dn_rgt & ~blk_rgt_dn;

   //------------------------------------------------------------
   // Movement (triggered by move pulse)
   //------------------------------------------------------------
   always @(posedge clk or posedge rst) begin
      if (rst) begin
         xloc <= xloc_start;
         yloc <= yloc_start;
         xdir <= xdir_start;
         ydir <= ydir_start;
      end else if (pixpulse) begin
         if (move) begin
            case ({xdir, ydir})
               2'b00: begin  // heading left and up
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
               2'b01: begin  // heading left and down
                  // complete this code
               end
               2'b10: begin  // heading right and up
                   // complete this code
               end
               2'b11: begin  // heading right and down
                   // complete this code
               end
            endcase
         end
      end
   end

endmodule // ball
