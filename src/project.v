module tt_um_sha256_shift_reg (
    input wire clk,
    input wire rst_n,
    input wire [7:0] ui_in,
    input  wire [7:0] uio_in,   // IOs: Input path
    output reg [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    output reg [7:0] uo_out
);
reg busy;
// SHA-256 constants - defined individually
localparam [31:0] K00 = 32'h428a2f98; localparam [31:0] K01 = 32'h71374491;
localparam [31:0] K02 = 32'hb5c0fbcf; localparam [31:0] K03 = 32'he9b5dba5;
localparam [31:0] K04 = 32'h3956c25b; localparam [31:0] K05 = 32'h59f111f1;
localparam [31:0] K06 = 32'h923f82a4; localparam [31:0] K07 = 32'hab1c5ed5;
localparam [31:0] K08 = 32'hd807aa98; localparam [31:0] K09 = 32'h12835b01;
localparam [31:0] K10 = 32'h243185be; localparam [31:0] K11 = 32'h550c7dc3;
localparam [31:0] K12 = 32'h72be5d74; localparam [31:0] K13 = 32'h80deb1fe;
localparam [31:0] K14 = 32'h9bdc06a7; localparam [31:0] K15 = 32'hc19bf174;
localparam [31:0] K16 = 32'he49b69c1; localparam [31:0] K17 = 32'hefbe4786;
localparam [31:0] K18 = 32'h0fc19dc6; localparam [31:0] K19 = 32'h240ca1cc;
localparam [31:0] K20 = 32'h2de92c6f; localparam [31:0] K21 = 32'h4a7484aa;
localparam [31:0] K22 = 32'h5cb0a9dc; localparam [31:0] K23 = 32'h76f988da;
localparam [31:0] K24 = 32'h983e5152; localparam [31:0] K25 = 32'ha831c66d;
localparam [31:0] K26 = 32'hb00327c8; localparam [31:0] K27 = 32'hbf597fc7;
localparam [31:0] K28 = 32'hc6e00bf3; localparam [31:0] K29 = 32'hd5a79147;
localparam [31:0] K30 = 32'h06ca6351; localparam [31:0] K31 = 32'h14292967;
localparam [31:0] K32 = 32'h27b70a85; localparam [31:0] K33 = 32'h2e1b2138;
localparam [31:0] K34 = 32'h4d2c6dfc; localparam [31:0] K35 = 32'h53380d13;
localparam [31:0] K36 = 32'h650a7354; localparam [31:0] K37 = 32'h766a0abb;
localparam [31:0] K38 = 32'h81c2c92e; localparam [31:0] K39 = 32'h92722c85;
localparam [31:0] K40 = 32'ha2bfe8a1; localparam [31:0] K41 = 32'ha81a664b;
localparam [31:0] K42 = 32'hc24b8b70; localparam [31:0] K43 = 32'hc76c51a3;
localparam [31:0] K44 = 32'hd192e819; localparam [31:0] K45 = 32'hd6990624;
localparam [31:0] K46 = 32'hf40e3585; localparam [31:0] K47 = 32'h106aa070;
localparam [31:0] K48 = 32'h19a4c116; localparam [31:0] K49 = 32'h1e376c08;
localparam [31:0] K50 = 32'h2748774c; localparam [31:0] K51 = 32'h34b0bcb5;
localparam [31:0] K52 = 32'h391c0cb3; localparam [31:0] K53 = 32'h4ed8aa4a;
localparam [31:0] K54 = 32'h5b9cca4f; localparam [31:0] K55 = 32'h682e6ff3;
localparam [31:0] K56 = 32'h748f82ee; localparam [31:0] K57 = 32'h78a5636f;
localparam [31:0] K58 = 32'h84c87814; localparam [31:0] K59 = 32'h8cc70208;
localparam [31:0] K60 = 32'h90befffa; localparam [31:0] K61 = 32'ha4506ceb;
localparam [31:0] K62 = 32'hbef9a3f7; localparam [31:0] K63 = 32'hc67178f2;

// Initial hash values
localparam [31:0] H0_INIT = 32'h6a09e667;
localparam [31:0] H1_INIT = 32'hbb67ae85;
localparam [31:0] H2_INIT = 32'h3c6ef372;
localparam [31:0] H3_INIT = 32'ha54ff53a;
localparam [31:0] H4_INIT = 32'h510e527f;
localparam [31:0] H5_INIT = 32'h9b05688c;
localparam [31:0] H6_INIT = 32'h1f83d9ab;
localparam [31:0] H7_INIT = 32'h5be0cd19;

// Shift registers for message schedule
reg [31:0] w [0:15];  // 16-word message block
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
assign  uio_oe = 8'b00000010;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        for (integer i = 0; i < 16; i = i + 1) w[i] <= 0;
        for (integer i = 0; i < 48; i = i + 1) w_ext[i] <= 0;
        
        h0 <= H0_INIT; h1 <= H1_INIT; h2 <= H2_INIT; h3 <= H3_INIT;
        h4 <= H4_INIT; h5 <= H5_INIT; h6 <= H6_INIT; h7 <= H7_INIT;
        
        byte_count <= 0;
        round <= 0;
        state <= IDLE;
        output_count <= 0;
        uio_out <= 8'b0;
        uo_out <= 0;
        busy <= 0;
    end else begin
        case (state)
            IDLE: begin
                uio_out[1] <= 0;
                if (uio_in[0]) begin
                    // Shift in new byte
                    w[byte_count[3:0]] <= {w[byte_count[3:0]][23:0], ui_in};
                    byte_count <= byte_count + 1;
                    state <= LOAD;
                    busy <= 1;
                end
            end
            
            LOAD: begin
                if (uio_in[0]) begin
                    // Continue loading bytes
                    w[byte_count[3:0]] <= {w[byte_count[3:0]][23:0], ui_in};
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
                    
                    // Select the appropriate K constant
                    case (round)
                        0: temp1 = h + SIGMA1(e) + ch(e, f, g) + K00 + w_ext[round];
                        1: temp1 = h + SIGMA1(e) + ch(e, f, g) + K01 + w_ext[round];
                        2: temp1 = h + SIGMA1(e) + ch(e, f, g) + K02 + w_ext[round];
                        3: temp1 = h + SIGMA1(e) + ch(e, f, g) + K03 + w_ext[round];
                        4: temp1 = h + SIGMA1(e) + ch(e, f, g) + K04 + w_ext[round];
                        5: temp1 = h + SIGMA1(e) + ch(e, f, g) + K05 + w_ext[round];
                        6: temp1 = h + SIGMA1(e) + ch(e, f, g) + K06 + w_ext[round];
                        7: temp1 = h + SIGMA1(e) + ch(e, f, g) + K07 + w_ext[round];
                        8: temp1 = h + SIGMA1(e) + ch(e, f, g) + K08 + w_ext[round];
                        9: temp1 = h + SIGMA1(e) + ch(e, f, g) + K09 + w_ext[round];
                        10: temp1 = h + SIGMA1(e) + ch(e, f, g) + K10 + w_ext[round];
                        11: temp1 = h + SIGMA1(e) + ch(e, f, g) + K11 + w_ext[round];
                        12: temp1 = h + SIGMA1(e) + ch(e, f, g) + K12 + w_ext[round];
                        13: temp1 = h + SIGMA1(e) + ch(e, f, g) + K13 + w_ext[round];
                        14: temp1 = h + SIGMA1(e) + ch(e, f, g) + K14 + w_ext[round];
                        15: temp1 = h + SIGMA1(e) + ch(e, f, g) + K15 + w_ext[round];
                        16: temp1 = h + SIGMA1(e) + ch(e, f, g) + K16 + w_ext[round];
                        17: temp1 = h + SIGMA1(e) + ch(e, f, g) + K17 + w_ext[round];
                        18: temp1 = h + SIGMA1(e) + ch(e, f, g) + K18 + w_ext[round];
                        19: temp1 = h + SIGMA1(e) + ch(e, f, g) + K19 + w_ext[round];
                        20: temp1 = h + SIGMA1(e) + ch(e, f, g) + K10 + w_ext[round];
                        21: temp1 = h + SIGMA1(e) + ch(e, f, g) + K11 + w_ext[round];
                        22: temp1 = h + SIGMA1(e) + ch(e, f, g) + K12 + w_ext[round];
                        23: temp1 = h + SIGMA1(e) + ch(e, f, g) + K13 + w_ext[round];
                        24: temp1 = h + SIGMA1(e) + ch(e, f, g) + K14 + w_ext[round];
                        25: temp1 = h + SIGMA1(e) + ch(e, f, g) + K15 + w_ext[round];
                        26: temp1 = h + SIGMA1(e) + ch(e, f, g) + K16 + w_ext[round];
                        27: temp1 = h + SIGMA1(e) + ch(e, f, g) + K17 + w_ext[round];
                        28: temp1 = h + SIGMA1(e) + ch(e, f, g) + K18 + w_ext[round];
                        29: temp1 = h + SIGMA1(e) + ch(e, f, g) + K19 + w_ext[round];
                        30: temp1 = h + SIGMA1(e) + ch(e, f, g) + K20 + w_ext[round];
                        31: temp1 = h + SIGMA1(e) + ch(e, f, g) + K21 + w_ext[round];
                        32: temp1 = h + SIGMA1(e) + ch(e, f, g) + K22 + w_ext[round];
                        33: temp1 = h + SIGMA1(e) + ch(e, f, g) + K23 + w_ext[round];
                        34: temp1 = h + SIGMA1(e) + ch(e, f, g) + K24 + w_ext[round];
                        35: temp1 = h + SIGMA1(e) + ch(e, f, g) + K25 + w_ext[round];
                        36: temp1 = h + SIGMA1(e) + ch(e, f, g) + K26 + w_ext[round];
                        37: temp1 = h + SIGMA1(e) + ch(e, f, g) + K27 + w_ext[round];
                        38: temp1 = h + SIGMA1(e) + ch(e, f, g) + K28 + w_ext[round];
                        39: temp1 = h + SIGMA1(e) + ch(e, f, g) + K29 + w_ext[round];
                        30: temp1 = h + SIGMA1(e) + ch(e, f, g) + K30 + w_ext[round];
                        31: temp1 = h + SIGMA1(e) + ch(e, f, g) + K31 + w_ext[round];
                        32: temp1 = h + SIGMA1(e) + ch(e, f, g) + K32 + w_ext[round];
                        33: temp1 = h + SIGMA1(e) + ch(e, f, g) + K33 + w_ext[round];
                        34: temp1 = h + SIGMA1(e) + ch(e, f, g) + K34 + w_ext[round];
                        35: temp1 = h + SIGMA1(e) + ch(e, f, g) + K35 + w_ext[round];
                        36: temp1 = h + SIGMA1(e) + ch(e, f, g) + K36 + w_ext[round];
                        37: temp1 = h + SIGMA1(e) + ch(e, f, g) + K37 + w_ext[round];
                        38: temp1 = h + SIGMA1(e) + ch(e, f, g) + K38 + w_ext[round];
                        39: temp1 = h + SIGMA1(e) + ch(e, f, g) + K39 + w_ext[round];
                        40: temp1 = h + SIGMA1(e) + ch(e, f, g) + K40 + w_ext[round];
                        41: temp1 = h + SIGMA1(e) + ch(e, f, g) + K41 + w_ext[round];
                        42: temp1 = h + SIGMA1(e) + ch(e, f, g) + K42 + w_ext[round];
                        43: temp1 = h + SIGMA1(e) + ch(e, f, g) + K43 + w_ext[round];
                        44: temp1 = h + SIGMA1(e) + ch(e, f, g) + K44 + w_ext[round];
                        45: temp1 = h + SIGMA1(e) + ch(e, f, g) + K45 + w_ext[round];
                        46: temp1 = h + SIGMA1(e) + ch(e, f, g) + K46 + w_ext[round];
                        47: temp1 = h + SIGMA1(e) + ch(e, f, g) + K47 + w_ext[round];
                        48: temp1 = h + SIGMA1(e) + ch(e, f, g) + K48 + w_ext[round];
                        49: temp1 = h + SIGMA1(e) + ch(e, f, g) + K49 + w_ext[round];
                        50: temp1 = h + SIGMA1(e) + ch(e, f, g) + K50 + w_ext[round];
                        51: temp1 = h + SIGMA1(e) + ch(e, f, g) + K51 + w_ext[round];
                        52: temp1 = h + SIGMA1(e) + ch(e, f, g) + K52 + w_ext[round];
                        53: temp1 = h + SIGMA1(e) + ch(e, f, g) + K53 + w_ext[round];
                        54: temp1 = h + SIGMA1(e) + ch(e, f, g) + K54 + w_ext[round];
                        55: temp1 = h + SIGMA1(e) + ch(e, f, g) + K55 + w_ext[round];
                        56: temp1 = h + SIGMA1(e) + ch(e, f, g) + K56 + w_ext[round];
                        57: temp1 = h + SIGMA1(e) + ch(e, f, g) + K57 + w_ext[round];
                        58: temp1 = h + SIGMA1(e) + ch(e, f, g) + K58 + w_ext[round];
                        59: temp1 = h + SIGMA1(e) + ch(e, f, g) + K59 + w_ext[round];
                        60: temp1 = h + SIGMA1(e) + ch(e, f, g) + K60 + w_ext[round];
                        61: temp1 = h + SIGMA1(e) + ch(e, f, g) + K61 + w_ext[round];
                        62: temp1 = h + SIGMA1(e) + ch(e, f, g) + K62 + w_ext[round];
                        63: temp1 = h + SIGMA1(e) + ch(e, f, g) + K63 + w_ext[round];
                        default: temp1 = 0;
                    endcase
                    
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
                // Output hash in 8-bit chunks
                uio_out[1] <= 1;
                case (output_count)
                    0: uo_out <= h0[31:24];
                    1: uo_out <= h0[23:16];
                    2: uo_out <= h0[15:8];
                    3: uo_out <= h0[7:0];
                    4: uo_out <= h1[31:24];
                    5: uo_out <= h1[23:16];
                    6: uo_out <= h1[15:8];
                    7: uo_out <= h1[7:0];
                    8: uo_out <= h2[31:24];
                    9: uo_out <= h2[23:16];
                    10: uo_out <= h2[15:8];
                    11: uo_out <= h2[7:0];
                    12: uo_out <= h3[31:24];
                    13: uo_out <= h3[23:16];
                    14: uo_out <= h3[15:8];
                    15: uo_out <= h3[7:0];
                    16: uo_out <= h4[31:24];
                    17: uo_out <= h4[23:16];
                    18: uo_out <= h4[15:8];
                    19: uo_out <= h4[7:0];
                    20: uo_out <= h5[31:24];
                    21: uo_out <= h5[23:16];
                    22: uo_out <= h5[15:8];
                    23: uo_out <= h5[7:0];
                    24: uo_out <= h6[31:24];
                    25: uo_out <= h6[23:16];
                    26: uo_out <= h6[15:8];
                    27: uo_out <= h6[7:0];
                    28: uo_out <= h7[31:24];
                    29: uo_out <= h7[23:16];
                    30: uo_out <= h7[15:8];
                    31: uo_out <= h7[7:0];
                endcase
                
                output_count <= output_count + 1;
                if (output_count == 31) begin
                    state <= IDLE;
                    uio_out[1] <= 0;
                    busy <= 0;
                end
            end
        endcase
    end
end
    wire _unused = &{ena, uio_in, uio_oe[7:2], uio_out[7:2], 1'b0};
endmodule
