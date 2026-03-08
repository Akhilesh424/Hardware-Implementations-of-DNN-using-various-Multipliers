`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Updated: 2025 for Vivado (SystemVerilog)
// Original Date: 2018
// Design Name: zyNet Testbench
// Module Name: top_sim
// Description: SystemVerilog testbench with corrected $readmemb usage, 
//              explicit input port directions, and string-based file paths.
// 
//////////////////////////////////////////////////////////////////////////////////

`include "..\rtl\include.v"

`define MaxTestSamples 100

module top_sim;

    // ---------------- DUT Signals ----------------
    reg reset;
    reg clock;
    reg [`dataWidth-1:0] in;
    reg in_valid;
    reg [`dataWidth-1:0] in_mem [0:784];  // 784 pixels + 1 label
    reg [`dataWidth-1:0] expected;

    reg s_axi_awvalid;
    reg [31:0] s_axi_awaddr;
    wire s_axi_awready;
    reg [31:0] s_axi_wdata;
    reg s_axi_wvalid;
    wire s_axi_wready;
    wire s_axi_bvalid;
    reg s_axi_bready;
    wire intr;
    reg [31:0] axiRdData;
    reg [31:0] s_axi_araddr;
    wire [31:0] s_axi_rdata;
    reg s_axi_arvalid;
    wire s_axi_arready;
    wire s_axi_rvalid;
    reg s_axi_rready;

    // ---------------- Layer sizes ----------------
    wire [31:0] numNeurons[31:1];
    wire [31:0] numWeights[31:1];

    assign numNeurons[1] = 30;
    assign numNeurons[2] = 30;
    assign numNeurons[3] = 10;
    assign numNeurons[4] = 10;

    assign numWeights[1] = 784;
    assign numWeights[2] = 30;
    assign numWeights[3] = 30;
    assign numWeights[4] = 10;

    integer right = 0;
    integer wrong = 0;

    // ---------------- Instantiate DUT ----------------
    zyNet dut (
        .s_axi_aclk(clock),
        .s_axi_aresetn(reset),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awprot(0),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(4'hF),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arprot(0),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        .axis_in_data(in),
        .axis_in_data_valid(in_valid),
        .axis_in_data_ready(),
        .intr(intr)
    );

    // ---------------- Clock ----------------
    initial clock = 0;
    always #5 clock = ~clock;

    // ---------------- Reset ----------------
    initial begin
        reset = 0;
        in_valid = 0;
        s_axi_awvalid = 0;
        s_axi_bready = 0;
        s_axi_wvalid = 0;
        s_axi_arvalid = 0;
        #100 reset = 1;
    end

    // ---------------- Handshake ----------------
    always @(posedge clock) begin
        s_axi_bready <= s_axi_bvalid;
        s_axi_rready <= s_axi_rvalid;
    end

    // ---------------- AXI Write ----------------
    task automatic writeAxi(input [31:0] address, input [31:0] data);
    begin
        @(posedge clock);
        s_axi_awvalid <= 1'b1;
        s_axi_awaddr  <= address;
        s_axi_wdata   <= data;
        s_axi_wvalid  <= 1'b1;
        wait(s_axi_wready);
        @(posedge clock);
        s_axi_awvalid <= 0;
        s_axi_wvalid  <= 0;
        @(posedge clock);
    end
    endtask

    // ---------------- AXI Read ----------------
    task automatic readAxi(input [31:0] address);
    begin
        @(posedge clock);
        s_axi_arvalid <= 1'b1;
        s_axi_araddr  <= address;
        wait(s_axi_arready);
        @(posedge clock);
        s_axi_arvalid <= 0;
        wait(s_axi_rvalid);
        @(posedge clock);
        axiRdData <= s_axi_rdata;
        @(posedge clock);
    end
    endtask

    // ---------------- Config Weights ----------------
    task automatic configWeights();
        integer i, j, k, t;
        string fname;
        reg [`dataWidth:0] config_mem [0:783];
    begin
        @(posedge clock);
        for (k=1; k<=`numLayers; k++) begin
            writeAxi(12,k); // layer number
            for (j=0; j<numNeurons[k]; j++) begin
                fname = $sformatf("w_%0d_%0d.mif", k, j);
                $readmemb(fname, config_mem);
                writeAxi(16,j);
                for (t=0; t<numWeights[k]; t++) begin
                    writeAxi(0,{15'd0,config_mem[t]});
                end
            end
        end
    end
    endtask

    // ---------------- Config Bias ----------------
    task automatic configBias();
        integer j,k;
        string fname;
        reg [31:0] bias [0:0];
    begin
        @(posedge clock);
        for (k=1; k<=`numLayers; k++) begin
            writeAxi(12,k);
            for (j=0; j<numNeurons[k]; j++) begin
                fname = $sformatf("b_%0d_%0d.mif", k, j);
                $readmemb(fname, bias);
                writeAxi(16,j);
                writeAxi(4,{15'd0,bias[0]});
            end
        end
    end
    endtask

    // ---------------- Send Data ----------------
    task automatic sendData(input string fname);
        integer t;
    begin
        $readmemb(fname, in_mem);
        @(posedge clock); @(posedge clock); @(posedge clock);
        for (t=0; t<784; t++) begin
            @(posedge clock);
            in       <= in_mem[t];
            in_valid <= 1;
        end
        @(posedge clock);
        in_valid <= 0;
        expected = in_mem[784];  // label is last line
    end
    endtask

    // ---------------- Testbench Main ----------------
    integer testDataCount;
    string datafile;
    integer start;

    initial begin
        #200;
        writeAxi(28,0); // clear soft reset
        start = $time;

        `ifndef pretrained
            configWeights();
            configBias();
        `endif

        $display("Configuration completed in %0t ns", $time-start);

        start = $time;
        for (testDataCount=0; testDataCount<`MaxTestSamples; testDataCount++) begin
            datafile = $sformatf("test_data_%04d.txt", testDataCount);
            sendData(datafile);
            @(posedge intr);
            readAxi(8);
            if (axiRdData == expected)
                right++;
            else
                wrong++;
            $display("%0d. Accuracy: %f%%, Detected: %0x, Expected: %0x",
                     testDataCount+1, right*100.0/(testDataCount+1), axiRdData, expected);
        end

        $display("Final Accuracy: %f%%", right*100.0/`MaxTestSamples);
        $stop;
    end

endmodule