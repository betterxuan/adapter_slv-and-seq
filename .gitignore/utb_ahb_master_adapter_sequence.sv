//--------------------------------------------------------------------
// @Brief Description: utb command to ahb trans adapter sequence
//====================================================================

`ifndef UTB_AHB_MASTER_ADAPTER_SEQUENCE_SV
`define UTB_AHB_MASTER_ADAPTER_SEQUENCE_SV

class utb_ahb_master_adapter_sequence extends svt_ahb_master_transaction_base_sequence;

  /** UVM Object Utility macro */
  local svt_ahb_master_transaction ahb_trans[string];
  local svt_ahb_master_transaction cur_trans;
  local mailbox #(utb_cmd_packet_t) req_cmd_pkt_mb;
  local mailbox #(utb_cmd_packet_t) rsp_cmd_pkt_mb;

  `uvm_object_utils(utb_ahb_master_adapter_sequence)

  /** Class Constructor */
  function new(string name="utb_ahb_master_adapter_sequence");
    super.new(name);
    req_cmd_pkt_mb = new();
    rsp_cmd_pkt_mb = new();
  endfunction
  
  virtual task body();
    svt_configuration get_cfg;
    utb_cmd_packet_t cmd_pkt;
    `uvm_info("body", "Entered ...", UVM_LOW)
    super.body();

    /** Obtain a handle to the port configuration */
    p_sequencer.get_cfg(get_cfg);
    if (!$cast(cfg, get_cfg)) begin
      `uvm_fatal("body", "Unable to $cast the configuration to a svt_ahb_port_configuration class");
    end

    create_ahb_trans();

    forever begin
      req_cmd_pkt_mb.get(cmd_pkt);
      cmd2trans(cmd_pkt);
      rsp_cmd_pkt_mb.put(cmd_pkt);
    end

    `uvm_info("body", "Exiting ...", UVM_LOW)
  endtask: body

  local function void create_ahb_trans();
    svt_ahb_master_transaction trans;

    //trans = svt_ahb_master_transaction::type_id::create("single");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::SINGLE;
                            data.size() == 1;
                            };
    ahb_trans["single"] = trans;

    //trans = svt_ahb_master_transaction::type_id::create("incr");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::INCR;
                            data.size() == 32;
                            };
    ahb_trans["incr"] = trans;

    //trans = svt_ahb_master_transaction::type_id::create("wrap4");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::WRAP4;
                            data.size() == 4;
                            };
    ahb_trans["wrap4"] = trans;

    //trans = svt_ahb_master_transaction::type_id::create("incr4");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::INCR4;
                            data.size() == 4;
                            };
    ahb_trans["incr4"] = trans;
    
    //trans = svt_ahb_master_transaction::type_id::create("wrap8");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::WRAP8;
                            data.size() == 8;
                            };
    ahb_trans["wrap8"] = trans;

    //trans = svt_ahb_master_transaction::type_id::create("incr8");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::INCR8;
                            data.size() == 8;
                            };
    ahb_trans["incr8"] = trans;

    //trans = svt_ahb_master_transaction::type_id::create("wrap16");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::WRAP16;
                            data.size() == 16;
                            };
    ahb_trans["wrap16"] = trans;

    //trans = svt_ahb_master_transaction::type_id::create("incr16");
    `uvm_create(trans)
    trans.cfg = cfg;
    trans.randomize() with {burst_type == svt_ahb_transaction::INCR16;
                            data.size() == 16;
                            };
    ahb_trans["incr16"] = trans;
  endfunction

  local function void set_default_trans(svt_ahb_master_transaction trans
                                        ,int unsigned addr
                                        ,svt_ahb_transaction::xact_type_enum xact
                                        ,int burst_size = cfg.data_width >> 3
                                      );
    trans.xact_type = xact;
    trans.addr = addr;
    case(burst_size)
      1:  trans.burst_size = svt_ahb_transaction::BURST_SIZE_8BIT;
      2:  trans.burst_size = svt_ahb_transaction::BURST_SIZE_16BIT;
      4:  trans.burst_size = svt_ahb_transaction::BURST_SIZE_32BIT;
      8:  trans.burst_size = svt_ahb_transaction::BURST_SIZE_64BIT;
      default: begin
        if(burst_size > 8) begin
          `uvm_warning("TRANS_SIZE", $sformatf("trans size %0d is set default value 8", AHB_NET_DATA_WIDTH))
          trans.burst_size = svt_ahb_transaction::BURST_SIZE_64BIT;
        end
      end
    endcase
    
  endfunction

  virtual task cmd2trans(ref utb_cmd_packet_t cmd_pkt);
    int trans_len = 1;
    int burst_size = AHB_NET_DATA_WIDTH;
    `uvm_info("CMD2TRANS", $sformatf("get command type %s with date length %0d", cmd_pkt.cmd, cmd_pkt.data.size()), UVM_LOW)

    if(!is_valid(cmd_pkt))
      `uvm_fatal("CMD2TRANS", "cmd_pkt check failure via is_valid() method")

    case(cmd_pkt.cmd)
      utb_common_pkg::WBURST: begin 
        trans_len = cmd_pkt.len;
        cur_trans = get_trans(trans_len);
        set_default_trans(cur_trans, cmd_pkt.addr, svt_ahb_transaction::WRITE);
      end
      utb_common_pkg::RBURST: begin
        trans_len = cmd_pkt.data[0];
        cur_trans = get_trans(trans_len);
        set_default_trans(cur_trans, cmd_pkt.addr, svt_ahb_transaction::READ);
        return; // setup the read trans and wait UTB_READ to trigger
      end
      utb_common_pkg::WDATA: begin 
        trans_len = 1;
        burst_size = cmd_pkt.size;
        cur_trans = get_trans(trans_len);
        set_default_trans(cur_trans, cmd_pkt.addr,svt_ahb_transaction::WRITE, burst_size);
      end
      utb_common_pkg::RDATA: begin
        trans_len = 1;
        burst_size = cmd_pkt.size;
        cur_trans = get_trans(trans_len);
        set_default_trans(cur_trans, cmd_pkt.addr, svt_ahb_transaction::READ, burst_size);
        return; // setup the read trans and wait UTB_READ to trigger
      end
      utb_common_pkg::UTB_READ: begin

      end
      default: begin
        `uvm_error("CMD2TRANS", $sformatf("command type %s is not a valid type", cmd_pkt.cmd))
        return;
      end
    endcase

    if(cmd_pkt.tlm_cmd == UVM_TLM_WRITE_COMMAND) begin
      foreach(cur_trans.data[i]) cur_trans.data[i] = cmd_pkt.data[i];
    end
    
    `uvm_info("CMD2TRANS", $sformatf("Started transfering items"), UVM_LOW)
    start_item(cur_trans);

    finish_item(cur_trans);

    get_response(rsp);

    case(cmd_pkt.cmd)
      utb_common_pkg::UTB_READ: begin
        cmd_pkt.data = new[cur_trans.get_burst_length()];
        foreach(cmd_pkt.data[i]) begin
          cmd_pkt.data[i] = rsp.data[i];
        end
      end
    endcase
    `uvm_info("CMD2TRANS", $sformatf("Finished transfering items"), UVM_LOW)
  endtask

  local function svt_ahb_master_transaction get_trans(int length);
    svt_ahb_master_transaction trans;
    case(length)
      1: begin
        trans = ahb_trans["single"];
      end
      4: begin
        trans = ahb_trans["incr4"];
      end
      8: begin
        trans = ahb_trans["incr8"];
      end
      16: begin
        trans = ahb_trans["incr16"];
      end
      0: begin
        `uvm_error("CMDPSR", $sformatf("received data size should not be 0!"))
      end
      default: begin
        // resize the INCR sequence data size
        ahb_trans["incr"].randomize() with {burst_type == svt_ahb_transaction::INCR;
                                            data.size() == length;
                                            };
        trans = ahb_trans["incr"];
      end
    endcase
    return trans;
  endfunction

  local function bit is_valid(utb_cmd_packet_t cmd_pkt);
    case(cmd_pkt.cmd)
      utb_common_pkg::WBURST: begin
        if(cmd_pkt.len < 1) begin
          `uvm_error("ISVLD", "WBURST data length should be larger than 1")
          return 0;
        end
      end
      utb_common_pkg::RBURST: begin
        if(cmd_pkt.len < 1) begin
          `uvm_error("ISVLD", "RBURST data length should be larger than 1")
          return 0;
        end
      end
    endcase
    return 1;
  endfunction

  task put_cmd_pkt_req(utb_cmd_packet_t cmd_pkt);
    req_cmd_pkt_mb.put(cmd_pkt);
  endtask

  task get_cmd_pkt_rsp(output utb_cmd_packet_t cmd_pkt);
    rsp_cmd_pkt_mb.get(cmd_pkt);
  endtask

endclass: utb_ahb_master_adapter_sequence

`endif // UTB_AHB_MASTER_ADAPTER_SEQUENCE_SV
