//====================================================================
//
// File Name: clocks_verimod_master_driver.sv

//====================================================================

/***************************************************************************
 *
 * Author:      $Author:$
 * File:        $File:$
 * Revision:    $Revision:$
 * Date:        $Date:$
 *
 *******************************************************************************
 *
 * clocks_verimod gen master driver implementation
 *
 *******************************************************************************
 */
`ifndef CLOCKS_VERIMOD_GEN_MASTER_DRIVER_SV
`define CLOCKS_VERIMOD_GEN_MASTER_DRIVER_SV

function clocks_verimod_master_driver::new (string name, uvm_component parent);
  super.new(name, parent);
  clk_locker = new(1);  // keyCount = 1
  clk_freq = 26;
  clk_base = MHz;
  has_coverage = FALSE;
  clk_name = "NONE";
  kind = GEN_TYPE;
  // default settings: 26 MHz clock with 2 % variation, no jitter
  clk_variation = 0;
  clk_jitter_on = FALSE;
  enable_clock = TRUE;    // switch to activate clock settings
  clk_highz = FALSE;
  clk_startvalue = 0;     // clock starts at high or low
  clk_duty_cycle = 50;    // clock duty cycle 50:50 per default (percent)
  clk_phase_shift = 0;    // phase shift at initial clock setup, 1/4 = 25, 1/2 = 50, 3/4 = 75
  wait_factor = 1;        // wait factor for clock stop during phase shift
  reset_delay = 100;      // time before reset (ps)
  reset_duration = 250;   // time reset active (ps)
  reset_factor = 1;       // factor for reset (ps)
  reset_active = 0;       // default value: low active reset
  _duration_timeunit = 1ns; // USER should not modify the timeunit externally
  gen_mode = SOURCE_GEN; // by default, it is to generate clock
endfunction : new

task clocks_verimod_master_driver::run_phase(uvm_phase phase);
  // to indict correct clock gen mode to interface
  set_mode(gen_mode);
  fork
    // clock initial phase
    if(enable_clock == TRUE) begin
      fork
        print_clock_settings();
        change_ratio_clk();
        reset_control();
      join_none
    end
    // clock driving phase by sequence item
    get_and_drive();
  join_none
endtask : run_phase


task clocks_verimod_master_driver::get_and_drive();
    uvm_sequence_item item;
    clocks_verimod_transfer t;

    forever begin
      
      seq_item_port.get_next_item(item);

      // debug
      `uvm_info(get_type_name(), "sequencer got next item", UVM_HIGH)
      $cast(t, item);

      // To avoid long time waiting for the LOW frequency clock generation
      // Liu, Bin Rocker 2014/01/14
      fork
        begin
          if(gen_mode == SOURCE_GEN) begin
            do_clock(t);
          end
          else if(gen_mode == EN_GEN) begin
            do_clock_en(t);
          end
        end
      join_none

      seq_item_port.item_done();

      // debug
      `uvm_info(get_type_name(), "sequencer item_done_triggered", UVM_HIGH)
      // Advance clock
    end
   
endtask : get_and_drive

function void clocks_verimod_master_driver::print_clock_settings();
  `uvm_info(get_type_name(), $psprintf("**********  clock settting  **********"), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("*** enable clk   = %d", enable_clock), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("*** clk highz    = %d", clk_highz), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("*** start value  = %d", intf.clk_startvalue), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("*** jitter       = %d", clk_jitter_on), UVM_HIGH)
  if(clk_jitter_on == TRUE) begin
    `uvm_info(get_type_name(), $psprintf("*** jitter delay   = %d ps", intf.clk_delay), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** jitter width   = %d ps", intf.clk_width), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** jitter period  = %d ps", (intf.clk_delay + intf.clk_width)), UVM_HIGH)
  end
  else begin
    `uvm_info(get_type_name(), $psprintf("*** delay          = %d ps", intf.clk_delay), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** width          = %d ps", intf.clk_width), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** period         = %d ps", (intf.clk_delay + intf.clk_width)), UVM_HIGH)
  end
  `uvm_info(get_type_name(), $psprintf("*** phase shift  = %d /100", clk_phase_shift), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("*** duty cycle   = %d", clk_duty_cycle), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("**********  clock settting  **********"), UVM_HIGH)

endfunction : print_clock_settings

