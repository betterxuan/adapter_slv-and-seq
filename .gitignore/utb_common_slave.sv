/**
 * Abstract:
 *  This component implements basic functions of a UTB common slave with Generic Payload TLM transactions. 
 *  It should be connected to a standard AMBA slave agent so that the coressponding bus transactions can 
 *  be translated to the TLM transactions.
 */

`ifndef GUARD_UTB_COMMON_SLAVE_SV
`define GUARD_UTB_COMMON_SLAVE_SV


class utb_common_slave extends utb_common_component;

  typedef enum {CMD, ADDR, ADDON, SIZE, LEN, DATA} state_t;
  utb_agent_mode_t mode;
  /** UVM Component Utility macro */
  `uvm_component_utils(utb_common_slave)

  /** Backward snoop transaction transport interface */
  uvm_tlm_b_target_socket#(utb_common_slave, uvm_tlm_generic_payload) b_resp;

  svt_mem mem;
 
  local uvm_tlm_generic_payload cur_gp;
  local net_data_t data_q[$];
  protected utb_cmd_packet_t cmd_packet_put_q[$];
  protected mailbox #(utb_cmd_packet_t) data_get_mb;
  local semaphore b_trans_key;
  local bit is_new_read;
  local int cur_master_id;

  /** Class Constructor */
  function new(string name = "utb_common_slave", uvm_component parent=null);
    super.new(name,parent);

    b_resp = new("b_resp", this);
    b_trans_key = new();
    is_new_read = 1;
    data_get_mb = new();
    mode = `DEFAULT_AGENT_MODE;
  endfunction: new

  task run_phase(uvm_phase phase);
    super.run_phase(phase);
    fork
      cmd_formatter();
      cmd_parser();
    join_none
  endtask
  /**
   * Build Phase
   * - Create and apply the customized configuration transaction factory
   * - Create the TB ENV
   * - Set the default sequences
   */
  virtual function void build_phase(uvm_phase phase);
    `uvm_info("build_phase", "Entered...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#(int)::get(this, "", "mode", mode))
      `uvm_info("CFG", "no mode is set, and applied default MASTER_AGENT_MODE", UVM_HIGH)

    `uvm_info("build_phase", "Exiting...", UVM_LOW)
  endfunction: build_phase

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
  endfunction

  /**
   * Implementation of the backward path
   * 
   * Fullfill slave request using a memory model
   */
  virtual task b_transport(uvm_tlm_generic_payload gp,
                   uvm_tlm_time            delay);
    net_data_t pdata[];
    byte unsigned glb[];
    net_data_t gdata[];
    utb_cmd_packet_t cmd_pkt;
    cur_gp = gp;
    format_pdata(gp, pdata);
    foreach(pdata[i]) data_q.push_back(pdata[i]); 
    
    wait_tlm2_trans_rsp();
    if(gp.get_command() == UVM_TLM_READ_COMMAND) begin
      data_get_mb.get(cmd_pkt);
      trans2lb(cmd_pkt.data, glb);
      gp.set_data_length(glb.size());
      gp.set_data(glb);
      is_new_read = 1;
    end

    gp.m_response_status = UVM_TLM_OK_RESPONSE;
    `uvm_info(get_type_name(), $sformatf("TLM SLV RESPONSE:\n%s", gp.sprint()), UVM_LOW);
  endtask

  local function void format_pdata(uvm_tlm_generic_payload gp, output net_data_t pdata[]);
    byte unsigned plb[];
    utb_cmd_addon_t addon;
    case(gp.get_command())
      UVM_TLM_WRITE_COMMAND: begin
        gp.get_data(plb);
        lb2trans(plb, pdata);
      end
      UVM_TLM_READ_COMMAND: begin
        if(is_new_read) begin
          addon.master_id = this.cur_master_id;
          addon.slave_id = this.id;
          pdata = {unsigned'(UTB_READ), gp.get_address(), addon, AHB_NET_BYTES_NUM, 'h0};
          is_new_read = 0;
        end
      end
    endcase
  endfunction


  virtual task cmd_formatter();
    state_t state;
    utb_cmd_packet_t cmd_pkt;
    int data_cnt;
    int idx;
    forever begin
      state = CMD;
      data_cnt = 0;
      idx = 0;
      forever begin
        wait(data_q.size() > 0);
        case(state)
          CMD: begin
            cmd_pkt.cmd = utb_command_type'(data_q.pop_front());
            cmd_pkt.tlm_cmd = cur_gp.get_command();
            state = ADDR;
          end
          ADDR: begin
            cmd_pkt.addr = data_q.pop_front();
            state = ADDON;
          end
          ADDON: begin
            cmd_pkt.addon = data_q.pop_front();
            this.cur_master_id = cmd_pkt.addon.master_id;
            this.id = cmd_pkt.addon.slave_id;
            // update address after getting master_id and slave_id
            cmd_pkt.addr = addr_map.get_original_addr(this.cur_master_id, this.id, cmd_pkt.addr);
            state = SIZE;
          end
          SIZE: begin
            cmd_pkt.size = data_q.pop_front();
            state = LEN;
          end
          LEN: begin
            cmd_pkt.len = data_q.pop_front();
            cmd_pkt.data = new[cmd_pkt.len];
            data_cnt = cmd_pkt.len;
            state = DATA;
            if(data_cnt <= 0) begin
              cmd_packet_put_q.push_back(cmd_pkt);
              break;
            end
          end
          DATA: begin
            if(idx < data_cnt) begin
              cmd_pkt.data[idx] = data_q.pop_front();
              idx++;
            end
            if(idx >= data_cnt) begin
              cmd_packet_put_q.push_back(cmd_pkt);
              break;
            end
          end
        endcase
        finish_tlm2_trans();
      end
    end
  endtask
  
  virtual task cmd_parser();
    // USER to be specified to parse the command packet
    // and translate the down stream agent's sequences
  endtask

  protected function void finish_tlm2_trans();
    b_trans_key.put();
  endfunction 

  protected task wait_tlm2_trans_rsp();
    b_trans_key.get();
  endtask

endclass

`endif // GUARD_UTB_COMMON_SLAVE_SV
