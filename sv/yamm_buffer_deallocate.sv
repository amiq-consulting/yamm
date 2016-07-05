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

function bit yamm_buffer::deallocate(yamm_buffer del, bit recursive = 1);

	yamm_buffer temp;
	yamm_buffer free_n;

	// First check if basic conditions are met (The buffer is allocated and has a positive size)
	if(del._size<=0)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_DEALLOC_WARN", "Buffer's size has to be > 0, probably deallocated already. Deallocation failed.");
		`else
		$warning("YAMM_DEALLOC_WARN: Buffer's size has to be > 0, probably deallocated already. Deallocation failed.");
		`endif
		return 0;
	end

	// If the buffer is static it can't be deallocated
	if(del._static)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_DEALLOC_WARN", "Buffer is static. Deallocation failed.");
		`else	
		$warning("YAMM_DEALLOC_WARN: Buffer is static. Deallocation failed.");
		`endif
		return 0;
	end

	// The buffer has to be occupied to be deallocated
	if(del.free)
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_DEALLOC_WARN", "Buffer is free");
		`else
		$warning("YAMM_DEALLOC_WARN: Buffer is free");
		`endif
		return 0;
	end

	// The buffer has to be linked somewhere in the memory
	if((del.next == null) && (del.prev == null) && (this.first != del)) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_DEALLOC_WARN", "Buffer is not linked anywhere in the memory. Deallocation failed.");
		`else
		$warning("YAMM_DEALLOC_WARN: Buffer is not linked anywhere in the memory. Deallocation failed.");
		`endif
		return 0;
	end

	// If the recursive bit is not set and there are buffers inside this buffer
	// don't deallocate it
	if((first != null) && (recursive == 0)) begin
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_DEALLOC_WARN", "The buffer has other buffers inside it's memory space!");
		`else
		$warning("YAMM_DEALLOC_WARN: The buffer has other buffers inside it's memory space!");
		`endif
		return 0;
	end

	// First create a new free buffer to replace the one we want to deallocate
	free_n = new;
	free_n._size = del._size;
	free_n._start_addr = del._start_addr;
	free_n._end_addr = del._end_addr;
	free_n.free = 1;
	free_n.next = del.next;
	free_n.prev = del.prev;
	if(del.prev)
		del.prev.next = free_n;
	if(del.next)
		del.next.prev = free_n;

	//TODO: Manage the situation in which the user keeps a reference to a buffer that's inside the deallocated buffer
	// The user should manage that on his own for now

	number_of_buffers--;
	number_of_free_buffers++;

	// Now we check if the adjacent buffers are free and concatenate them if so
	merge(free_n);

	// If out buffer has the starting address the same as the memory map move
	// the first pointer to it
	if(free_n._start_addr == _start_addr)
		first = free_n;

	// Find the next/prev free buffers to the one we deallocated

	temp = free_n;

	if(temp.next)
	begin
		temp = temp.next;
		while((!temp.free)&&(temp.next))
			temp = temp.next;
		if(temp.free)
		begin
			temp.prev_free = free_n;
			free_n.next_free = temp;
		end
	end

	temp = free_n;

	if(temp.prev)
	begin
		temp = temp.prev;
		while((temp.free) && (temp.prev))
			temp = temp.prev;
		if(temp.free)
		begin
			temp.next_free = free_n;
			free_n.prev_free = temp;
		end
		else
			first_free = free_n;
	end
	else
		first_free = free_n;

	// Delete any references the buffer possesses
	del.next = null;
	del.prev = null;
	del.first = null;
	del.first_free = null;
	del.next_free = null;
	del.prev_free = null;

	del._start_addr = 0;
	del._end_addr = 0;
	del._size = 0;

	//$display("Buffer was deallocated successful.");
	return 1;

endfunction

function bit yamm_buffer::deallocate_by_addr(yamm_addr_width addr);

	// The function uses get_buffer() to pass the look-up buffer to
	// the deallocate() function
	return deallocate(get_buffer(addr));

endfunction

`endif
