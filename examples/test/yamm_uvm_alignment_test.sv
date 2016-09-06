

`ifndef yamm_uvm_alignment_test
`define yamm_uvm_alignment_test


class yamm_uvm_alignment_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_alignment_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		automatic yamm memory = new;
		yamm_buffer buffer;
		int maxval;
		yamm_allocation_mode_e alloc_mode;
		int allocations;
		int fails;


		memory.build("my_memory",1024*50);

		buffer = new;
		buffer.set_start_addr_size(1024, 156);
		void'(memory.allocate_static_buffer(buffer));

		for (int i=0; i<alloc_mode.num(); i++) begin

			alloc_mode = yamm_allocation_mode_e'(i);
			maxval = 100;

			`uvm_info("YAMM_ALIGNMENT_INF", $sformatf("Starting allocation for %s", alloc_mode.name()), UVM_MEDIUM)

			while(memory.get_usage_statistics() < 100) begin
				buffer = new;
				buffer.set_size($urandom_range(maxval, 1));
				buffer.set_granularity($urandom_range(maxval, buffer.get_size()));
				buffer.set_start_addr_alignment($urandom_range(8, 1));
				if(maxval == 1)
					buffer.set_start_addr_alignment(1);
				allocations++;

				if(!memory.allocate(buffer, alloc_mode)) begin
					maxval = maxval/2;
					fails++;
				end

				if(!memory.check_address_space_consistency()) begin
					`uvm_warning("YAMM_ALIGNMENT_WARN", $sformatf("Allocations: %d", allocations))
					`uvm_fatal("YAMM_ALIGNMENT_FATAL", "Consistency error!")
				end

				if(!memory.check_alignment())
					`uvm_fatal("YAMM_ALIGNMENT_FATAL", "Alignment error!")


			end

			`uvm_info("YAMM_ALIGNMENT_INF", $sformatf("Allocations done successful for %s ; Usage: %f", alloc_mode.name(), memory.get_usage_statistics()), UVM_MEDIUM)
			memory.reset();
		end

	endtask

endclass

`endif

