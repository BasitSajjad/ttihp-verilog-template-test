/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module sha256_shift_reg (
    input wire clk,
    input wire reset_n,
    input wire [7:0] data_in,
    input wire valid_in,
    output reg [7:0] hash_out,
    output reg valid_o
);

// SHA-256 constants
localparam [31:0] K[0:63] = '{
    32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5, 32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
    32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3, 32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
    32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc, 32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
    32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7, 32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
    32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13, 32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
    32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3, 32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
    32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5, 32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
    32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208, 32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
};

// Initial hash values
localparam [31:0] H_init[0:7] = '{
    32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
    32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
};

// Shift registers for message schedule
reg [31:0] w [0:15];  // 16-word message block shift register
reg [31:0] w_ext [0:47]; // Extended message schedule

// Working variables
reg [31:0] a, b, c, d, e, f, g, h;
reg [31:0] h0, h1, h2, h3, h4, h5, h6, h7;

// Control registers
reg [6:0] byte_count;
reg [5:0] round;
reg [2:0] state;
reg [3:0] output_count;

// States
localparam IDLE = 0;
localparam LOAD = 1;
localparam PAD = 2;
localparam EXPAND = 3;
localparam COMPRESS = 4;
localparam UPDATE = 5;
localparam OUTPUT = 6;

// SHA-256 functions using shift operations
function [31:0] sigma0;
    input [31:0] x;
    begin
        sigma0 = ((x >> 7) | (x << 25)) ^ ((x >> 18) | (x << 14)) ^ (x >> 3);
    end
endfunction

function [31:0] sigma1;
    input [31:0] x;
    begin
        sigma1 = ((x >> 17) | (x << 15)) ^ ((x >> 19) | (x << 13)) ^ (x >> 10);
    end
endfunction

function [31:0] SIGMA0;
    input [31:0] x;
    begin
        SIGMA0 = ((x >> 2) | (x << 30)) ^ ((x >> 13) | (x << 19)) ^ ((x >> 22) | (x << 10));
    end
endfunction

function [31:0] SIGMA1;
    input [31:0] x;
    begin
        SIGMA1 = ((x >> 6) | (x << 26)) ^ ((x >> 11) | (x << 21)) ^ ((x >> 25) | (x << 7));
    end
endfunction

function [31:0] ch;
    input [31:0] x, y, z;
    begin
        ch = (x & y) ^ (~x & z);
    end
endfunction

function [31:0] maj;
    input [31:0] x, y, z;
    begin
        maj = (x & y) ^ (x & z) ^ (y & z);
    end
