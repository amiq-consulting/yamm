/******************************************************************************
 * (C) Copyright 2016 AMIQ Consulting
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 *******************************************************************************/

/**
 * 	A module that features a specific stress test and performance measuring:
 * 	
 * 	A memory of size 1GB is initialized and 5000 buffers of size 64.5KB are allocated using UNIFORM_FIT to rise 
 * 	usage and fragmentation.
 * 
 *  The performance is measured afterwards for all 6 allocations mode by allocating 20000 buffers starting with a size
 *  of 95KB and halving it after 11500, 14000 and 18000 allocations respectively. Time elapsed and statistics are 
 *  displayed after the 20000 allocations for every allocation mode.
 * 
 * 	After allocation, buffers are deallocated, time taken is measured and memory is afterwards reset.
 * 
 *  After the final allocation mode is benchmarked the search function is tested by doing 20000 searches on random addresses.
 *  Time taken is displayed.
 * 
 */
module yamm_benchmark;

	import yamm_pkg::*;
	initial begin
		run_test();
	end



	task automatic run_test();
		yamm_size_width frag_buffer_size = 64500;
		yamm_size_width buffer_size = 95000;
		yamm_size_width memory_size = 1024*1024*1024;
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

			$display("Memory was reset.");
			//do initial fragmentation
			$system("date +\"%s\" > time_log");
			while(nr_allocations_frag--)
				if(!mem.allocate_by_size(frag_buffer_size, UNIFORM_FIT))
					$display("PROBLEM!");
			//mem.print(0);
			$display("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation());
			$system("date +\"%s\" >> time_log");
			fd = $fopen("time_log","r");
			$fscanf(fd,"%d",time1);
			$fscanf(fd,"%d",delta_time);
			$fclose(fd);
			delta_time -= time1;
			$display("alloc_mode= UNIFORM_FIT (Fragmentation), delta_time=", delta_time);



			alloc_mode = yamm_allocation_mode_e'(i);
			$system("date +\"%s\" > time_log");
			while(nr_allocations--) begin
				if(!mem.allocate_by_size(_buffer_size, alloc_mode))
					mem.print(0);
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
			$display("alloc_mode=", alloc_mode.name(),", delta_time=", delta_time);


			if(mem.check_address_space_consistency())
			begin
				$display("Consistency Checked!");
				mem.print_stats();
			end
			else
				$fatal(1, "Consistency problem!");

			if(only_test_search)
				i = 5;

			if(i == 5)
			begin
				yamm_addr_width rnd_addr;
				int iterator = 0;
				$display("Begin search test.");
				$system("date +\"%s\" > time_log");
				while(iterator < search_iterations)
				begin
					rnd_addr = $urandom_range(mem.size-1, 0);
					buffer_q.push_back(mem.get_buffer(rnd_addr));
					iterator++;
				end
				$system("date +\"%s\" >> time_log");
				fd = $fopen("time_log","r");
				$fscanf(fd,"%d",time1);
				$fscanf(fd,"%d",delta_time);
				$fclose(fd);
				delta_time -= time1;
				$display("Number of searches: ", search_iterations, ", delta_time = %0d", delta_time);
			end

			while(buffer_q.size > 0)
				void'(buffer_q.pop_front());

			while(buffer_q.size > 0) begin
				yamm_buffer t;
				t = buffer_q.pop_front();
				$display(t.size);
			end


			$display("Begin deallocations.");
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
			$display("Number of deallocations: ", number_of_deallocations,", delta_time=", delta_time);
			mem.print_stats();
			mem.print(0);

		end

	endtask
endmodule
