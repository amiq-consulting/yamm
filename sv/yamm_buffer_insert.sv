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

function bit yamm_buffer::insert(yamm_buffer n);
	// Get the buffer that contains the address of n
	yamm_buffer temp;
	yamm_addr_width t_start_addr;
	yamm_size_width tsize;

	// Check if the given parameter is a valid handle
	if(!n) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "No valid buffer was given as argument. Insertion failed.");
		`else	
		$warning("YAMM_INSERT_WARN: No valid buffer was given as argument. Insertion failed.");
		`endif
		return 0;
	end

	// Check to see if it is linked to any other buffers
	if(((n.next) || (n.prev)) && (n._static == 0)) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The buffer is already allocated somewhere in the memory. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The buffer is already allocated somewhere in the memory. Insertion failed.");
		`endif
		return 0;
	end

	// Write the local parameters
	n._start_addr = n.start_addr;
	n._size = n.size;
	n._start_addr_alignment = n.start_addr_alignment;

	// If there is no handle to the first buffer then the memory map is not initialized
	// Initialize it with a new free buffer of the same size as the memory map
	// It is used when allocating inside a buffer
	if(!first)
	begin
		first_free = new;
		first_free._start_addr = _start_addr;
		first_free._size = _size;
		first_free._end_addr = first_free._start_addr + first_free._size - 1;
		first_free.free = 1;
		first = first_free;
		temp = first_free;
	end

	n._end_addr = n._start_addr + n._size - 1;
	temp = get_buffer(n._start_addr);

	// We are using the get_buffer function which can return a null handle
	// if the address is not valid
	if(!temp) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The starting address of the buffer is not in memory. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The starting address of the buffer is not in memory. Insertion failed.");
		`endif
		return 0;
	end

	if(temp.free == 1)
	begin
		t_start_addr = temp.get_aligned_addr(n._start_addr_alignment, temp);
		tsize = temp._end_addr - t_start_addr + 1;
	end
	else
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The address is occupied. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The address is occupied. Insertion failed.");
		`endif
		return 0;
	end

	// Check if the buffer has positive size
	if(n._size < 1)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The buffer's size has to be > 0. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The buffer's size has to be > 0. Insertion failed.");
		`endif
		return 0;
	end

	// Allocate the buffer if possible
	if(t_start_addr > n._start_addr)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The address is occupied. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The address is occupied. Insertion failed.");
		`endif
		return 0;
	end

	if(n._end_addr > temp._end_addr)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The buffer overlaps, not enough space. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The buffer overlaps, not enough space. Insertion failed.");
		`endif
		return 0;
	end

	if(tsize >= n._size)
	begin
		add(n,temp);
		return 1;
	end

	if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_INSERT_WARN", "The buffer doesn't fit. Insertion failed.");
		`else
		$warning("YAMM_INSERT_WARN: The buffer doesn't fit. Insertion failed.");
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
