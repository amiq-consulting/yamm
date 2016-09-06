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

`ifndef __yamm_buffer_get_buffers
`define __yamm_buffer_get_buffers

function yamm_buffer yamm_buffer::get_buffer(yamm_addr_width_t start);

	yamm_buffer handle_to_buffer;
	handle_to_buffer = first;

	// Check if the address given is valid (it exists in the memory map)
	if((start>end_addr) || (start<start_addr))
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Address is outside current memory map boundaries. Search failed.");
		`else
		$warning("[YAMM_WRN] Address is outside current memory map boundaries. Search failed.");
		`endif
		return null;
	end

	// Look for the buffer that contains the given address
	while((handle_to_buffer.next) && (handle_to_buffer.end_addr < start))
		handle_to_buffer = handle_to_buffer.next;

	// If the buffer is found and is allocated return it
	if(start>=handle_to_buffer.start_addr)
	begin
		if(handle_to_buffer.is_free == 0)
			return handle_to_buffer;
		else
			return null;
	end else begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Search failed.");
		`else
		$warning("[YAMM_WRN] Search failed.");
		`endif
		return null;
	end
endfunction


function yamm_buffer_q yamm_buffer::get_buffers_in_range(yamm_addr_width_t start_addr, yamm_addr_width_t end_addr);

	// Use the get_buffer() function to return the first buffer
	yamm_buffer handle_to_buffer = internal_get_buffer(start_addr);
	yamm_buffer qu[$];

	// If the given addresses are not valid (end > start) return the queue empty
	if(end_addr < start_addr)
		return qu;

	// If the start address belongs to a valid buffer push buffers in the
	// queue until end address is reached then return the queue
	while((handle_to_buffer) && (handle_to_buffer.end_addr <= end_addr))
	begin
		if(handle_to_buffer.is_free == 0)
			qu.push_back(handle_to_buffer);
		handle_to_buffer = handle_to_buffer.next;
	end

	return qu;
endfunction


function yamm_buffer_q yamm_buffer::get_buffers_by_access(yamm_access access);

	// We first compute the end addr for the access based on the start_addr and size of access
	access.compute_end_addr();

	// We use the get_buffers_in_range function using the access parameters
	return get_buffers_in_range(access.start_addr, access.end_addr);
endfunction

function yamm_buffer_q yamm_buffer::get_all_buffers_by_type(string type_name);
	yamm_buffer handle_to_buffer = first;
	yamm_buffer qu[$];

	// (Slow) Traverse the entire memory pushing in the queue the buffers which name match the given string
	while(handle_to_buffer.next)
	begin
		if(handle_to_buffer.name == type_name)
			qu.push_back(handle_to_buffer);
		handle_to_buffer = handle_to_buffer.next;
	end
	return qu;
endfunction


`endif
