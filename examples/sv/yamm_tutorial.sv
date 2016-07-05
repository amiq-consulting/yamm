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
 * A module that should help new users to understand how YAMM can be used and see some of it's features
 * in action. We recommend you to run the example and follow the code.
 *
 */
 
module yamm_tutorial;

	// First step in using YAMM is importing the package
	import yamm_pkg::*;

	initial begin

		// Next we have to instantiate it
		automatic yamm memory = new;

		// We will also declare some useful variables
		automatic yamm_addr_width start_addr = 10;
		yamm_addr_width end_addr;
		yamm_size_width size;
		yamm_byte_s sample_contents;
		yamm_buffer sample_buffer;
		yamm_buffer_q queue_of_buffers;

		// And then build it
		memory.build("my_memory", 1024*10);

		// At this point the memory has a size but no buffers, not even free ones
		// We can allocate some static buffers now


		// Let's allocate some static buffers in a contiguous space starting with address 10
		for(int i=0;i<10;i++) begin

			automatic yamm_buffer new_static_buffer = new;
			new_static_buffer.start_addr = start_addr;
			new_static_buffer.size = 4;

			if(!memory.allocate_static_buffer(new_static_buffer))
				$warning("Static buffer coudn't be allocated.");

			start_addr += 4;

		end

		// Now in our top object, there's a queue of 10 buffers with size 4 organized starting with address 10
		// one next to each other, to allocate them though, and also initialize the memory we call reset

		memory.reset();

		// Let's take a look at the memory now
		$display(memory.sprint_buffer(1));
		$display("\n\n");

		// As you can see the 10 buffers are now in the memory, these buffers are persistent through reset


		// Now let's say we need 100 buffers of random sizes between 1-100, non-overlapping, randomly allocated in the memory

		for(int i=0;i<100;i++) begin

			// The simplest way to allocate buffers is using the allocate_by_size() function
			automatic yamm_buffer new_buffer = memory.allocate_by_size($urandom_range(100, 1), RANDOM_FIT);

			// Also we are interested in having some payload
			// Please note that this function is optional, as calling get_contents on a buffer without payload will
			// call it automatically
			new_buffer.generate_contents();
			
			// We can also set a type name to find them easier
			new_buffer.set_name("my_first_100_buffers");
			
			// Now you can do something with the buffer you just allocated
			
			
			//..............................
			start_addr = new_buffer.start_addr;
			end_addr = new_buffer.end_addr();
			size = new_buffer.size;
			sample_contents = new_buffer.get_contents();
			//..............................

		end
		
		// Now we can view the memory again with the 110 buffers in it
		$display(memory.sprint_buffer(1));
		
		// If we want to get a specific buffer we can get it by knowing it's address
		sample_buffer = memory.get_buffer(15);
		
		// For instance, now the sample_buffer handle points to the second static buffer we allocated
		$display($sformatf("Sample buffer's parameters: Starting address: %x ; Ending address: %x Size: %x"
			, sample_buffer.start_addr, sample_buffer.end_addr(), sample_buffer.size));
		
		// Also if we want we can get for instance the buffers in the second half of the memory
		queue_of_buffers = memory.get_buffers_in_range(memory.size/2, memory.size-1);
		
		// And also we can easily get buffers for which we set a specific type_name
		queue_of_buffers = memory.get_all_buffers_by_type("my_first_100_buffers");
		
		// Let's check the memory usage right now
		$display("Percentage of memory occupied: %f", memory.get_usage_statistics());
		
		
		// Now let's deallocate the buffers that have a size over 50
		foreach (queue_of_buffers[i]) begin
			
			if(queue_of_buffers[i].size > 50)
				if(!memory.deallocate(queue_of_buffers[i]))
					$warning("Buffer coudn't be deallocated");
			
		end
		
		// And now check again the memory usage
		$display("Percentage of memory occupied: %f\n\n", memory.get_usage_statistics());
		
		// And display the memory map
		$display(memory.sprint_buffer(1));
		
		// And let's also check the memory consistency to make sure yamm as a reference model is correct
		if(memory.check_address_space_consistency())
			$display("Consistency checked!");
		
		// This are some of the yamm's features, we hope you now have some understanding of how it works

	end


endmodule