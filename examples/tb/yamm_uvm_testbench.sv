`timescale 1ns / 1ps

`ifndef __yamm_top
`define __yamm_top

module yamm_uvm_testbench;

	import uvm_pkg::*;
	import yamm_pkg::*;
	import yamm_test_pkg::*;

	initial begin
		run_test();
	end

endmodule

`endif
