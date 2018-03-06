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

function bit yamm_buffer::allocate(yamm_buffer new_buffer, yamm_allocation_mode_e allocation_mode = RANDOM_FIT);

	yamm_buffer handle_to_buffer;

	if(size == 0) begin
		`ifdef YAMM_USE_UVM
		`uvm_error("YAMM_ERR", "Memory wasn't built (Size = 0)");
		`else
		$error($sformatf("[YAMM_ERR] Memory wasn't built (Size = 0)"));
		`endif
		return 0;
	end
	// Check if the handle is valid
	if(!new_buffer) begin
		if(!disable_warnings)
			`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "No suitable buffer was given as argument. Allocation failed.");
			`else
		$warning("[YAMM_WRN] No suitable buffer was given as argument. Allocation failed.");
			`endif
		return 0;
	end

	// The hidden data
	new_buffer.size = compute_size_with_gran(new_buffer.size, new_buffer.granularity);

	// Sanitation check: Don't allocate buffers that are already in the memory
	if((new_buffer.next) || (new_buffer.prev)) begin

		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "The buffers is already allocated in the memory. Allocation failed.");
		`else
		$warning("[YAMM_WRN] The buffers is already allocated in the memory. Allocation failed.");
		`endif
		return 0;
	end

	// Check if it has a positive size
	if(new_buffer.size <= 0)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "The size of the buffer has to be > 0. Allocation failed.");
		`else
		$warning("[YAMM_WRN] The size of the buffer has to be > 0. Allocation failed.");
		`endif
		return 0;
	end

	if(new_buffer.first != null)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Can't allocate buffers with children!");
		`else
		$warning("[YAMM_WRN] Can't allocate buffers with children!");
		`endif
		return 0;
	end
	
	// Find a free buffer that can contain the allocated buffer and matches the selected allocation_mode
	handle_to_buffer = find_suitable_buffer(new_buffer.size, new_buffer.start_addr_alignment, allocation_mode);

	// If a valid handle is returned by the search function compute the start and end addr and add it inside the found buffer
	if(handle_to_buffer) begin
		if(new_buffer.compute_start_addr(handle_to_buffer, allocation_mode)) begin
			new_buffer.end_addr = new_buffer.start_addr + new_buffer.size - 1;
			add(new_buffer, handle_to_buffer);
		end
		else
			return 0;

		return 1;

	end
	else
		return 0;



endfunction

function yamm_buffer yamm_buffer::allocate_by_size(yamm_size_width_t size, yamm_allocation_mode_e allocation_mode = RANDOM_FIT);

	// Create a buffer and give it the specified size
	yamm_buffer new_buffer = new;
	new_buffer.size = size;

	// Allocate it using the allocation function
	if(this.allocate(new_buffer, allocation_mode)) begin
		return new_buffer;
	end
	else
		return null;

endfunction

`endif
