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

`ifndef __yamm_buffer_deallocate
`define __yamm_buffer_deallocate

function bit yamm_buffer::deallocate(yamm_buffer deleted_buffer, bit recursive = 1);

	yamm_buffer handle_to_buffer;
	yamm_buffer new_free_buffer;

	// Check if the buffer is null
	if(deleted_buffer == null) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "The buffer provided is a null handle. Deallocation failed.");
		`else
		$warning("[YAMM_WRN] The buffer provided is a null handle. Deallocation failed.");
		`endif
		return 0;
	end

	// First check if basic conditions are met (The buffer is allocated and has a positive size)
	if(deleted_buffer.size<=0)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Buffer's size has to be > 0, probably deallocated already. Deallocation failed.");
		`else
		$warning("[YAMM_WRN] Buffer's size has to be > 0, probably deallocated already. Deallocation failed.");
		`endif
		return 0;
	end

	// If the buffer is static it can't be deallocated
	if(deleted_buffer.is_static)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Buffer is static. Deallocation failed.");
		`else
		$warning("[YAMM_WRN] Buffer is static. Deallocation failed.");
		`endif
		return 0;
	end

	// The buffer has to be occupied to be deallocated
	if(deleted_buffer.is_free)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Buffer is free");
		`else
		$warning("[YAMM_WRN] Buffer is free.");
		`endif
		return 0;
	end

	// The buffer has to be linked somewhere in the memory
	if((deleted_buffer.next == null) && (deleted_buffer.prev == null) && (this.first != deleted_buffer)) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Buffer is not linked anywhere in the memory. Deallocation failed.");
		`else
		$warning("[YAMM_WRN] Buffer is not linked anywhere in the memory. Deallocation failed.");
		`endif
		return 0;
	end

	// If the recursive bit is not set and there are buffers inside this buffer
	// don't deallocate it
	if((first != null) && (recursive == 0)) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", "The buffer has other buffers inside it's memory space!");
		`else
		$warning("[YAMM_WRN] The buffer has other buffers inside it's memory space!");
		`endif
		return 0;
	end

	// First create a new free buffer to replace the one we want to deallocate
	new_free_buffer = new;
	new_free_buffer.size = deleted_buffer.size;
	new_free_buffer.start_addr = deleted_buffer.start_addr;
	new_free_buffer.end_addr = deleted_buffer.end_addr;
	new_free_buffer.is_free = 1;
	new_free_buffer.next = deleted_buffer.next;
	new_free_buffer.prev = deleted_buffer.prev;
	if(deleted_buffer.prev)
		deleted_buffer.prev.next = new_free_buffer;
	if(deleted_buffer.next)
		deleted_buffer.next.prev = new_free_buffer;

	number_of_buffers--;
	number_of_free_buffers++;

	// Now we check if the adjacent buffers are free and concatenate them if so
	merge(new_free_buffer);

	// If out buffer has the starting address the same as the memory map move
	// the first pointer to it
	if(new_free_buffer.start_addr == start_addr)
		first = new_free_buffer;

	// Find the next/prev free buffers to the one we deallocated

	handle_to_buffer = new_free_buffer;

	if(handle_to_buffer.next)
	begin
		handle_to_buffer = handle_to_buffer.next;
		while((!handle_to_buffer.is_free)&&(handle_to_buffer.next))
			handle_to_buffer = handle_to_buffer.next;
		if(handle_to_buffer.is_free)
		begin
			handle_to_buffer.prev_free = new_free_buffer;
			new_free_buffer.next_free = handle_to_buffer;
		end
	end

	handle_to_buffer = new_free_buffer;

	if(handle_to_buffer.prev)
	begin
		handle_to_buffer = handle_to_buffer.prev;
		while((!handle_to_buffer.is_free) && (handle_to_buffer.prev))
			handle_to_buffer = handle_to_buffer.prev;
		if(handle_to_buffer.is_free)
		begin
			handle_to_buffer.next_free = new_free_buffer;
			new_free_buffer.prev_free = handle_to_buffer;
		end
		else
			first_free = new_free_buffer;
	end
	else
		first_free = new_free_buffer;

	// Delete any references the buffer possesses
	deleted_buffer.next = null;
	deleted_buffer.prev = null;
	deleted_buffer.first = null;
	deleted_buffer.first_free = null;
	deleted_buffer.next_free = null;
	deleted_buffer.prev_free = null;

	deleted_buffer.start_addr = 0;
	deleted_buffer.end_addr = 0;
	deleted_buffer.size = 0;

	return 1;

endfunction

function bit yamm_buffer::deallocate_by_addr(yamm_addr_width_t addr);

	// The function uses internal_get_buffer() to pass the look-up buffer to
	// the deallocate() function
	return deallocate(internal_get_buffer(addr));

endfunction

`endif