endfunction

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        // Reset all registers
        for (integer i = 0; i < 16; i = i + 1) w[i] <= 0;
        for (integer i = 0; i < 48; i = i + 1) w_ext[i] <= 0;
        
        h0 <= H_init[0]; h1 <= H_init[1]; h2 <= H_init[2]; h3 <= H_init[3];
        h4 <= H_init[4]; h5 <= H_init[5]; h6 <= H_init[6]; h7 <= H_init[7];
        
        byte_count <= 0;
        round <= 0;
        state <= IDLE;
        output_count <= 0;
        valid_o <= 0;
        hash_out <= 0;
    end else begin
        case (state)
            IDLE: begin
                valid_o <= 0;
                if (valid_in) begin
                    // Shift in new byte
                    w[byte_count[3:0]] <= {w[byte_count[3:0]][23:0], data_in};
                    byte_count <= byte_count + 1;
                    state <= LOAD;
                end
            end
            
            LOAD: begin
                if (valid_in) begin
                    // Continue loading bytes
                    w[byte_count[3:0]] <= {w[byte_count[3:0]][23:0], data_in};
                    byte_count <= byte_count + 1;
                    
                    if (byte_count == 63) begin
                        state <= PAD;
                    end
                end else begin
                    // No more input, pad the message
                    state <= PAD;
                end
            end
            
            PAD: begin
                // Pad with 1 followed by zeros
                if (byte_count < 64) begin
                    if (byte_count[3:0] == 0) begin
                        w[byte_count[3:0]] <= 32'h80000000;
                    end else begin
                        w[byte_count[3:0]] <= 0;
                    end
                    byte_count <= byte_count + 1;
                end else begin
                    // Last two words are length (in bits, big-endian)
                    w[14] <= byte_count << 3; // Assuming message is < 2^32 bits
                    w[15] <= 0;
                    state <= EXPAND;
                    round <= 0;
                end
            end
            
            EXPAND: begin
                // Message schedule expansion using shift registers
                if (round < 16) begin
                    // First 16 words are just the message block
                    w_ext[round] <= w[round];
                    round <= round + 1;
                end else if (round < 64) begin
                    // Subsequent words are derived from previous words
                    w_ext[round] <= w_ext[round-16] + sigma0(w_ext[round-15]) + 
                                   w_ext[round-7] + sigma1(w_ext[round-2]);
                    round <= round + 1;
                end else begin
                    // Initialize working variables
                    a <= h0; b <= h1; c <= h2; d <= h3;
                    e <= h4; f <= h5; g <= h6; h <= h7;
                    state <= COMPRESS;
                    round <= 0;
                end
            end
            
            COMPRESS: begin
                if (round < 64) begin
                    // Compression function using shift registers
                    reg [31:0] temp1, temp2;
                    
                    temp1 = h + SIGMA1(e) + ch(e, f, g) + K[round] + w_ext[round];
                    temp2 = SIGMA0(a) + maj(a, b, c);
                    
                    // Shift working variables
                    h <= g;
                    g <= f;
                    f <= e;
                    e <= d + temp1;
                    d <= c;
                    c <= b;
                    b <= a;
                    a <= temp1 + temp2;
                    
                    round <= round + 1;
                end else begin
                    state <= UPDATE;
                end
            end
            
            UPDATE: begin
                // Update hash values
                h0 <= h0 + a;
                h1 <= h1 + b;
                h2 <= h2 + c;
                h3 <= h3 + d;
                h4 <= h4 + e;
                h5 <= h5 + f;
                h6 <= h6 + g;
                h7 <= h7 + h;
                
                // Check if we need to process another block
                if (byte_count >= 56) begin // Last block was processed
                    state <= OUTPUT;
                    output_count <= 0;
                end else begin
                    // Process next block
                    state <= IDLE;
                    byte_count <= 0;
                end
            end
            
            OUTPUT: begin
                // Output hash in 8-bit chunks using shift register approach
                valid_o <= 1;
                case (output_count)
                    0: hash_out <= h0[31:24];
                    1: hash_out <= h0[23:16];
                    2: hash_out <= h0[15:8];
                    3: hash_out <= h0[7:0];
                    4: hash_out <= h1[31:24];
                    5: hash_out <= h1[23:16];
                    6: hash_out <= h1[15:8];
                    7: hash_out <= h1[7:0];
                    8: hash_out <= h2[31:24];
                    9: hash_out <= h2[23:16];
                    10: hash_out <= h2[15:8];
                    11: hash_out <= h2[7:0];
                    12: hash_out <= h3[31:24];
                    13: hash_out <= h3[23:16];
                    14: hash_out <= h3[15:8];
                    15: hash_out <= h3[7:0];
                    16: hash_out <= h4[31:24];
                    17: hash_out <= h4[23:16];
                    18: hash_out <= h4[15:8];
                    19: hash_out <= h4[7:0];
                    20: hash_out <= h5[31:24];
                    21: hash_out <= h5[23:16];
                    22: hash_out <= h5[15:8];
                    23: hash_out <= h5[7:0];
                    24: hash_out <= h6[31:24];
                    25: hash_out <= h6[23:16];
                    26: hash_out <= h6[15:8];
                    27: hash_out <= h6[7:0];
                    28: hash_out <= h7[31:24];
                    29: hash_out <= h7[23:16];
                    30: hash_out <= h7[15:8];
                    31: hash_out <= h7[7:0];
                endcase
                
                output_count <= output_count + 1;
                if (output_count == 31) begin
                    state <= IDLE;
                    valid_o <= 0;
                end
            end
        endcase
    end
end

endmodule