task clocks_verimod_master_driver::change_ratio_clk();
  int unsigned factor;
  bit[39: 0]    period;
  bit[39: 0]    half_period;
  bit[39: 0]    halfp_min;
  bit[39: 0]    halfp_max;
  int unsigned clk_delay;
  int unsigned clk_width;
  int unsigned wait_calc;
  int unsigned corr_factor;
  string prt_str;

  // correction facotr MHz/KHz
  if(clk_base == MHz) factor = 1; else factor = 1000;
  if(clk_freq < 1000) corr_factor = 1; else corr_factor = 1000;

  // calc values
  period = 1000_000*corr_factor/clk_freq; // ns

  `uvm_info(get_type_name(), $psprintf("calc clock period = %d ps", period*factor/corr_factor), UVM_LOW)

  half_period = period/2;
  halfp_min = half_period - (half_period*clk_variation/100)/2;
  halfp_max = half_period + (half_period*clk_variation/100)/2;

  // modification in case of KHz clock
  halfp_min = halfp_min * factor/corr_factor;
  halfp_max = halfp_max * factor/corr_factor;

  // generate delay and width within variation ranges
  // with respect to the clocks duty cycle setting
  clk_delay = $urandom_range(halfp_max*(100-clk_duty_cycle)/50, halfp_min*(100-clk_duty_cycle)/50);
  clk_width = $urandom_range(halfp_max*clk_duty_cycle/50,       halfp_min*clk_duty_cycle/50);


  // recalculate period
  period = clk_delay + clk_width;
  `uvm_info(get_type_name(), $psprintf("gen clock period = %d ps", period), UVM_HIGH)

  intf.clk_startvalue = clk_startvalue;
  // assign clock delay/width depending on start value
  // necessary for correct duty cycle
  if(clk_startvalue == 0) begin
    intf.clk_delay  = clk_delay;
    intf.clk_width  = clk_width;
  end
  else begin
    intf.clk_delay  = clk_width;
    intf.clk_width  = clk_delay;
  end

  // limitation to 32 bit integer not working for 32KHz calc!
  wait_calc = (clk_delay+clk_width) * (100+clk_phase_shift) / 100;
  intf.clk_wait = wait_calc;
  if(clk_highz == TRUE) begin
    `uvm_info(get_type_name(), $psprintf("********** clock highz **********"), UVM_HIGH)
    intf.enable_clock = 0;
    intf.clk_highz = 1;
  end
  else begin
    intf.enable_clock = 1;
    intf.clk_highz = 0;
    // do not change ratio during reset active time (begin of simulation)
    // reset shoudl be applied before or after
    while(intf.reset == reset_active) begin
      @(posedge intf.clk);
    end // while (intf.reset...)
    `uvm_info(get_type_name(), $psprintf("********** clock stop **********"), UVM_HIGH)
    prt_str.itoa(clk_base);
    `uvm_info(get_type_name(), $psprintf("*** clk_freq         ~ %d %s", clk_freq, prt_str), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** clk_start_val    = %d", clk_startvalue), UVM_HIGH)
    if(clk_startvalue == 0) begin
      `uvm_info(get_type_name(), $psprintf("*** clk_delay        = %d ps", clk_delay), UVM_HIGH)
      `uvm_info(get_type_name(), $psprintf("*** clk_width        = %d ps", clk_width), UVM_HIGH)
    end
    else begin
      `uvm_info(get_type_name(), $psprintf("*** clk_delay        = %d ps", clk_width), UVM_HIGH)
      `uvm_info(get_type_name(), $psprintf("*** clk_width        = %d ps", clk_delay), UVM_HIGH)
    end
    `uvm_info(get_type_name(), $psprintf("*** clk_period       = %d ps", period), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** clk_phase_shift  = %d", clk_phase_shift), UVM_HIGH)
    prt_str.itoa(clk_duty_cycle);
    `uvm_info(get_type_name(), $psprintf("*** duty cycle       = %s", prt_str), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("*** clk_wait         = %d", (clk_delay+clk_width)*(100+clk_phase_shift)/100), UVM_HIGH)
    intf.enable_clock = 0;
    // minimus wait for 1 period (plus phase shift)
    #(wait_factor*(clk_delay+clk_width));
    intf.enable_clock = 1;
    `uvm_info(get_type_name(), $psprintf("********** clock start **********"), UVM_HIGH)
    if (has_coverage == TRUE) begin
      prt_str.itoa(clk_base);
      `uvm_info(get_type_name(), $psprintf("cover clock period = %d, freq = %d %s", period, clk_freq, prt_str), UVM_HIGH)
      -> collect_cover_e;
    end
  end // ! if(clk_highz...)

endtask : change_ratio_clk

task clocks_verimod_master_driver::jitter_clk(input int unsigned halfp_min, input int unsigned halfp_max);
  while(clk_jitter_on == TRUE) begin
    int unsigned  jitter_period;
    int unsigned  jitter_delay;
    int unsigned  jitter_width;

    // generate delay and width within variation ranges
    // with respect to the clocks duty cycle setting
    jitter_delay = $urandom_range(halfp_max*(100-clk_duty_cycle)/50, halfp_min*(100-clk_duty_cycle)/50);
    jitter_width = $urandom_range(halfp_max*clk_duty_cycle/50,       halfp_min*clk_duty_cycle/50);

    `uvm_info(get_type_name(), $psprintf("********** JITTER **********"), UVM_HIGH)
    if(clk_startvalue == 0) begin
      `uvm_info(get_type_name(), $psprintf("*** clk_delay            = %d ps", jitter_delay), UVM_HIGH)
      `uvm_info(get_type_name(), $psprintf("*** clk_width            = %d ps", jitter_width), UVM_HIGH)
      intf.clk_delay = jitter_delay;
      intf.clk_width = jitter_width;
    end 
    else begin
      `uvm_info(get_type_name(), $psprintf("*** clk_delay            = %d ps", jitter_width), UVM_HIGH)
      `uvm_info(get_type_name(), $psprintf("*** clk_width            = %d ps", jitter_delay), UVM_HIGH)
      intf.clk_delay = jitter_width;
      intf.clk_width = jitter_delay;
    end // ! if(clk_startvalue...)
    jitter_period = jitter_delay + jitter_width;
    `uvm_info(get_type_name(), $psprintf("*** clk_period             = %d ps", jitter_period), UVM_HIGH)
    `uvm_info(get_type_name(), $psprintf("********** JITTER **********"), UVM_HIGH)
    @(negedge intf.clk);
  end

    //`uvm_info(get_type_name, $psprintf(), UVM_HIGH)
endtask :jitter_clk 

task clocks_verimod_master_driver::reset_control();
  intf.reset_active = reset_active;
  #(reset_delay*reset_factor);
  `uvm_info(get_type_name(), $psprintf("********** reset %s **********", clk_name), UVM_HIGH)
  `uvm_info(get_type_name(), $psprintf("*** reset active level is    %d", reset_active), UVM_HIGH)
  intf.enable_reset = 1;
  #(reset_duration*reset_factor);
  `uvm_info(get_type_name(), $psprintf("********** reset released %s **********", clk_name), UVM_HIGH)
  intf.enable_reset = 0;

endtask : reset_control

task clocks_verimod_master_driver::do_clock(clocks_verimod_transfer trans);
  int unsigned        wait_calc;
  int unsigned        factor;
  bit [39: 0]         period;
  bit [39: 0]         half_period;
  bit [39: 0]         halfp_min;
  bit [39: 0]         halfp_max;
  int unsigned        seq_delay;
  int unsigned        seq_width;
  int unsigned        corr_factor;


  // lock so that the actual clock is exclusive
  clk_locker.get();

  if(trans.seq_type == SET) begin
    `uvm_info(get_type_name(), $psprintf("*** Clock generator driving clock setting : %s", trans.sprint()), UVM_HIGH)
    // correction factor MHz/KHz
    if(trans.base == MHz) factor = 1; else factor = 1000;
    // correction factor high values
    if(trans.freq < 1000) corr_factor = 1; else corr_factor = 1000;
    // calc values
    period = 1000_000*corr_factor/trans.freq; // ps
    `uvm_info(get_type_name(), $psprintf("calc clock period = %d ps", period*factor/corr_factor), UVM_HIGH)

    half_period = period/2;
    halfp_min = half_period - (half_period*trans.variation/100)/2;
    halfp_max = half_period + (half_period*trans.variation/100)/2;

    // modification in case of KHz clock
    halfp_min = halfp_min * factor/corr_factor;
    halfp_max = halfp_max * factor/corr_factor;

    // set clock parameters (necessary for coverage)
    clk_duty_cycle  = trans.duty_cycle;
    clk_freq        = trans.freq;
    clk_base        = trans.base;
    clk_variation   = trans.variation;

    // generata delay and width within variation ranges
    // with respect to the clocks duty cycle setting
    seq_delay = $urandom_range(halfp_max*(100-clk_duty_cycle)/50, halfp_min*(100-clk_duty_cycle)/50);
    seq_width = $urandom_range(halfp_max*clk_duty_cycle/50,       halfp_min*clk_duty_cycle/50);

    // recalculate period
    period = seq_delay + seq_width;
    `uvm_info(get_type_name(), $psprintf("gen clock period = %d ps", period), UVM_HIGH)

    // assign values to signals in clock generator
    intf.clk_startvalue = clk_startvalue;
    if(clk_startvalue == 0) begin
      intf.clk_delay    = seq_delay;
      intf.clk_width    = seq_width;
    end
    else begin
      intf.clk_delay    = seq_width;
      intf.clk_width    = seq_delay;
    end // if(clk_startvalue...)
    wait_calc = (seq_delay+seq_width) * (100+clk_phase_shift) / 100;
    intf.clk_wait   = wait_calc;
    // jitter on/off
    clk_jitter_on   = trans.jitter;
    // clock enable
    enable_clock    = trans.enable;
    if(trans.enable == TRUE) begin
      intf.enable_clock = 1;
      intf.clk_highz    = 0;
      @(posedge intf.clk);
    end
    else begin
      intf.enable_clock = 0;
      if(trans.highz == TRUE) begin
        intf.clk_highz = 1;
      end
      // minimum wait for one 26MHz period even if clock is disabled
      #(period); // ps
    end // if(trans.enable...)
    print_clock_settings();
    fork
      jitter_clk(halfp_min, halfp_max);
    join_none
    `uvm_info(get_type_name(), $psprintf("Clock generator driving clock setting ... done"), UVM_HIGH)
    // collect coverage
    if(has_coverage == TRUE) begin
      -> collect_cover_e;
    end
    clk_locker.put(1); // release the exclusive key : clk_locker
  end
  else if(trans.seq_type == RESET) begin
    if(trans.sync_set == TRUE) @(posedge intf.clk); // synchronize to clock edge
    `uvm_info(get_type_name(), $psprintf("*** Clock generator driving reset : %s", trans.sprint()), UVM_HIGH)
    intf.enable_reset = 1;
    #(trans.duration*_duration_timeunit);
    if(trans.sync_rel == TRUE) @(posedge intf.clk); // synchronize to clock edge
    `uvm_info(get_type_name(), $psprintf("*** Clock generator releasing reset : %s", trans.sprint()), UVM_HIGH)
    intf.enable_reset = 0;
    clk_locker.put(1); // release the exclusive key : clk_locker

  end
  else begin
    `uvm_warning(get_type_name(), $psprintf("WARNING: unknown sequence used for clock generator"))
    clk_locker.put(1); // release the exclusive key : clk_locker
  end
endtask : do_clock


task clocks_verimod_master_driver::do_clock_en(clocks_verimod_transfer trans); 
  int unsigned        factor;
  bit [39: 0]         period;
  int unsigned        corr_factor;

  if(trans.seq_type == SET) begin
    `uvm_info(get_type_name(), $psprintf("*** Clock generator driving clock setting : %s", trans.sprint()), UVM_HIGH)
    // correction factor MHz/KHz
    if(trans.base == MHz) factor = 1; else factor = 1000;
    // correction factor high values
    if(trans.freq < 1000) corr_factor = 1; else corr_factor = 1000;
    // calc values
    period = 1000_000*corr_factor/trans.freq; // ps
    intf.div = trans.div;
    if(trans.enable == TRUE) begin
      intf.enable_clock = 1;
      intf.clk_highz    = 0;
      @(posedge intf.clk);
    end
    else begin
      intf.enable_clock = 0;
      if(trans.highz == TRUE) begin
        intf.clk_highz = 1;
      end
      // minimum wait for one 26MHz period even if clock is disabled
      #(period); // ps
    end // if(trans.enable...)
  end
  else if(trans.seq_type == RESET) begin
    if(trans.sync_set == TRUE) @(posedge intf.clk); // synchronize to clock edge
    `uvm_info(get_type_name(), $psprintf("*** Clock generator driving reset : %s", trans.sprint()), UVM_HIGH)
    intf.enable_reset = 1;
    #(trans.duration*_duration_timeunit);
    if(trans.sync_rel == TRUE) @(posedge intf.clk); // synchronize to clock edge
    `uvm_info(get_type_name(), $psprintf("*** Clock generator releasing reset : %s", trans.sprint()), UVM_HIGH)
    intf.enable_reset = 0;
  end
  else begin
    `uvm_warning(get_type_name(), $psprintf("WARNING: unknown sequence used for clock generator"))
  end
endtask: do_clock_en

function void clocks_verimod_master_driver::set_mode(clocks_verimod_gen_mode_t mode);
  this.gen_mode = mode;
  intf.gen_mode = mode;
endfunction: set_mode

`endif // CLOCKS_VERIMOD_GEN_MASTER_DRIVER_SV
