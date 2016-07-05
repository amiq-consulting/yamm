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

`ifndef __yamm_buffer_allocate
`define __yamm_buffer_allocate

function bit yamm_buffer::allocate(yamm_buffer n, yamm_allocation_mode_e allocation_mode = RANDOM_FIT);

	yamm_buffer temp;

	if(_size == 0) begin
		`ifdef YAMM_USE_UVM
		`uvm_error("ALLOC_ERROR", "Memory wasn't built (Size = 0)");
		`else
		$error($sformatf("Memory wasn't built (Size = 0)"));
		`endif
		return 0;
	end
	// Check if the handle is valid
	if(!n) begin
		if(!disable_warnings)
			`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_ALLOC_WARN", "No suitable buffer was given as argument. Allocation failed.");
			`else
		    $warning("YAMM_ALLOC_WARN: No suitable buffer was given as argument. Allocation failed.");
			`endif
		return 0;
	end

	// The hidden data
	n._start_addr_alignment = n.start_addr_alignment;
	n._granularity = n.granularity;
	n._size = compute_size_with_gran(n.size, n.granularity);

	// Sanitation check: Don't allocate buffers that are already in the memory
	if((n.next) || (n.prev)) begin

		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_ALLOC_WARN", "The buffers is already allocated in the memory. Allocation failed.");
		`else
		$warning("YAMM_ALLOC_WARN: The buffers is already allocated in the memory. Allocation failed.");
		`endif
		return 0;
	end

	// Check if it has a positive size
	if(n._size <= 0)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_ALLOC_WARN", "The size of the buffer has to be > 0. Allocation failed.");
		`else
		$warning("YAMM_ALLOC_WARN: The size of the buffer has to be > 0. Allocation failed.");
		`endif
		return 0;
	end

	// Find a free buffer that can contain the allocated buffer and matches the selected allocation_mode
	temp = find_suitable_buffer(n._size, n._start_addr_alignment, allocation_mode);

	// If a valid handle is returned by the search function compute the start and end addr and add it inside the found buffer
	if(temp) begin
		if(n.compute_start_addr(temp, allocation_mode)) begin
			n._end_addr = n._start_addr + n._size - 1;
			add(n, temp);
		end
		else
			return 0;

		n.start_addr = n._start_addr;
		n.size = n._size;
		return 1;

	end
	else
		return 0;


endfunction

function yamm_buffer yamm_buffer::allocate_by_size(yamm_addr_width size, yamm_allocation_mode_e allocation_mode = RANDOM_FIT);

	// Create a buffer and give it the specified size
	yamm_buffer n = new;
	n.size = size;

	// Allocate it using the allocation function
	if(this.allocate(n, allocation_mode)) begin
		n.start_addr = n._start_addr;
		n.size = n._size;
		return n;
	end
	else
		return null;

endfunction

`endif
