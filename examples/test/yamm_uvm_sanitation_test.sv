

`ifndef __yamm_uvm_sanitation_test
`define __yamm_uvm_sanitation_test


class yamm_uvm_sanitation_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_sanitation_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		yamm_buffer n;

		yamm mem = new;
		mem.build("Name",1024);
		mem.reset();
		`uvm_info("YAMM_SANITATION_TEST", "Memory was reset.", UVM_HIGH)

		n = new;
		n.set_size(256);
		void'(mem.allocate(n,RANDOM_FIT));
		`uvm_info("YAMM_SANITATION_TEST", "Allocated randomly a buffer of size 256.", UVM_NONE)
		`uvm_info("YAMM_SANITATION_TEST", mem.sprint_buffer(1), UVM_MEDIUM);
		`uvm_info("YAMM_SANITATION_TEST", $sformatf("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation()), UVM_NONE)
		`uvm_info("YAMM_SANITATION_TEST", "Trying to change the start address to 12 and size to 16.", UVM_NONE)
		n.set_start_addr_size(12, 16);
		`uvm_info("YAMM_SANITATION_TEST", mem.sprint_buffer(1), UVM_MEDIUM);
		`uvm_info("YAMM_SANITATION_TEST", $sformatf("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation()), UVM_NONE)
		`uvm_info("YAMM_SANITATION_TEST", "Try to insert the buffer.", UVM_NONE)
		void'(mem.insert(n));
		`uvm_info("YAMM_SANITATION_TEST", mem.sprint_buffer(1), UVM_MEDIUM);
		`uvm_info("YAMM_SANITATION_TEST", $sformatf("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation()), UVM_NONE)
		void'(mem.deallocate(n));
		`uvm_info("YAMM_SANITATION_TEST", "Deallocated buffer.", UVM_NONE)
		`uvm_info("YAMM_SANITATION_TEST", mem.sprint_buffer(1), UVM_MEDIUM);
		`uvm_info("YAMM_SANITATION_TEST", $sformatf("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation()), UVM_NONE)
		`uvm_info("YAMM_SANITATION_TEST", "Trying to change the start address to 12 and size to 16.", UVM_NONE)
		n.set_start_addr_size(12, 16);
		n.set_start_addr_alignment(5);
		n.set_granularity(10);
		`uvm_info("YAMM_SANITATION_TEST", "Try to insert the buffer.", UVM_NONE)
		void'(mem.insert(n));
		`uvm_info("YAMM_SANITATION_TEST", mem.sprint_buffer(1), UVM_MEDIUM);
		`uvm_info("YAMM_SANITATION_TEST", $sformatf("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation()), UVM_NONE)



		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_SANITATION_TEST", "Consistency problem!")
		else
			`uvm_info("YAMM_SANITATION_TEST", "Consistency Checked!", UVM_MEDIUM)

	endtask

endclass

`endif

