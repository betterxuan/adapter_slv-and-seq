//--------------------------------------------------------------------
// @Brief Description: utb to ahb master programming interface
//====================================================================

`ifndef UTB_AHB_SLAVE_SV
`define UTB_AHB_SLAVE_SV

class utb_ahb_slave extends utb_common_slave;

  svt_ahb_master_transaction_sequencer mst_sqr;
  svt_ahb_slave_sequencer slv_sqr;
  utb_ahb_master_adapter_sequence mst_adapter;
  utb_ahb_slave_adapter_sequence slv_adapter;

  `uvm_component_utils(utb_ahb_slave)

  function new(string name = "utb_ahb_slave", uvm_component parent);
    super.new(name,parent);
  endfunction: new

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(mode == MASTER_AGENT_MODE) begin
      mst_adapter = utb_ahb_master_adapter_sequence::type_id::create("mst_adapter");
    end
    else if(mode == SLAVE_AGENT_MODE) begin
      slv_adapter = utb_ahb_slave_adapter_sequence::type_id::create("slv_adapter");
    end
  endfunction: build_phase

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork 
      if(mode == MASTER_AGENT_MODE) begin
        mst_adapter.start(mst_sqr);
      end
      else if(mode == SLAVE_AGENT_MODE) begin
        slv_adapter.start(slv_sqr);
      end
    join_none
  endtask


  virtual task cmd_parser();
    utb_cmd_packet_t req, rsp;
    forever begin
      wait(cmd_packet_put_q.size() > 0);
      req = cmd_packet_put_q.pop_front();
      `uvm_info("cmd_parser", $sformatf("received command packet %s", req.cmd), UVM_HIGH)
      if(mode == MASTER_AGENT_MODE) begin
        mst_adapter.put_cmd_pkt_req(req);
        mst_adapter.get_cmd_pkt_rsp(rsp);
      end
      else if(mode == SLAVE_AGENT_MODE) begin
        slv_adapter.put_cmd_pkt_req(req);
        slv_adapter.get_cmd_pkt_rsp(rsp);
      end
      if(rsp.cmd == UTB_READ) begin
        data_get_mb.put(rsp);
      end
      finish_tlm2_trans();
    end
  endtask

endclass

`endif
