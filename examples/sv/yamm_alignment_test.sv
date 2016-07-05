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
 * A test that demonstrates the ability of YAMM to create buffers with different alignments and granularities for 
 * any allocation rule
 * 
 */

module yamm_alignment_test;

	import yamm_pkg::*;
	import uvm_pkg::*;

	initial

	begin

		automatic yamm memory = new;
		yamm_buffer buffer;
		int maxval;
		yamm_allocation_mode_e alloc_mode;
		int allocations;
		int fails;


		memory.build("my_memory",1024*50);

		buffer = new;
		buffer.start_addr = 1024;
		buffer.size = 156;
		void'(memory.allocate_static_buffer(buffer));

		for (int i=0; i<alloc_mode.num(); i++) begin

			alloc_mode = yamm_allocation_mode_e'(i);
			maxval = 100;

			$display("Starting allocation for %s", alloc_mode.name());

			while(memory.get_usage_statistics() < 100) begin
				buffer = new;
				buffer.size = $urandom_range(maxval, 0);
				buffer.granularity = $urandom_range(maxval, buffer.size);
				buffer.start_addr_alignment = $urandom_range(8, 1);
				if(maxval == 1)
					buffer.start_addr_alignment = 1;
				allocations++;

				if(!memory.allocate(buffer, alloc_mode)) begin
					maxval = maxval/2;
					fails++;
				end

				if(!memory.check_address_space_consistency()) begin
					$display("Allocations: %d", allocations);
					memory.print(0);
					$fatal(1,"Consistency error!");
				end

				if(!memory.check_alignment())
					$fatal(1,"Alignment error!");

				
			end
			
			$display("Allocations done successful for %s ; Usage: %f", alloc_mode.name(), memory.get_usage_statistics());
			memory.reset();
		end




	end



endmodule

