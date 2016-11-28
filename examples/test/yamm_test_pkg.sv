

`ifndef __yamm_test_pkg
`define __yamm_test_pkg


package yamm_test_pkg;

	import uvm_pkg::*;
	`include "uvm_macros.svh"

	import yamm_pkg::*;

	`include "yamm_uvm_benchmark.sv"
	`include "yamm_uvm_yamm_vs_mam_test.sv"
	`include "yamm_uvm_alignment_test.sv"
	`include "yamm_uvm_sanitation_test.sv"
	`include "yamm_uvm_stability_test.sv"
	`include "yamm_uvm_recursive_test.sv"

endpackage

`endif
