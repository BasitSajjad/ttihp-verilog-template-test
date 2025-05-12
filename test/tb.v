module tb();

// DUT signals
reg clk;
reg reset_n;
reg ena;
reg [7:0] ui;
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
    .uio_out({uio_out}),
    .uio_in({7'b0, uio_in[0]}),
    .uio_oe(uio_oe),
    .uo(uo)
);
endmodule
