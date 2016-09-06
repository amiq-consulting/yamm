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

`ifndef __yamm_buffer_insert
`define __yamm_buffer_insert

function bit yamm_buffer::insert(yamm_buffer new_buffer);
	// Get the buffer that contains the address of new_buffer
	yamm_buffer handle_to_buffer;

	// Check if the buffer has positive size
	if(new_buffer.size < 1) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The buffer's size has to be > 0. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The buffer's size has to be > 0. Insertion failed.");
		`endif
		return 0;
	end

	if(new_buffer.start_addr % new_buffer.start_addr_alignment != 0)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The start_addr of the buffer doesn't match its alignment! Trying to insert anyway.");
		`else
		$warning("[YAMM_WRN] The start_addr of the buffer doesn't match its alignment! Trying to insert anyway.");
		`endif

	if(new_buffer.size % new_buffer.granularity != 0)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The size of the buffer doesn't match its granularity! Trying to insert anyway.");
		`else
		$warning("[YAMM_WRN] The size of the buffer doesn't match its granularity! Trying to insert anyway.");
		`endif


	// Check if the given parameter is a valid handle
	if(!new_buffer) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "No valid buffer was given as argument. Insertion failed.");
		`else
		$warning("[YAMM_WRN] No valid buffer was given as argument. Insertion failed.");
		`endif
		return 0;
	end

	// Check to see if it is linked to any other buffers
	if((new_buffer.next) || (new_buffer.prev)) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The buffer is already allocated somewhere in the memory. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The buffer is already allocated somewhere in the memory. Insertion failed.");
		`endif
		return 0;
	end

	// If there is no handle to the first buffer then the memory map is not initialized
	// Initialize it with a new free buffer of the same size as the memory map
	// It is used when allocating inside a buffer
	if(!first) begin
		first_free = new;
		first_free.start_addr = start_addr;
		first_free.size = size;
		first_free.end_addr = first_free.start_addr + first_free.size - 1;
		first_free.is_free = 1;
		first = first_free;
		handle_to_buffer = first_free;
	end

	new_buffer.end_addr = new_buffer.start_addr + new_buffer.size - 1;
	handle_to_buffer = internal_get_buffer(new_buffer.start_addr);

	// We are using the get_buffer function which can return a null handle
	// if the address is not valid
	if(!handle_to_buffer) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The starting address of the buffer is not in memory. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The starting address of the buffer is not in memory. Insertion failed.");
		`endif
		return 0;
	end

	if(handle_to_buffer.is_free == 0) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The address is occupied. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The address is occupied. Insertion failed.");
		`endif
		return 0;
	end

	// Allocate the buffer if possible 
	if(handle_to_buffer.start_addr > new_buffer.start_addr) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "The address is occupied. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The address is occupied. Insertion failed.");
		`endif
		return 0;
	end

	if(new_buffer.end_addr > handle_to_buffer.end_addr) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "The buffer overlaps, not enough space. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The buffer overlaps, not enough space. Insertion failed.");
		`endif
		return 0;
	end

	if(handle_to_buffer.size >= new_buffer.size) begin
		add(new_buffer,handle_to_buffer);
		return 1;
	end

	if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The buffer doesn't fit. Insertion failed.");
		`else
		$warning("[YAMM_WRN] The buffer doesn't fit. Insertion failed.");
		`endif
	return 0;
endfunction

function yamm_buffer yamm_buffer::insert_access(yamm_access access);

	// Create a new buffer using the accesses parameters as arguments

	yamm_buffer n = new;
	access.compute_end_addr();
	n.start_addr = access.start_addr;
	n.size = access.size;

	if(insert(n))
		return n;
	else
		return null;
endfunction

`endif
