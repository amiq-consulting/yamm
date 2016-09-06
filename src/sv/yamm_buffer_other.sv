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

`ifndef __yamm_buffer_other
`define __yamm_buffer_other

function bit yamm_buffer::check_address_space_consistency();
	yamm_buffer handle_to_buffer = first;
	yamm_buffer recursive_handle_to_buffer;

	while(handle_to_buffer)
	begin

		if(handle_to_buffer.next) begin
			// The start address of the following buffer has to be at the next address of the current's end address
			if(!(handle_to_buffer.next.start_addr == (handle_to_buffer.end_addr+1))) begin
				return 0;
			end

			// There shoudn't be 2 consecutive free buffers
			if(handle_to_buffer.is_free && handle_to_buffer.next.is_free) begin
				return 0;
			end
		end
		
		// The end address - start_address + 1 should equal the buffer's size
		if((handle_to_buffer.end_addr - handle_to_buffer.start_addr + 1) != (handle_to_buffer.size)) begin
			return 0;
		end

		// The size of the buffer should be positive
		if(handle_to_buffer.size < 1) begin
			return 0;
		end

		// Recursive check for the buffers inside the current memory space
		if(handle_to_buffer.first) begin
			// Check that the first buffer has the same starting address as its memory space
			if(handle_to_buffer.first.start_addr != handle_to_buffer.start_addr) begin
				$display("1");
				$display(handle_to_buffer.sprint_buffer(1));
				return 0;
			end

			if(handle_to_buffer.check_address_space_consistency()==0)
				return 0;

			// Take a handle to the first buffer useful for traversing it
			recursive_handle_to_buffer = handle_to_buffer.first;

			// Find the last buffer in the memory space
			while(recursive_handle_to_buffer.next)
				recursive_handle_to_buffer = recursive_handle_to_buffer.next;

			// Check if its end address matches the end address of its memory space
			if(recursive_handle_to_buffer.end_addr != handle_to_buffer.end_addr) begin
				$display("2");
				$display(handle_to_buffer.sprint_buffer(1));
				return 0;
			end

		end
		handle_to_buffer = handle_to_buffer.next;
	end
	return 1;
endfunction

function bit yamm_buffer::access_overlaps(yamm_access access);

	// Use the internal_get_buffer function to get a handle to the buffer
	// specified by the access parameters
	yamm_buffer handle_to_buffer = internal_get_buffer(access.start_addr);
	access.compute_end_addr();

	// If there is a occupied buffer between the start and
	// end address of the access return 1 (buffer overlap)
	while((handle_to_buffer) && (handle_to_buffer.start_addr <= access.end_addr)) begin
		if(handle_to_buffer.is_free == 0)
			return 1;
		handle_to_buffer = handle_to_buffer.next;
	end

	return 0;

endfunction

// Function returns 0 if buffer start_addr is not aligned according to start_addr_alignement
function bit yamm_buffer::check_alignment();

	// Don't check free buffers
	if(is_free == 1)
		return 1;

	// Check alignment using modulo property
	if(start_addr % start_addr_alignment != 0) begin
		return 0;
	end

	return 1;

endfunction

function void yamm_buffer::set_start_addr(yamm_addr_width_t new_start_address);

	if(next!=null || prev != null) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "Can't modify a linked buffer!");
		`else
		$warning("[YAMM_WRN] Can't modify a linked buffer!");
		`endif
		return;
	end

	this.start_addr = new_start_address;

endfunction

function void yamm_buffer::set_size(yamm_size_width_t new_size);

	if(next!=null || prev != null) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "Can't modify a linked buffer!");
		`else
		$warning("[YAMM_WRN] Can't modify a linked buffer!");
		`endif
		return;
	end

	this.size = new_size;

endfunction

function void yamm_buffer::set_start_addr_size(yamm_addr_width_t new_start_address, yamm_size_width_t new_size);

	if(next!=null || prev != null) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "Can't modify a linked buffer!");
		`else
		$warning("[YAMM_WRN] Can't modify a linked buffer!");
		`endif
		return;
	end

	this.start_addr = new_start_address;
	this.size = new_size;

endfunction

function void yamm_buffer::set_start_addr_alignment(int new_start_addr_alignment);

	if(next!=null || prev != null) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "Can't modify a linked buffer!");
		`else
		$warning("[YAMM_WRN] Can't modify a linked buffer!");
		`endif
		return;
	end

	this.start_addr_alignment = new_start_addr_alignment;

endfunction

function void yamm_buffer::set_granularity(int new_granularity);

	if(next!=null || prev != null) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "Can't modify a linked buffer!");
		`else
		$warning("[YAMM_WRN] Can't modify a linked buffer!");
		`endif
		return;
	end

	this.granularity = new_granularity;

endfunction

function yamm_addr_width_t yamm_buffer::get_start_addr();

	return this.start_addr;

endfunction

function yamm_size_width_t yamm_buffer:: get_size();

	return this.size;

endfunction

function yamm_addr_width_t yamm_buffer::get_end_addr();

	return this.end_addr;

endfunction

function int yamm_buffer::get_start_addr_alignment();

	return this.start_addr_alignment;

endfunction

function int yamm_buffer::get_granularity();

	return this.granularity;

endfunction


`endif
