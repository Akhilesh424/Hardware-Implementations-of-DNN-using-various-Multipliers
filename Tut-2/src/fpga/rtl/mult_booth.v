`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// 16x16 Signed Booth Multiplier (Combinational)
// Latency = 0 cycles (matches original neuron timing)
//////////////////////////////////////////////////////////////////////////////////

module mult_booth #(
    parameter W = 16
)(
    input  signed [W-1:0]   a,
    input  signed [W-1:0]   b,
    output signed [2*W-1:0] p
);

    integer i;
    reg signed [W:0] booth;
    reg signed [2*W-1:0] acc;

    always @(*) begin
        acc   = 0;
        booth = {b, 1'b0};

        for (i = 0; i < W; i = i + 1) begin
            case ({booth[i+1], booth[i]})
                2'b01: acc = acc + (a <<< i);
                2'b10: acc = acc - (a <<< i);
                default: acc = acc;
            endcase
        end
    end

    assign p = acc;

endmodule
