
module top_vga (
    input  wire       clk,       // 100 MHz board clock on Nexys A7
    input  wire       rst,       // Active-high reset
    // VGA outputs
    output wire [3:0] vgaRed,
    output wire [3:0] vgaGreen,
    output wire [3:0] vgaBlue,
    output wire       hsync,
    output wire       vsync
);

  localparam NSPRITE = 2;

  wire [        9:0] hcount;
  wire [        9:0] vcount;
  wire               hblank;
  wire               vblank;
  wire               pixpulse;
  wire [NSPRITE-1:0] draw_ball;

  wire [NSPRITE-1:0] draw_ball_col;
  wire [        9:0] hcount_col_out[0:NSPRITE-1];
  wire [        9:0] vcount_col_out[0:NSPRITE-1];

  reg                scan_grant_1;
  wire [NSPRITE-1:0] scan_active;
  wire [NSPRITE-1:0] scan_done;

  reg                move;
  reg  [        1:0] scan_state;
  reg  [       11:0] current_pixel;
  reg  [       15:0] move_delay;

  localparam WALL_COLOR = 12'h00f;
  localparam BALL_COLOR = 12'h0f0;
  localparam EMPTY_COLOR = 12'h700;

  //---------------------------------------------
  // VGA Timing Generator
  //---------------------------------------------
  vga_timing vga_gen (
      .clk     (clk),
      .pixpulse(pixpulse),
      .rst     (rst),
      .hcount  (hcount[9:0]),
      .vcount  (vcount[9:0]),
      .hsync   (hsync),
      .vsync   (vsync),
      .hblank  (hblank),
      .vblank  (vblank)
  );

  reg [9:0] hcount_col;
  reg [9:0] vcount_col;
  integer i;
  always @(*) begin
    hcount_col = 10'd0;
    vcount_col = 10'd0;
    for (i = 0; i < NSPRITE; i = i + 1) begin
      if (scan_active[i]) begin
        hcount_col = hcount_col_out[i];
        vcount_col = vcount_col_out[i];
      end
    end
  end

  function is_a_wall(input [9:0] hcount, input [9:0] vcount);
    is_a_wall =
        ((hcount < 5) | (hcount > 625) | (vcount < 5) | (vcount > 475)) |
        ((hcount < 300) & (hcount > 295) & (vcount < 300) & (vcount > 200));
  endfunction


  // empty_col seen by each sprite excludes the *other* sprite and walls
  reg empty_col[NSPRITE-1:0];
  integer j;
  integer k;
  always @(*) begin
    for (j = 0; j < NSPRITE; j = j + 1) begin
      empty_col[j] = ~(is_a_wall(hcount_col, vcount_col));
      for (k = 0; k < NSPRITE; k = k + 1) begin
        if (k != j) begin
          empty_col[j] = empty_col[j] & ~draw_ball_col[k];
        end
      end
    end
  end

  //---------------------------------------------
  // Sprite instances
  //---------------------------------------------
  ball #(320, 240, 0, 0) u_ball_1 (
      .draw_ball     (draw_ball[0]),
      .draw_ball_col (draw_ball_col[0]),
      .hcount_col_out(hcount_col_out[0]),
      .vcount_col_out(vcount_col_out[0]),
      .scan_active   (scan_active[0]),
      .scan_done     (scan_done[0]),
      .xloc          (),
      .yloc          (),
      .clk           (clk),
      .pixpulse      (pixpulse),
      .rst           (rst),
      .hcount        (hcount[9:0]),
      .vcount        (vcount[9:0]),
      .hcount_col    (hcount_col),
      .vcount_col    (vcount_col),
      .empty_col     (empty_col[0]),
      .scan_grant    (scan_grant_1),
      .move          (move)
  );

  bigball #(80, 80, 1, 0) u_ball_2 (
      .draw_ball     (draw_ball[1]),
      .draw_ball_col (draw_ball_col[1]),
      .hcount_col_out(hcount_col_out[1]),
      .vcount_col_out(vcount_col_out[1]),
      .scan_active   (scan_active[1]),
      .scan_done     (scan_done[1]),
      .xloc          (),
      .yloc          (),
      .clk           (clk),
      .pixpulse      (pixpulse),
      .rst           (rst),
      .hcount        (hcount[9:0]),
      .vcount        (vcount[9:0]),
      .hcount_col    (hcount_col),
      .vcount_col    (vcount_col),
      .empty_col     (empty_col[1]),
      .scan_grant    (scan_done[0]),  // daisy chain grant from ball 1
      .move          (move)
  );

  //---------------------------------------------
  // Collision scan sequencer + move generator
  //
  //---------------------------------------------
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      scan_state   <= 2'b00;
      scan_grant_1 <= 1'b0;
      move         <= 1'b0;
      move_delay   <= 16'd0;
    end else if (pixpulse) begin
      // Defaults: all pulses low each cycle
      scan_grant_1 <= 1'b0;
      move         <= 1'b0;

      case (scan_state)
        2'b00: begin
          scan_grant_1 <= 1'b1;  // one-cycle grant to sprite 1
          scan_state   <= 2'b01;
          move_delay   <= 16'd45000;
        end
        2'b01: begin
          if (move_delay > 0) move_delay <= move_delay - 1;
          if (scan_done[NSPRITE-1]) scan_state <= 2'b10;
        end
        2'b10: begin
          // wait some number of clocks
          if (move_delay == 16'd0) begin
            scan_state <= 2'b11;
          end else begin
            move_delay <= move_delay - 1;
            scan_state <= 2'b10;
          end
        end
        2'b11: begin
          move_delay <= 16'd0;
          move       <= 1'b1;  // all sprites move simultaneously
          scan_state <= 2'b00;
        end
      endcase
    end
  end

  //---------------------------------------------
  // Paint logic (uses raster hcount/vcount, unchanged)
  //---------------------------------------------

  always @(posedge clk) begin
    if (pixpulse)
      current_pixel <= is_a_wall(hcount, vcount) ? WALL_COLOR
                                   : ((|draw_ball) ? BALL_COLOR : EMPTY_COLOR);
  end

  assign vgaRed   = (~hblank && ~vblank) ? current_pixel[11:8] : 4'b0;
  assign vgaGreen = (~hblank && ~vblank) ? current_pixel[7:4] : 4'b0;
  assign vgaBlue  = (~hblank && ~vblank) ? current_pixel[3:0] : 4'b0;

endmodule
