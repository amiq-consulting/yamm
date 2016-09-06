

`ifndef __yamm_uvm_stability_test
`define __yamm_uvm_stability_test


class yamm_uvm_stability_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_stability_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		yamm_buffer n;
		yamm_allocation_mode_e alloc_mode;
		int maxval, buffers=0;
		yamm_buffer_q queue1, queue2;

		yamm mem = new;
		mem.build("Name",1024*50);

		for (int i=0; i<alloc_mode.num(); i++) begin

			// Phase I -> Allocate in the main memory
			alloc_mode = yamm_allocation_mode_e'(i);
			maxval = 100;

			`uvm_info("YAMM_STABILITY_TEST_INF", $sformatf("Starting to work on main memory, allocation mode: %s", alloc_mode.name()), UVM_MEDIUM)

			// Allocate until 70% memory usage is reached
			while(mem.get_usage_statistics() < 100) begin
				if(!mem.allocate_by_size($urandom_range(maxval, 1), alloc_mode))
					maxval = maxval/2;
			end

			// Check memory consistency
			if(!mem.check_address_space_consistency()) begin
				`uvm_fatal("YAMM_STABILITY_TEST_FATAL", "Consistency error!")
			end


			// Phase II -> Allocate inside each buffer allocated in main memory
			queue1 = mem.get_buffers_in_range(0, mem.get_end_addr());

			foreach(queue1[i]) begin

				maxval = 10;

				while(queue1[i].get_usage_statistics() < 70)
					if(!queue1[i].allocate_by_size($urandom_range(maxval, 1), alloc_mode))
						maxval = maxval/2;

				if(!queue1[i].check_address_space_consistency()) begin
					queue1[i].sprint_buffer(1);
					`uvm_fatal("YAMM_STABILITY_TEST_FATAL", "Consistency error!")
				end

				// Phase III -> Allocate one level of recursivity deeper
				queue2 = queue1[i].get_buffers_in_range(queue1[i].get_start_addr(), queue1[i].get_end_addr());

				foreach(queue2[i]) begin

					maxval = 2; 

					while(queue2[i].get_usage_statistics() < 70)
						if(!queue2[i].allocate_by_size($urandom_range(maxval, 1), alloc_mode))
							maxval = maxval/2;

					if(!queue2[i].check_address_space_consistency())
						`uvm_fatal("YAMM_STABILITY_TEST_FATAL", "Consistency error!")

				end

			end

			// Phase IV -> Reset the memory and move on to the next allocation mode
			if(!mem.check_address_space_consistency())
				`uvm_fatal("YAMM_STABILITY_TEST_FATAL", "Consistency error!")
			mem.print_stats();
			mem.reset();
			`uvm_info("YAMM_STABILITY_TEST_INF", "Reset was done.", UVM_MEDIUM)
			mem.print_stats();
		end

	endtask

endclass

`endif

