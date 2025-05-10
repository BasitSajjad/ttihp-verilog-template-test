module tb_sha256();

// DUT signals
reg clk;
reg reset_n;
reg [7:0] data_in;
reg valid_in;
wire [7:0] hash_out;
wire valid_o;

// Test variables
integer i, j;
reg [7:0] test_message[0:63];
reg [7:0] expected_hash[0:31];
integer errors;

// Instantiate the DUT
sha256_shift_reg dut (
    .clk(clk),
    .reset_n(reset_n),
    .data_in(data_in),
    .valid_in(valid_in),
    .hash_out(hash_out),
    .valid_o(valid_o)
);
endmodule
