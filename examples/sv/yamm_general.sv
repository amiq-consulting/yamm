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
 * A module that shows some generic functions of YAMM
 */
module yamm_general;

	import yamm_pkg::*;

	initial

	begin
		int i_allocs;
		automatic yamm mem = new; // We first instantiate a memory

		/* Let's consider we want to allocate a random number of static buffers
		 * of various sizes
		 */
		int number_of_static_buffers;
		yamm_buffer static_buffer;
		automatic yamm_addr_width start_addr = 0;

		/* We are then going to dynamically allocate and deallocate buffers in
		 * the memory with various payloads and of a few different types
		 */
		yamm_buffer general_buffer;
		int number_of_general_buffers;
		string _type;

		/* We are going to clear the memory and reuse the memory as a memory map
		 * with 4 byte granularity and also aligned on addresses multiple of 4
		 */
		static int granularity = 4;
		static int address_alignment = 4;

		/* We are going to generate accesses in the memory at random addresses,
		 * check if they overlap any buffers and display their type and payload if
		 * they do
		 */
		yamm_access basic_access;
		yamm_addr_width ac_addr;
		yamm_buffer_q queue;



		/*
		 * Stage 1 -> Initialize the memory and allocate static buffers
		 *
		 */

		// A memory called YAMM_MEMORY_MAP of size 1 MB
		mem.build("YAMM_MEMORY_MAP", 1024*1024);
		number_of_static_buffers = $urandom_range(100, 10);

		while(number_of_static_buffers--) begin

			static_buffer = new;
			// We randomize the size of the buffer
			static_buffer.size = $urandom_range(128, 32);
			static_buffer.start_addr = start_addr;
			// And we allocate it
			void'(mem.allocate_static_buffer(static_buffer));
			start_addr = start_addr + static_buffer.size;
		end

		// After the allocation of static buffers is done memory is initialized
		// with a reset call

		mem.reset();

		// We can visualize the result by viewing stats and printing the memory

		mem.print_stats();
		mem.print();

		/*
		 * Stage 2 -> General buffers allocation + type
		 *
		 */


		number_of_general_buffers = $urandom_range(1000, 100);

		for(int i=0;i<number_of_general_buffers;i++) begin

			general_buffer = new;
			general_buffer.size = $urandom_range(512, 1);

			void'(mem.allocate(general_buffer, RANDOM_FIT));

			/*
			 * We are going to generate random payload for each buffer
			 */

			general_buffer.generate_contents();

			/*
			 * We are going to create 2 types of buffers
			 * Big -> Size > 256
			 * Small -> Size <= 256
			 */

			if(general_buffer.size > 256)
				general_buffer.set_name("Big");
			else
				general_buffer.set_name("Small");

			/*
			 * We are going to allocate a few buffers inside an already allocated buffer
			 */
			 
			i_allocs = $urandom_range(5, 1);
			for(int j=0;j<i_allocs;j++) begin
				if(!general_buffer.allocate_by_size($urandom_range(10, 5), RANDOM_FIT))
					$display("Problem with allocation!");
			end


		end

		mem.print_stats();

		/*
		 * Stage 3 -> Search for buffers using range, access and address + deallocation
		 *
		 */

		// Let's first create a basic access with the span of the first half of memory
		basic_access = new;
		basic_access.start_addr = 0;
		basic_access.size = mem.size/2;

		// Get all the buffers contained in the first half of the memory
		queue = mem.get_buffers_by_access(basic_access);

		// Deallocate them
		while(queue.size() > 0)
			void'(mem.deallocate(queue.pop_back()));


		// Get all the buffers contained in the first half of the memory this time
		// using get_buffers_in_range
		queue = mem.get_buffers_in_range(0,mem.size/2);

		// Display them
		foreach(queue[i]) begin
			$display($sformatf("Buffer at %x - %x",queue[i].start_addr, queue[i].end_addr()));
		end

		queue.delete();

		// We can also get a specific buffer by addr
		general_buffer = mem.get_buffer(12);
		$display($sformatf("Buffer at %x - %x", general_buffer.start_addr, general_buffer.end_addr()));

		// Or we can get the buffers of a specific type
		queue = mem.get_all_buffers_by_type("Small");
		foreach(queue[i])
			$display($sformatf("Buffer at %x - %x with size: %x", queue[i].start_addr, queue[i].end_addr(), queue[i].size));

		/*
		 * Stage 4 -> Content checking, setting and memory reset
		 */

		general_buffer = mem.get_buffer(0);
		
		$display($sformatf("The contents are %s", array2string(general_buffer.get_contents())));

		// The new contents are new_contents
		general_buffer.set_contents('{'h54,'h45,'h53,'h54});

		if(general_buffer.compare_contents('{'h54,'h45,'h53,'h54}))
			$display($sformatf("Contents were changed correctly!"));

		$display($sformatf("Now the contents are %s\n", array2string(general_buffer.get_contents())));

		mem.reset();

		$display("Reset was done");

		mem.print_stats();

		mem.print();

	end

    function string array2string(yamm_byte_s array);
	    array2string = "";
	    foreach(array[i])
		    array2string=$sformatf("%s%x ", array2string, array[i]);
    endfunction


endmodule

