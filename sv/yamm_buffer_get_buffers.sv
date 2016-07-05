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

function yamm_buffer yamm_buffer::get_buffer(yamm_addr_width start);

	yamm_buffer temp;
	temp = first;

	// Check if the address given is valid (it exists in the memory map)
	if((start>_end_addr) || (start<_start_addr))
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_SEARCH_WARN", "Address is outside current memory map boundaries. Search failed.");
		`else
		$warning("YAMM_SEARCH_WARN: Address is outside current memory map boundaries. Search failed.");
		`endif
		return null;
	end

	// Look for the buffer that contains the given address
	while((temp.next) && (temp._end_addr < start))
		temp = temp.next;

	// If the buffer is found return it.
	if(start>=temp._start_addr) 
	begin
		//$display("Buffer found.");
		return temp;
	end else begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_SEARCH_WARN", "Search failed.");
		`else
		$warning("YAMM_SEARCH_WARN: Search failed.");
		`endif
		return null;
	end
endfunction

function yamm_buffer_q yamm_buffer::get_buffers_in_range(yamm_addr_width start_addr, yamm_addr_width end_addr);

	// Use the get_buffer() function to return the first buffer
	yamm_buffer temp = get_buffer(start_addr);
	yamm_buffer qu[$];

	// If the given addresses are not valid (end > start) return the queue empty
	if(end_addr < start_addr)
		return qu;

	// If the start address belongs to a valid buffer push buffers in the
	// queue until end address is reached then return the queue
	while((temp.next) && (temp._end_addr <= end_addr))
	begin
		if(temp.free == 0)
			qu.push_back(temp);
		temp = temp.next;
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
	yamm_buffer temp = first;
	yamm_buffer qu[$];

	// (Slow) Traverse the entire memory pushing in the queue the buffers which name match the given string
	while(temp.next)
	begin
		if(temp.name == type_name)
			qu.push_back(temp);
		temp = temp.next;
	end
	return qu;
endfunction


`endif
