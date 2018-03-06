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

`ifndef __yamm
`define __yamm

/**
 *
 * Top level class, acts as the full memory. This is the only level on which static buffers can be allocated
 *
 */
class yamm extends yamm_buffer;

	// As long as this bit is 0 nothing can be done -> memory has to be built before it can be used
	local bit built = 0;

	// As long as this bit is 0 and built bit is 1 static buffers can be allocated and regular buffers can't -> memory has to be reset after static buffers allocation and before further use
	local bit initialized = 0;

	// Every time a static buffer is allocate it is pushed in this queue. The entire queue is allocated in the memory when reset is called.
	local yamm_buffer_q static_qu;

	/**
	 * Function that initializes the memory, setting a name and a size for the memory as well as
	 * creating a free buffer over the entire memory span, supporting allocation and making the memory usable.
	 * Can only be called once.
	 *
	 * @param name - A name set for the memory
	 * @param size - The size of the memory
	 */
	extern function void build(string name, yamm_size_width_t size);

	/**
	 *
	 * @param n_buffer - The new static buffer that will be allocated, if it is valid it will be inserted and also pushed in a queue on top level for
	 * fast retrieval
	 *
	 * @return Returns 1 if the buffer was allocated or 0 if it overlaps at least partially other allocated buffer
	 */
	extern function bit allocate_static_buffer(yamm_buffer n_buffer);

	/**
	 * Can not be used if build wasn't called. Function that deallocated all non-static buffers and also clears the contents
	 * and all buffers allocated inside static buffers
	 *
	 */
	extern function void reset();

	/**
	 *
	 * @return Returns the queue of static buffers that are stored in memory.
	 */
	extern function yamm_buffer_q get_static_buffers();

	/**
	 * Function that dumps memory to file starting with the level it is called on. Can be done recursively if bit is set.
	 *
	 * @param recursive - If set, the function will also dump buffers stored inside the current buffer
	 * @return Returns 1 if done successfully, or 0 otherwise
	 */
	function bit write_memory_map_to_file(bit recursive=0);
		int uid = $urandom();
		string fname = $sformatf("yamm_dump_%s_%0x_%0x_%4x.txt", name, start_addr, end_addr, uid);
		int fd = $fopen(fname, "w");
		if(fd) begin
			$fwrite(fd, sprint_buffer(1));
			$fclose(fd);
			return 1;
		end
		else
			return 0;
	endfunction

endclass


function void yamm::build(string name, yamm_size_width_t size);

	yamm_buffer mem;

	if(this.built)
	begin
		`ifdef YAMM_USE_UVM
		`uvm_error("YAMM_ERR", "Memory wasn't built (Size = 0)");
		`else
		$error($sformatf("[YAMM_ERR] Memory was already built! File:%0s Line:%0d", `__FILE__, `__LINE__));
		`endif
		return;
	end

	this.built = 1;

	// The visible data
	this.size = size;

	// The hidden data
	size = size;
	end_addr = size - 1;
	this.set_name(name);

	mem = new();
	mem.size = this.size;
	mem.end_addr = this.end_addr;
	mem.size = mem.size;
	mem.is_free = 1;
	first_free = mem;
	first = mem;

	number_of_buffers = 0;
	number_of_free_buffers = 1;

endfunction


function bit yamm::allocate_static_buffer(yamm_buffer n_buffer);

	if(built == 0)
	begin
		`ifdef YAMM_USE_UVM
		`uvm_error("YAMM_ERR", "Memory wasn't built (Size = 0)");
		`else
		$error($sformatf("[YAMM_ERR] Memory wasn't built! File:%0s Line:%0d", `__FILE__, `__LINE__));
		`endif
		return 0;
	end

	n_buffer.is_static = 1;
	n_buffer.start_addr = n_buffer.start_addr;
	n_buffer.size = n_buffer.size;
	n_buffer.end_addr = n_buffer.start_addr + n_buffer.size - 1;

	if(this.insert(n_buffer)) begin
		static_qu.push_back(n_buffer);
		return 1;
	end
	else
		return 0;

endfunction


function yamm_buffer_q yamm::get_static_buffers();
	return static_qu;
endfunction


function void yamm::reset();

	if(built == 0) begin
		`ifdef YAMM_USE_UVM
		`uvm_error("YAMM_ERR", "Memory wasn't built (Size = 0)");
		`else
		$error($sformatf("[YAMM_ERR] Memory wasn't built! File:%0s Line:%0d", `__FILE__, `__LINE__));
		`endif
		return;
	end

	this.intern_reset();

endfunction

`endif
