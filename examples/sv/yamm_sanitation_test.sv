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
 * A test that demonstrates the encapsulation of buffer data and memory integrity protection
 */
module yamm_sanitation_test;

	import yamm_pkg::*;



	initial begin
		run_test();
	end

	task automatic run_test();
		yamm_buffer n;

		yamm mem = new;
		mem.build("Name",1024);
		mem.reset();
		$display("Memory was reset.");
		
		n = new;
		n.size = 256;
		void'(mem.allocate(n,RANDOM_FIT));
		$display("Allocated randomly a buffer of size 256.");
		mem.print(0);
		$display("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation());
		n.start_addr = 12;
		n.size = 16;
		$display("Changed buffer start_addr to 12 and size to 16.");
		mem.print(0);
		$display("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation());
		$display("Try to insert the buffer.");
		void'(mem.insert(n));
		mem.print(0);
		$display("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation());
		void'(mem.deallocate(n));
		$display("Deallocated buffer.");
		mem.print(0);
		$display("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation());		
		void'(mem.insert(n));
		$display("Try to insert the buffer.");
		mem.print(0);
		$display("Usage: %0d Frag: %0d", mem.get_usage_statistics(), mem.get_fragmentation());
		
			

		if(mem.check_address_space_consistency())
			$display("Consistency Checked!");

	endtask
endmodule

