`timescale 1ns / 1ps

module mac_slice_faulty_general(
    input              clk,
    input  [255:0]     in_array,
    input  [1023:0]    weight_array,
    
    input              saf_enable,
    input  [3:0]       saf_array,
    input  [7:0]       saf_index,
    
    input              bridge_enable,
    input  [255:0]     bridge_mask,
    input  [1:0]       bridge_type,
    
    output reg [15:0]  sum
    );
    
    reg [255:0]    in_faulty;
    reg [1023:0]   weight_faulty;
    reg [3:0]      andv, orv;
    integer        i;
        
    
    // --- Fault injection logic ---
    always @(*) begin
    
        in_faulty      = in_array;
        weight_faulty  = weight_array;
        
        // ------------------------------------
        // SAF injection
        // ------------------------------------
        if (saf_enable) begin
            // Replace the 4-bit weight slice at saf_index
            weight_faulty[4*saf_index +: 4] = saf_array;
        end
        
        
        // --------------------------------------
        // Bridging / Dominant faults
        // --------------------------------------
        if (bridge_enable) begin   
            for (i = 0; i < 255; i = i + 1) begin
                if (bridge_mask[i] && bridge_mask[i+1]) begin
                    case (bridge_type)
                        2'b00: begin        // wired-AND
                            in_faulty[i]    = in_faulty[i] & in_faulty[i+1];
                            in_faulty[i+1]  = in_faulty[i];
                        end
                        2'b01: begin        // wired-OR
                            in_faulty[i]    = in_faulty[i] | in_faulty[i+1];
                            in_faulty[i+1]  = in_faulty[i];
                        end
                        2'b10: begin        // dominant (i dominant i+1)
                            in_faulty[i+1]  = in_faulty[i];
                        end
                        2'b11: begin        // dominant-AND
                            in_faulty[i+1]  = in_faulty[i] & in_faulty[i+1];
                        end
                    endcase
                end
            end
        end
    end
    
    // -------------------------------------
    // Clocked Accumulation: sum updates once per clk
    // -------------------------------------
    
    reg [15:0] acc;
    integer    k;
    
    always @(posedge clk) begin
        acc = 0;
        for (k = 0; k < 256; k = k + 1)
            acc = acc + (in_faulty[k] ? weight_faulty[4*k +: 4] : 4'b0000);
        sum <= acc;
        
    end
    
endmodule
