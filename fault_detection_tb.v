`timescale 1ns / 10ps

module fault_detection_tb;

  // Clock
  reg clk = 0;
  always #10 clk = ~clk;

  // DUT I/O
  reg  [255:0]   in_array;
  reg  [1023:0]  weight_array;
  reg            saf_enable;
  reg  [3:0]     saf_array;
  reg  [7:0]     saf_index;
  reg            bridge_enable;
  reg  [255:0]   bridge_mask;
  reg  [1:0]     bridge_type;
  wire [15:0]    sum;
  
  // --- Add for detection ---
  reg [3:0] SAF;
  integer i;
  
  reg [15:0] previous_sum;
  reg [15:0] current_sum;
    
  // DUT distance
  mac_slice_faulty_general dut (
    .clk              (clk),
    .in_array         (in_array),
    .weight_array     (weight_array),
    .saf_enable       (saf_enable),
    .saf_array        (saf_array),
    .saf_index        (saf_index),
    .bridge_enable    (bridge_enable),
    .bridge_mask      (bridge_mask),
    .bridge_type      (bridge_type),
    .sum              (sum)
  );

  
  initial begin
    
    in_array      = 256'b0;
    weight_array  = 1024'b0;
    saf_array     = 4'b0;
    saf_index     = 8'b0;
    bridge_mask   = 256'b0;
    bridge_type   = 2'b00;         // wired-AND as default
    
    saf_enable    = 1'b0;
    bridge_enable = 1'b0;
    
    previous_sum  = 16'd15;
    current_sum   = 16'd15;
    
    /* bridge_type: 2'b00  wired-AND
               2'b01  wired-OR
               2'b10  dominant
               2'b11  dominant-AND
    */
    
    // Replace saf_index (3) SAF you want --------------------------
    
    saf_enable  =   1'b1;
    saf_index   =   8'd11;
    saf_array   =   4'b1111;
    
    
    // Bridge between weight[20] and weight[21] (wired-OR) -----------------
    bridge_enable   =   1'b0;
    bridge_mask     =   256'b0;
    bridge_mask[20] =   1;
    bridge_mask[21] =   1;
    bridge_type     =   2'b11;
    
    
    #25;
    
    
    // ======================
    // Stage 1 - weights = 0
    // ======================
    $display("\n=== Stage 1: Walking-One with WEIGHTS=0 ===");
    SAF = 4'b0000;       // initialize trigger
    bridge_enable = 1'b0;
    
    for (i = 0; i < 256; i = i + 1) begin
        in_array = 256'b0;
        in_array[i] = 1'b1;
        @(posedge clk);
        #1; 
        
        // --- Fault detection logic ---
        if (sum != 16'd0) begin
            SAF = sum[3:0];
            $display(" FAULT DETECTED | index = %0d | faulty weight = %b",
                    i, sum);
            
            $finish;
           
        end
    end
    
    // break between Stage 1 and Stage 2
    @(posedge clk);
    in_array = 256'b0;
    #40;
    
    
    // ======================
    // Stage 2 - weights = 1
    // ======================
    $display("\n=== Stage 2: Walking-One with WEIGHTS = 1 ===");
    
    weight_array  = {256{4'b1111}};
    bridge_enable = 1'b1;
    previous_sum  = 16'd15;
    
    for (i = 0; i < 256; i = i +1) begin
        in_array = 256'b0;
        in_array[i] = 1'b1;
        @(posedge clk);
        #1;
        
        current_sum = sum;
        
        $display("[%0t ns] Stage 2 | index = %0d | prev = %b | curr = %b",
                   $time, i, previous_sum, current_sum);
        
        // -------------------------------
        //  Fault detection logic 
        // -------------------------------
        
        // Wired-AND fault
        if (previous_sum == 16'd0 && current_sum == 16'b0) begin
            $display(" Wired-AND FAULT DETECTED | index = %0d", i);
            $finish;
        end
        
        // Dominant (Dominant-OR)
        else if ((previous_sum == 16'd30 && current_sum == 16'd0) || (previous_sum == 16'd0 && current_sum == 16'd30)) begin
            $display(" (Dominant)Dominant-OR FAULT DETECTED | index = %0d", i);
            $finish;
        end
        
        // Dominant-AND
        else if (previous_sum == 16'd0 && current_sum == 16'd15) begin
            $display(" Dominant-AND FAULT DETECTED | index = %0d", i);
            $finish;
        end
        
        // Wired-OR
        else if (previous_sum == 16'd30 && current_sum == 16'd30) begin
            $display(" Wired-OR FAULT DETECTED | index = %0d", i);
            $finish;
        end
        
        previous_sum = current_sum;
                   
    end
    
    // Wrap-up
    @(posedge clk);
    in_array = 256'b0;
    $display("\nCompleted Stage 2.");
    #50;
    $finish;
    
   end

endmodule
