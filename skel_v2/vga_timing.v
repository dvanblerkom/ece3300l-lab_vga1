

module vga_timing(
    input wire	     clk, 
    input wire	     rst,
    output wire      pixpulse,			  
    output reg [9:0] hcount,
    output reg [9:0] vcount,
    output reg	     hsync,
    output reg	     vsync,
    output reg	     hblank,
    output reg	     vblank
		  );

    // 640x480 @ 60Hz typical timing (25MHz pixel clock):
    // Horizontal:
    //   Visible area: 640
    //   Front porch: 16
    //   Sync pulse: 96
    //   Back porch: 48
    //   Total: 800
    localparam H_DISPLAY = 640;
    localparam H_FP      = 16;
    localparam H_SYNC    = 96;
    localparam H_BP      = 48;
    localparam H_TOTAL   = H_DISPLAY + H_FP + H_SYNC + H_BP; // 800

    // Vertical:
    //   Visible area: 480
    //   Front porch: 10
    //   Sync pulse: 2
    //   Back porch: 33
    //   Total: 525
    localparam V_DISPLAY = 480;
    localparam V_FP      = 10;
    localparam V_SYNC    = 2;
    localparam V_BP      = 33;
    localparam V_TOTAL   = V_DISPLAY + V_FP + V_SYNC + V_BP; // 525

   // create a pulse every 25MHz
   reg [1:0]   pix_clk_div;
   assign pixpulse = &pix_clk_div;
   
   always @(posedge clk or posedge rst) begin
        if (rst) begin
            pix_clk_div <= 2'b00;
        end else begin
            pix_clk_div <= pix_clk_div + 1'b1;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            hcount <= 0;
            vcount <= 0;
        end else if (pixpulse) begin
            // increment horizontal counter
            if (hcount == H_TOTAL - 1) begin
                hcount <= 0;
                // increment vertical counter
                if (vcount == V_TOTAL - 1)
                    vcount <= 0;
                else
                    vcount <= vcount + 1;
            end else begin
                hcount <= hcount + 1;
            end
        end
    end

    // hblank/vblank
    always @(*) begin
        hblank = (hcount >= H_DISPLAY);
        vblank = (vcount >= V_DISPLAY);
    end

    // hsync, vsync generation
    always @(posedge clk) begin
        if (pixpulse) begin
           hsync <= ~((hcount >= (H_DISPLAY + H_FP)) && 
                  (hcount <  (H_DISPLAY + H_FP + H_SYNC)));
           vsync <= ~((vcount >= (V_DISPLAY + V_FP)) && 
                  (vcount <  (V_DISPLAY + V_FP + V_SYNC)));
        end
    end

endmodule

