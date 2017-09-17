
// File Name: clocks_verimod_if.sv

//====================================================================

`ifndef CLOCKS_VERIMOD_IF_SV
`define CLOCKS_VERIMOD_IF_SV

interface clocks_verimod_if;

  timeunit 1ps;
  timeprecision 1ps;
  import clocks_verimod_pkg::clocks_verimod_gen_mode_t;

  string id = "default_clocks";

  // Control flags
  bit                has_checks = 1;
  bit                has_coverage = 1;

  // Actual Signals 
  // USER: Add interface signals

  // clock signal
  logic            clk_in;
  logic            clk_source_gen;
  logic            clk;
  wire logic       reset;
  logic            en;
  // initial clock start level(defalut = 1'b0)
  logic            clk_startvalue = 1'b0;
  // delay befor signal change
  integer unsigned clk_delay      = 19230; // 19.23ns
  // width of second phase befor next clock change
  integer unsigned clk_width      = 19230; // 19.23ns
  // clock stop period for phase shift
  integer unsigned clk_wait       = 5000;  // 5ns
  // clock enable signal ('1'=on / '0'=off)
  logic            enable_clock   = 1'b0;
  // tristate high z clock out (default = '0')
  logic            clk_highz      = 1'b0;
  // reset enable signal ('1'=on / '0'=off)
  logic            enable_reset   = 1'b0;
  // reset active level (default = '0')
  logic            reset_active   = 1'b0;
  // clock generation mode
  clocks_verimod_gen_mode_t gen_mode = clocks_verimod_pkg::SOURCE_GEN;
  // clock divider parameter
  int unsigned   div = 0;

  clocking cb @(posedge clk);
   // USER: Add clocking block detail
  endclocking : cb

  modport DUT ( input clk
		// USER: Add dut I/O
              );
  modport TB  ( clocking cb);

  //-------------------------------------------------------------------------------------
  // CLOCK and RESET generation here
  // USER need use sequence to dynamically change the clock generation
  // variables, and thus change the clock cycles
  //-------------------------------------------------------------------------------------
  assign reset = enable_reset ? reset_active : (!reset_active);

  initial begin
    // assign start value (default assignment)
    clk_source_gen <= clk_startvalue;
    en  <= 1'b0;
    forever begin
      // when clock is disabled
      if(enable_clock == 1'b0) begin
        en <= 1'b0;
        if(clk_highz == 1'b1) begin
          clk_source_gen <= 1'bz;
        end
        // wait some time when clock isn't enabled
        #(clk_wait);
      end
      // when clock is enabled
      else begin
        if(gen_mode == clocks_verimod_pkg::SOURCE_GEN) begin
          en <= 1'b1;
          // wait first phase of the clock before changing
          #(clk_delay);
          // invert clock
          clk_source_gen <= !clk_startvalue;
          // wait second phase of the clock before changing
          #(clk_width);
          // invert clock
          clk_source_gen <= clk_startvalue;
        end
        else if(gen_mode == clocks_verimod_pkg::EN_GEN) begin
          if(div > 1) begin
            // wait first phase of the clock before changing
            @(posedge clk_in);
            // invert clock, blocking assignment
            en = 1'b0;
            // wait second phase of the clock before changing
            repeat(div-1) @(posedge clk_in);
            // invert clock, blocking assignment
            en = 1'b1;
          end
          else if(div == 1) begin
            // wait first phase of the clock before changing
            @(posedge clk_in);
            en = 1'b1;
          end
          else if(div == 0) begin
            // wait first phase of the clock before changing
            @(posedge clk_in);
            en = 1'b0;
          end
        end
      end
    end

  end

  // Coverage and assertions to be implemented here.
  // USER: Add assertions/coverage here

endinterface : clocks_verimod_if

`endif // CLOCKS_VERIMOD_IF_SV
