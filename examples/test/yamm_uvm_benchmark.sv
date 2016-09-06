

`ifndef __yamm_uvm_benchmark
`define __yamm_uvm_benchmark


class yamm_uvm_benchmark extends uvm_test;

	`uvm_component_utils(yamm_uvm_benchmark)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		yamm_size_width_t frag_buffer_size = 64500;
		yamm_size_width_t buffer_size = 95000;
		yamm_size_width_t memory_size = 1024*1024*1024;
		int max_number_allocations = 20_000;
		int max_number_frag = 5_000;
		yamm_allocation_mode_e alloc_mode;
		yamm_buffer n;
		longint time1, delta_time;
		yamm_buffer_q buffer_q;
		int search_iterations = 20000;

		// Only test search
		bit only_test_search = 0;
		// Only test search

		yamm mem = new;
		mem.build("Name",memory_size);

		for (int i=0; i<alloc_mode.num(); i++) begin
			int nr_allocations = max_number_allocations;
			int nr_allocations_frag = max_number_frag;
			int number_of_deallocations = 0;
			int fd;//file descriptor
			int _buffer_size = buffer_size;
			mem.reset();

			`uvm_info("YAMM_BENCHMARK_INF", "Memory was created.", UVM_MEDIUM)
			//do initial fragmentation
			$system("date +\"%s\" > time_log");
			while(nr_allocations_frag--)
				if(!mem.allocate_by_size(frag_buffer_size, UNIFORM_FIT))
					`uvm_error("YAMM_BENCHMARK_ERR", "Problem with allocation!")
			//mem.print(0);
			`uvm_info("YAMM_BENCHMARK_INF", $sformatf("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation()), UVM_MEDIUM)
			$system("date +\"%s\" >> time_log");
			fd = $fopen("time_log","r");
			$fscanf(fd,"%d",time1);
			$fscanf(fd,"%d",delta_time);
			$fclose(fd);
			delta_time -= time1;
			`uvm_info("YAMM_BENCHMARK_INF", $sformatf("alloc_mode= UNIFORM_FIT (Fragmentation), delta_time=%0d", delta_time), UVM_MEDIUM)

			alloc_mode = yamm_allocation_mode_e'(i);
			$system("date +\"%s\" > time_log");
			while(nr_allocations--) begin
				if(!mem.allocate_by_size(_buffer_size, alloc_mode))
					`uvm_warning("YAMM_BENCHMARK_WRN", "Buffer could not be allocated!")
				if(nr_allocations == 11500)
					_buffer_size = _buffer_size/2;
				if(nr_allocations == 14000)
					_buffer_size = _buffer_size/2;
				if(nr_allocations == 18000)
					_buffer_size = _buffer_size/2;
			end
			$system("date +\"%s\" >> time_log");
			fd = $fopen("time_log","r");
			$fscanf(fd,"%d",time1);
			$fscanf(fd,"%d",delta_time);
			$fclose(fd);
			delta_time -= time1;
			`uvm_info("YAMM_BENCHMARK_INF", $sformatf("alloc_mode=%s, delta_time=%0d" , alloc_mode.name(), delta_time), UVM_NONE)



			if(mem.check_address_space_consistency())
			begin
				`uvm_info("YAMM_BENCHMARK_INF", "Consistency Checked!", UVM_MEDIUM)
				mem.print_stats();
			end
			else
				`uvm_fatal("YAMM_BENCHMARK_FATAL", "Consistency problem!");

			if(only_test_search)
				i = 5;

			if(i == 5)
			begin
				yamm_addr_width_t rnd_addr;
				int iterator = 0;
				`uvm_info("YAMM_BENCHMARK_INF", "Begin search test.", UVM_MEDIUM)
				$system("date +\"%s\" > time_log");
				while(iterator < search_iterations)
				begin
					rnd_addr = $urandom_range(mem.get_size()-1, 0);
					buffer_q.push_back(mem.get_buffer(rnd_addr));
					iterator++;
				end
				$system("date +\"%s\" >> time_log");
				fd = $fopen("time_log","r");
				$fscanf(fd,"%d",time1);
				$fscanf(fd,"%d",delta_time);
				$fclose(fd);
				delta_time -= time1;
				`uvm_info("YAMM_BENCHMARK_INF", $sformatf("Number of searches: %d ; delta_time = %0d", search_iterations, delta_time), UVM_NONE)
			end

			`uvm_info("YAMM_BENCHMARK_INF", "Begin deallocations.", UVM_MEDIUM)
			$system("date +\"%s\" > time_log");

			buffer_q = mem.get_buffers_in_range(0, memory_size-1);
			foreach (buffer_q[i])
			begin
				void'(mem.deallocate(buffer_q[i]));
				number_of_deallocations++;
			end

			$system("date +\"%s\" >> time_log");
			fd = $fopen("time_log","r");
			$fscanf(fd,"%d",time1);
			$fscanf(fd,"%d",delta_time);
			$fclose(fd);
			delta_time -= time1;
			`uvm_info("YAMM_BENCHMARK_INF", $sformatf("Number of deallocations: %0d ; delta_time: %0d", number_of_deallocations, delta_time), UVM_NONE)
			mem.print_stats();

		end

	endtask

endclass

`endif
