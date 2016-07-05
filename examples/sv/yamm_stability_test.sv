
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
 * A test that demonstrates the stability of YAMM by filling up the memory and recursively buffers inside it up 
 * to a third level of recursivity (Buffers in Buffers in Buffers in Memory)
 */
module yamm_stability_test;

	import yamm_pkg::*;

	initial begin
		run_test();
	end

	task automatic run_test();
		yamm_buffer n;
		yamm_allocation_mode_e alloc_mode;
		int maxval, buffers=0;
		yamm_buffer_q queue1, queue2;

		yamm mem = new;
		mem.build("Name",1024*50);
		//mem.reset();
		//$display("Memory was reset.");

		for (int i=0; i<alloc_mode.num(); i++) begin

			// Phase I -> Allocate in the main memory
			alloc_mode = yamm_allocation_mode_e'(i);
			maxval = 100;

			$display("Starting to work on main memory, allocation mode: %s", alloc_mode.name());

			// Allocate until 70% memory usage is reached
			while(mem.get_usage_statistics() < 100) begin
				if(!mem.allocate_by_size($urandom_range(maxval, 1), alloc_mode))
					maxval = maxval/2;
			end

			// Check memory consistency
			if(!mem.check_address_space_consistency()) begin
				$fatal(1,"Consistency error!");
			end


			// Phase II -> Allocate inside each buffer allocated in main memory
			queue1 = mem.get_buffers_in_range(0, mem.end_addr());

			foreach(queue1[i]) begin

				maxval = 10;

				while(queue1[i].get_usage_statistics() < 70)
					if(!queue1[i].allocate_by_size($urandom_range(maxval, 1), alloc_mode))
						maxval = maxval/2;

				if(!queue1[i].check_address_space_consistency()) begin
					queue1[i].print(1);
					$fatal(1,"Consistency error!");
				end

				// Phase III -> Allocate one level of recursivity deeper
				queue2 = queue1[i].get_buffers_in_range(queue1[i].start_addr, queue1[i].end_addr());

				foreach(queue2[i]) begin

					maxval = 2;

					while(queue2[i].get_usage_statistics() < 70)
						if(!queue2[i].allocate_by_size($urandom_range(maxval, 1), alloc_mode))
							maxval = maxval/2;

					if(!queue2[i].check_address_space_consistency())
						$fatal(1,"Consistency error!");

				end

			end

			// Phase IV -> Reset the memory and move on to the next allocation mode
			if(!mem.check_address_space_consistency())
				$fatal(1,"Consistency error!");
			mem.print_stats();
			$display(" ");
			mem.reset();
			$display(" ");
			mem.print_stats();
		end

	endtask
endmodule

