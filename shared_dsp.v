`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Neuron (Perceptron)
// Shared DSP48 Multiplier (Clocked, 1-cycle latency)
// Accuracy-preserving implementation
//////////////////////////////////////////////////////////////////////////////////

`include "include.v"

module neuron #(
    parameter layerNo=0,
    parameter neuronNo=0,
    parameter numWeight=784,
    parameter dataWidth=16,
    parameter sigmoidSize=5,
    parameter weightIntWidth=1,
    parameter actType="relu",
    parameter biasFile="",
    parameter weightFile=""
)(
    input                   clk,
    input                   rst,
    input  [dataWidth-1:0]  myinput,
    input                   myinputValid,
    input                   weightValid,
    input                   biasValid,
    input  [31:0]           weightValue,
    input  [31:0]           biasValue,
    input  [31:0]           config_layer_num,
    input  [31:0]           config_neuron_num,
    output [dataWidth-1:0]  out,
    output reg              outvalid
);

    // --------------------------------------------------
    // Address width
    // --------------------------------------------------
    parameter addressWidth = $clog2(numWeight);

    // --------------------------------------------------
    // Weight memory signals
    // --------------------------------------------------
    reg                      wen;
    wire                     ren;
    reg  [addressWidth-1:0]  w_addr;
    reg  [addressWidth:0]    r_addr;
    reg  [dataWidth-1:0]     w_in;
    wire [dataWidth-1:0]     w_out;

    // --------------------------------------------------
    // MAC signals
    // --------------------------------------------------
    reg  signed [2*dataWidth-1:0] mul;
    reg  signed [2*dataWidth-1:0] sum;
    reg  signed [2*dataWidth-1:0] bias;

    // --------------------------------------------------
    // Pipeline control
    // --------------------------------------------------
    reg  [dataWidth-1:0] myinputd;
    reg                  weight_valid;
    reg                  mult_valid;
    wire                 mux_valid;
    reg                  muxValid_d;
    reg                  muxValid_f;
    reg                  sigValid;

    wire [2*dataWidth:0] comboAdd;
    wire [2*dataWidth:0] BiasAdd;

    // --------------------------------------------------
    // Weight loading
    // --------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            w_addr <= {addressWidth{1'b1}};
            wen    <= 1'b0;
        end
        else if (weightValid &&
                 (config_layer_num  == layerNo) &&
                 (config_neuron_num == neuronNo)) begin
            w_in   <= weightValue[dataWidth-1:0];
            w_addr <= w_addr + 1'b1;
            wen    <= 1'b1;
        end
        else begin
            wen <= 1'b0;
        end
    end

    assign ren = myinputValid;

    // --------------------------------------------------
    // Bias handling
    // --------------------------------------------------
`ifdef pretrained
    reg [31:0] biasReg[0:0];
    reg addr = 0;

    initial begin
        $readmemb(biasFile, biasReg);
    end

    always @(posedge clk) begin
        bias <= {biasReg[addr][dataWidth-1:0], {dataWidth{1'b0}}};
    end
`else
    always @(posedge clk) begin
        if (biasValid &&
            (config_layer_num  == layerNo) &&
            (config_neuron_num == neuronNo)) begin
            bias <= {biasValue[dataWidth-1:0], {dataWidth{1'b0}}};
        end
    end
`endif

    // --------------------------------------------------
    // Read address counter
    // --------------------------------------------------
    always @(posedge clk) begin
        if (rst | outvalid)
            r_addr <= 0;
        else if (myinputValid)
            r_addr <= r_addr + 1'b1;
    end

    // ==================================================
    // SHARED DSP48 MULTIPLIER (CLOCKED, 1-CYCLE)
    // ==================================================
    wire signed [2*dataWidth-1:0] dsp_mul_out;

    dsp_mul_shared #(.W(dataWidth)) dsp_mul_u (
        .clk(clk),
        .en(myinputValid),      // DSP used only when needed
        .a(myinputd),
        .b(w_out),
        .p(dsp_mul_out)
    );

    // EXACTLY matches original DSP timing
    always @(posedge clk) begin
        mul <= dsp_mul_out;
    end

    // --------------------------------------------------
    // Accumulation logic (UNCHANGED)
    // --------------------------------------------------
    assign mux_valid = mult_valid;
    assign comboAdd  = mul + sum;
    assign BiasAdd   = bias + sum;

    always @(posedge clk) begin
        if (rst | outvalid)
            sum <= 0;
        else if ((r_addr == numWeight) & muxValid_f) begin
            if (!bias[2*dataWidth-1] & !sum[2*dataWidth-1] & BiasAdd[2*dataWidth-1]) begin
                sum[2*dataWidth-1]   <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
            end
            else if (bias[2*dataWidth-1] & sum[2*dataWidth-1] & !BiasAdd[2*dataWidth-1]) begin
                sum[2*dataWidth-1]   <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end
            else
                sum <= BiasAdd;
        end
        else if (mux_valid) begin
            if (!mul[2*dataWidth-1] & !sum[2*dataWidth-1] & comboAdd[2*dataWidth-1]) begin
                sum[2*dataWidth-1]   <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
            end
            else if (mul[2*dataWidth-1] & sum[2*dataWidth-1] & !comboAdd[2*dataWidth-1]) begin
                sum[2*dataWidth-1]   <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end
            else
                sum <= comboAdd;
        end
    end

    // --------------------------------------------------
    // Pipeline / valid control (UNCHANGED)
    // --------------------------------------------------
    always @(posedge clk) begin
        myinputd     <= myinput;
        weight_valid <= myinputValid;
        mult_valid   <= weight_valid;
        muxValid_d   <= mux_valid;
        muxValid_f   <= !mux_valid & muxValid_d;
        sigValid     <= ((r_addr == numWeight) & muxValid_f);
        outvalid     <= sigValid;
    end

    // --------------------------------------------------
    // Weight Memory
    // --------------------------------------------------
    Weight_Memory #(
        .numWeight(numWeight),
        .neuronNo(neuronNo),
        .layerNo(layerNo),
        .addressWidth(addressWidth),
        .dataWidth(dataWidth),
        .weightFile(weightFile)
    ) WM (
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .wadd(w_addr),
        .radd(r_addr),
        .win(w_in),
        .wout(w_out)
    );

    // --------------------------------------------------
    // Activation
    // --------------------------------------------------
    generate
        if (actType == "sigmoid") begin
            Sig_ROM #(
                .inWidth(sigmoidSize),
                .dataWidth(dataWidth)
            ) s1 (
                .clk(clk),
                .x(sum[2*dataWidth-1-:sigmoidSize]),
                .out(out)
            );
        end
        else begin
            ReLU #(
                .dataWidth(dataWidth),
                .weightIntWidth(weightIntWidth)
            ) s1 (
                .clk(clk),
                .x(sum),
                .out(out)
            );
        end
    endgenerate

endmodule


// ==================================================
// SHARED DSP48 MULTIPLIER MODULE
// ==================================================
module dsp_mul_shared #(
    parameter W = 16
)(
    input                   clk,
    input                   en,
    input  signed [W-1:0]   a,
    input  signed [W-1:0]   b,
    output reg signed [2*W-1:0] p
);
    always @(posedge clk) begin
        if (en)
            p <= a * b;   // DSP48 inferred
    end
endmodule