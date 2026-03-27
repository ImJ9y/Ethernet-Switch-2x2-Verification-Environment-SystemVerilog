class packet_c;
    rand bit [31:0] SA;
    rand bit [31:0] DA;
    rand bit [31:0] data[$];

    bit [31:0] CRC;

    localparam bit [31:0] PORT_A = 32'h0000_0001;
    localparam bit [31:0] PORT_B = 32'h0000_0002;

    constraint size_c{
        data.size() inside {[2:5]};
    }
    constraint addr_c {
        SA inside {PORT_A, PORT_B};
        DA inside {PORT_A, PORT_B};
    }

    function void calc_crc();
        CRC = 0;
        CRC ^= SA;
        CRC ^= DA;

        foreach (data[i]) begin
            CRC ^= data[i];
        end
    endfunction

    function void display();
        $display("SA = %h DA = %h CRC = %h Data size = %h", SA, DA, CRC, data.size());

        foreach (data[i]) begin
            $display("DATA[%0d] = %h", i, data[i]);
        end
    endfunction
endclass

class packet_gen_c;
  rand int num_packets;

  mailbox #(packet_c) gen2drv_mb;
  mailbox #(packet_c) gen2chk_mb;

  constraint num_pkt_c {
    num_packets inside {[1:5]};
  }

  function new(mailbox #(packet_c) drv_mb,
               mailbox #(packet_c) chk_mb);
    this.gen2drv_mb = drv_mb;
    this.gen2chk_mb = chk_mb;
  endfunction

  task run();
    packet_c pkt;

    if (!this.randomize()) begin
      $display("GEN: failed to randomize num_packets");
      return;
    end

    $display("GEN: generating %0d packets", num_packets);

    repeat (num_packets) begin
      pkt = new();

      if (!pkt.randomize()) begin
        $display("GEN: packet randomization failed");
        continue;
      end

      pkt.calc_crc();

      $display("GEN: created packet");
      pkt.display();

      gen2drv_mb.put(pkt);
      gen2chk_mb.put(pkt);
    end
  endtask
endclass

// gen -> driv -> dut -> mon -> chk
class packet_drv_c;
  virtual eth_if.DRV intf;
  mailbox #(packet_c) gen2drv_mb;

  function new(virtual eth_if.DRV intf,
               mailbox #(packet_c) mb);
    this.intf = intf;
    this.gen2drv_mb = mb;
  endfunction

  task send_packet_A(packet_c pkt);
    begin
      @(intf.drv_cb);
      intf.drv_cb.inDataA <= pkt.DA;
      intf.drv_cb.inSopA  <= 1;
      intf.drv_cb.inEopA  <= 0;

      @(intf.drv_cb);
      intf.drv_cb.inDataA <= pkt.SA;
      intf.drv_cb.inSopA  <= 0;
      intf.drv_cb.inEopA  <= 0;

      foreach (pkt.data[i]) begin
        @(intf.drv_cb);
        intf.drv_cb.inDataA <= pkt.data[i];
        intf.drv_cb.inSopA  <= 0;
        intf.drv_cb.inEopA  <= 0;
      end

      @(intf.drv_cb);
      intf.drv_cb.inDataA <= pkt.CRC;
      intf.drv_cb.inSopA  <= 0;
      intf.drv_cb.inEopA  <= 1;

      @(intf.drv_cb);
      intf.drv_cb.inDataA <= 0;
      intf.drv_cb.inSopA  <= 0;
      intf.drv_cb.inEopA  <= 0;
    end
  endtask

  task send_packet_B(packet_c pkt);
    begin
      @(intf.drv_cb);
      intf.drv_cb.inDataB <= pkt.DA;
      intf.drv_cb.inSopB  <= 1;
      intf.drv_cb.inEopB  <= 0;

      @(intf.drv_cb);
      intf.drv_cb.inDataB <= pkt.SA;
      intf.drv_cb.inSopB  <= 0;
      intf.drv_cb.inEopB  <= 0;

      foreach (pkt.data[i]) begin
        @(intf.drv_cb);
        intf.drv_cb.inDataB <= pkt.data[i];
        intf.drv_cb.inSopB  <= 0;
        intf.drv_cb.inEopB  <= 0;
      end

      @(intf.drv_cb);
      intf.drv_cb.inDataB <= pkt.CRC;
      intf.drv_cb.inSopB  <= 0;
      intf.drv_cb.inEopB  <= 1;

      @(intf.drv_cb);
      intf.drv_cb.inDataB <= 0;
      intf.drv_cb.inSopB  <= 0;
      intf.drv_cb.inEopB  <= 0;
    end
  endtask

  task run();
    packet_c pkt;

    forever begin
      gen2drv_mb.get(pkt);

      $display("DRV: sending packet");
      pkt.display();

      // Route packet based on SOURCE port (input side)
      if (pkt.SA == packet_c::PORT_A)
        send_packet_A(pkt);
      else if (pkt.SA == packet_c::PORT_B)
        send_packet_B(pkt);
      else
        $display("DRV: unknown SA=%h", pkt.SA);
    end
  endtask
endclass

//gen -> drv -> dut -> mon -> chk
class packet_mon_c;

    virtual eth_if.MON intf;
    mailbox #(packet_c) mon2chk_mb;

    function new(virtual eth_if.MON intf, mailbox #(packet_c) mb);
        this.intf = intf;
        this.mon2chk_mb = mb;
    endfunction

    task run();
        packet_c pkt;

        forever begin
        @(intf.mon_cb);
        //Packet appears on output port A
        if (intf.mon_cb.outSopA) begin
            //Create a fresh packet object
            pkt = new();
            pkt.data = {};
            pkt.DA = intf.mon_cb.outDataA;

            @(intf.mon_cb);
            pkt.SA = intf.mon_cb.outDataA;

            forever begin
            @(intf.mon_cb);
            if (intf.mon_cb.outEopA) begin
                pkt.CRC = intf.mon_cb.outDataA;
                break;
            end
            else begin
                pkt.data.push_back(intf.mon_cb.outDataA);
            end
            end

            $display("MON: captured packet on PORT_A");
            pkt.display();
            mon2chk_mb.put(pkt);
        end

        else if (intf.mon_cb.outSopB) begin
            pkt = new();
            pkt.data = {};

            pkt.DA = intf.mon_cb.outDataB;

            @(intf.mon_cb);
            pkt.SA = intf.mon_cb.outDataB;

            forever begin
            @(intf.mon_cb);
            if (intf.mon_cb.outEopB) begin
                pkt.CRC = intf.mon_cb.outDataB;
                break;
            end
            else begin
                pkt.data.push_back(intf.mon_cb.outDataB);
            end
            end

            $display("MON: captured packet on PORT_B");
            pkt.display();
            mon2chk_mb.put(pkt);
        end
        end
    endtask
endclass

class packet_check_c;
    packet_c exp_q_A[$];
    packet_c exp_q_B[$];

    mailbox #(packet_c) gen2chk_mb;
    mailbox #(packet_c) mon2chk_mb;

    function new(mailbox #(packet_c) g2c_mb, mailbox #(packet_c) m2c_mb);
        this.gen2chk_mb = g2c_mb;
        this.mon2chk_mb = m2c_mb;
    endfunction

    task add_expected(packet_c pkt);
        packet_c pkt_copy;

        begin
        pkt_copy = new();
        pkt_copy.SA  = pkt.SA;
        pkt_copy.DA  = pkt.DA;
        pkt_copy.CRC = pkt.CRC;

        pkt_copy.data = {};
        foreach (pkt.data[i]) begin
            pkt_copy.data.push_back(pkt.data[i]);
        end

        if (pkt.DA == packet_c::PORT_A)
            exp_q_A.push_back(pkt_copy);
        else if (pkt.DA == packet_c::PORT_B)
            exp_q_B.push_back(pkt_copy);
        else
            $display("CHK: add_expected saw unknown DA=%h", pkt.DA);
        end
    endtask

    task check_packet(packet_c actual_pkt, string port_name);
        packet_c expected_pkt;
        int pass = 1;

        begin
        if (port_name == "PORT_A")begin
            if (exp_q_A.size() == 0)begin
                $display("FAIL: Unexpected packet on PORT_A (no expected packet)");
                return;
            end
            expected_pkt = exp_q_A.pop_front();
        end
        else if (port_name == "PORT_B")begin
            if (exp_q_B.size() == 0)begin
                $display("FAIL: Unexpected packet on PORT_B (no expected packet)");
                return;
            end
            expected_pkt = exp_q_B.pop_front();
        end
        else begin
            $display("FAIL: Unknown port %s", port_name);
            return;
        end

        if (expected_pkt.DA != actual_pkt.DA) begin
        $display("FAIL: DA mismatch exp=%h act=%h", expected_pkt.DA, actual_pkt.DA);
        pass = 0;
        end

        if (expected_pkt.SA != actual_pkt.SA) begin
            $display("FAIL: SA mismatch exp=%h act=%h", expected_pkt.SA, actual_pkt.SA);
            pass = 0;
        end

        if (expected_pkt.data.size() != actual_pkt.data.size()) begin
            $display("FAIL: size mismatch exp=%0d act=%0d",
                    expected_pkt.data.size(), actual_pkt.data.size());
            pass = 0;
        end
        else begin
            foreach (expected_pkt.data[i]) begin
            if (expected_pkt.data[i] != actual_pkt.data[i]) begin
                $display("FAIL: data[%0d] mismatch exp=%h act=%h",
                        i, expected_pkt.data[i], actual_pkt.data[i]);
                pass = 0;
            end
            end
        end

        if (expected_pkt.CRC != actual_pkt.CRC) begin
            $display("FAIL: CRC mismatch exp=%h act=%h",
                    expected_pkt.CRC, actual_pkt.CRC);
            pass = 0;
        end

        if (pass)
            $display("PASS: Actual packet on %s matches expected packet", port_name);

        $display("Actual Packet on %s:", port_name);
        actual_pkt.display();
        $display("Expected Packet:");
        expected_pkt.display();
        end
    endtask

    task run();
    packet_c in_pkt; // packet coming from generator side
    packet_c out_pkt;// packet coming from monitor side

    fork
      forever begin
        gen2chk_mb.get(in_pkt);
        add_expected(in_pkt);
      end

      forever begin
        mon2chk_mb.get(out_pkt);

        if (out_pkt.DA == packet_c::PORT_A)
          check_packet(out_pkt, "PORT_A");
        else if (out_pkt.DA == packet_c::PORT_B)
          check_packet(out_pkt, "PORT_B");
        else
          $display("FAIL: Unknown port DA=%h", out_pkt.DA);
      end
    join
  endtask
endclass


interface eth_if (input logic clk);
  logic reset;
  logic [31:0] inDataA;
  logic inSopA;
  logic inEopA;
  logic [31:0] inDataB;
  logic inSopB;
  logic inEopB;

  logic [31:0] outDataA;
  logic outSopA;
  logic outEopA;
  logic [31:0] outDataB;
  logic outSopB;
  logic outEopB;

  logic portAStall;
  logic portBStall;

  clocking drv_cb @(posedge clk);
    default input #2ns output #2ns;
    input clk;
    input outDataA, outSopA, outEopA, outDataB, outSopB, outEopB, portAStall, portBStall;
    output reset, inDataA, inSopA, inEopA, inDataB, inSopB, inEopB;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #2ns output #2ns;
    input clk, reset;
    input inDataA, inSopA, inEopA, inDataB, inSopB, inEopB;
    input outDataA, outSopA, outEopA, outDataB, outSopB, outEopB;
    input portAStall, portBStall;
  endclocking

  modport DRV (clocking drv_cb);
  modport MON (clocking mon_cb);

endinterface

module test_eth_swt_2x2();
    initial begin
      $display("Simulation started");
    end
  
    logic clk;

    // Interface
    eth_if intf(clk);

    eth_swt_2x2 dut (
        .clk(clk),
        .reset(intf.reset),
        .inDataA(intf.inDataA),
        .inSopA(intf.inSopA),
        .inEopA(intf.inEopA),
        .inDataB(intf.inDataB),
        .inSopB(intf.inSopB),
        .inEopB(intf.inEopB),

        .outDataA(intf.outDataA),
        .outSopA(intf.outSopA),
        .outEopA(intf.outEopA),
        .outDataB(intf.outDataB),
        .outSopB(intf.outSopB),
        .outEopB(intf.outEopB),

        .portAStall(intf.portAStall),
        .portBStall(intf.portBStall)
    );

    // Clock
    initial clk = 0;
    always #2 clk = ~clk;

    // Reset
    initial begin
        intf.reset = 1;
        repeat (5) @(posedge clk);
        intf.reset = 0;
    end

    initial begin
        wait(!intf.reset);
        $display("INFO: Reset deasserted, starting test...");
    end

    mailbox #(packet_c) gen2drv_mb;
    mailbox #(packet_c) gen2chk_mb;
    mailbox #(packet_c) mon2chk_mb;

    packet_gen_c   generator;
    packet_drv_c   driver;
    packet_mon_c   monitor;
    packet_check_c checker;

    // Environment
    initial begin
        gen2drv_mb = new();
        gen2chk_mb = new();
        mon2chk_mb = new();

        generator = new(gen2drv_mb, gen2chk_mb);
        driver    = new(intf, gen2drv_mb);
        monitor   = new(intf, mon2chk_mb);
        checker   = new(gen2chk_mb, mon2chk_mb);

        @(negedge intf.reset); //Wait until reset is released before starting the test

        fork
        generator.run();
        driver.run();
        monitor.run();
        checker.run();
        join_none
    end

    // End simulation
    initial begin
        #1000;
        $finish;
    end

endmodule