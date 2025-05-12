module tb();

// DUT signals
reg clk;
reg reset_n;
reg ena;
reg [7:0] ui_in;
reg [7:0] uio_in;
wire [7:0] uo_out;
wire [7:0] uio_out;
wire [7:0] uio_oe;

// Test variables
integer i, j;
reg [7:0] test_message[0:63];
reg [7:0] expected_hash[0:31];
integer errors;

// Instantiate the DUT
tt_um_sha256_shift_reg dut (
    .clk(clk),
    .reset_n(reset_n),
    .ena(1'b1),
    .ui(ui),
    .uio_out({6'b0, uio_out[1],1'b0}),
    .uio_in({7'b0, uio_in[0]}),
    .uio_oe({6'b0, 1'b1, 1'b0}),
    .uo(uo)
);
endmodule
