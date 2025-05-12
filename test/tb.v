module tb();

// DUT signals
reg clk;
reg reset_n;
reg [7:0] ui;
reg [7:0] uio;
wire [7:0] uo;


// Test variables
integer i, j;
reg [7:0] test_message[0:63];
reg [7:0] expected_hash[0:31];
integer errors;

// Instantiate the DUT
tt_um_sha256_shift_reg dut (
    .clk(clk),
    .reset_n(reset_n),
    .ui(ui),
    .uio({6'b0, uio[1],uio[0]}),
    .uo(uo)
);
endmodule
