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

`ifndef __yamm_buffer
`define __yamm_buffer

typedef class yamm_buffer;

/**
 * Defines a queue of yamm_buffer
 */
typedef yamm_buffer yamm_buffer_q[$];

/**
 * Defines a byte array
 */
typedef byte yamm_byte_s[];


/**
 * The main class, contains all the functions used for memory management
 *
 * Each instance of the buffer represents a region in the memory and also
 * contains it's own memory map that can be used for recursive buffer allocation
 */
class yamm_buffer
	`ifdef YAMM_USE_UVM
	extends uvm_object
	`endif
	;

	// Pointer to the first free buffer in the current memory space
	protected yamm_buffer first_free;

	// Pointer to the first buffer in the current memory space (can be free or occupied)
	protected yamm_buffer first;

	// Pointer to the next buffer in memory (Used by both occupied and free buffers)
	protected yamm_buffer next;

	// Pointer to the previous buffer in memory (Used by both occupied and free buffers)
	protected yamm_buffer prev;

	// Pointer to the next free buffer in memory (Used by free buffers only)
	protected yamm_buffer next_free;

	// Pointer to the previous free buffer in memory (Used by free buffers only)
	protected yamm_buffer prev_free;


	// If set to 1 it will disable all warnings caused by various inconsistencies
	bit disable_warnings=0;


	// Buffer's payload, set by user using set_contents() or generate_contents()
	local byte contents[];

	// Type name, set by user using set_name()
	protected string name;

	// When this bit is 1 the buffer is static
	protected bit is_static = 0;


	// End address of the buffer, computed automatically, can be read using get_end_addr()
	protected yamm_addr_width_t end_addr=0;

	// Start address of the buffer, can be set using set_start_addr() or set_start_addr_size() and read using get_start_addr()
	protected yamm_addr_width_t start_addr=0;

	// Size of the buffer, can be set using set_size() and read using get_size()
	protected yamm_size_width_t size=0;

	// Granularity of the buffer, can be set using set_granularity() and can be read using get_granularity()
	protected int granularity=1;

	// Start_addr_alignment, can be set using start_addr_alignment() and can be read using get_start_addr_alignment()
	protected int start_addr_alignment=1;

	// When this bit is 1 the buffer is unoccupied
	protected bit is_free=0;

	// Keeps count of the number of occupied buffers in memory
	protected int number_of_buffers = 0;

	// Keeps count of the number of free buffers in memory
	protected int number_of_free_buffers = 1;


	`ifdef YAMM_USE_UVM
	`uvm_object_utils(yamm_buffer)
	function new(string name = "");
		super.new(name);
	endfunction
	`else
	function new();
	endfunction
	`endif


	/**
	 * It adds buffer n inside free buffer temp, it calls link_in_list to update the pointers
	 *
	 * @param n : The new buffer that will be added to the memory
	 * @param temp: The free buffer found by find_suitable_buffer() in which n is going to be allocated
	 */
	extern local function void add(yamm_buffer new_buffer, yamm_buffer suitable_free_buffer);

	/**
	 * Used to compute start_addr with alignment, only works for positive increment
	 * Used by allocate() and insert()
	 *
	 * @param alignment : The alignment needed
	 * @param temp : Free buffer in which the allocation takes place, used for boundaries checking
	 *
	 * @return Aligned start_addr if boundaries checking passes or temp buffer's (end_addr+1) if not
	 */
	extern local function yamm_addr_width_t get_aligned_addr(int alignment, yamm_buffer suitable_free_buffer);

	/**
	 * Used for finding a suitable buffer in which the new buffer can be allocated
	 * Used by compute_size_with_align() and insert()
	 *
	 * @param size : The size of the new buffer
	 * @param alignment : The alignment of the new buffer
	 * @param alloc_mode : The allocation mode, dictates the search rules
	 *
	 * @return A suitable free buffer if it exists or NULL otherwise
	 */
	extern local function yamm_buffer find_suitable_buffer(yamm_size_width_t size, int alignment, yamm_allocation_mode_e alloc_mode);

	/**
	 * Computes and returns the size of the buffer on which it is called
	 * Used by allocate()
	 *
	 * @param size : The regular size of the buffer
	 * @param granularity: The granularity of the buffer
	 *
	 * @return The new size taking in account the granularity
	 */
	extern local function yamm_size_width_t compute_size_with_gran(yamm_size_width_t size, int granularity);

	/**
	 * Computes the size taking in account alignment using get_aligned_addr()
	 * Used by find_suitable_buffer()
	 *
	 * @param alignment : The regular size of the buffer
	 * @param temp: The free buffer passed to get_aligned_addr()
	 *
	 * @return The new size taking in account the granularity
	 */
	extern local function yamm_size_width_t compute_size_with_align(int alignment, yamm_buffer suitable_free_buffer);

	/**
	 * It automatically updates the start_addr taking in account the alignment
	 * It can modify the start_addr both by adding to it or subtracting from it
	 * Used by compute_size_with_align()
	 *
	 * @param temp : The buffer in which the allocation takes place, usable for boundaries checking
	 */
	extern local function void get_closest_aligned_addr(yamm_buffer suitable_free_buffer);

	/**
	 * It computes and updates start_addr for various allocation modes, uses get_aligned_addr() and get_closest_aligned_addr()
	 * Used by allocate()
	 *
	 * @param temp : The buffer in which the allocation takes place, used to set boundaries
	 * @param alloc_mode : Allocation mode that dictates how the alignment is applied
	 *
	 */
	extern local function bit compute_start_addr(yamm_buffer suitable_free_buffer, yamm_allocation_mode_e alloc_mode);

	/**
	 * It merges free buffers after deallocation
	 *
	 * @param free_n : The buffer that was deallocated, it is going to get merged with neighboring buffers if they are free
	 */
	extern local function void merge(yamm_buffer new_free_buffer);

	/**
	 * It links buffers in memory after adding a new buffer
	 *
	 * @param temp_prev : The free buffer created from the start of the old free buffer that spans to the start of the new buffer, can be NULL
	 * @param n : The new buffer that was just allocated
	 * @param temp : The old buffer that was resized, if the end address of the new buffer matches its end address then it won't get linked
	 */
	extern local function void link_in_list(yamm_buffer prev_free_buffer, yamm_buffer new_buffer, yamm_buffer next_free_buffer);

	/**
	 * Function used to propagate the reset to buffers allocated inside other buffers
	 */
	extern protected function void intern_reset();

	/**
	 * It prints all the buffers in order
	 * If recursive bit is set it also prints the buffers inside other buffers
	 */
	extern protected function void print(bit recursive=0);

	/**
	 * It prints all the free buffers in order
	 */
	extern protected function void print_free();

	/**
	 * It prints the number of occupied buffer, the number of free buffers as well as
	 * the usage statistics and fragmentation
	 */
	extern function void print_stats();

	/**
	 * It checks if the alignment constraint is obeyed
	 */
	extern function bit check_alignment();

	/**
	 * Same as get_buffer() but it can also return free buffer, used internally
	 */
	extern local function yamm_buffer internal_get_buffer(yamm_addr_width_t start);




	/**
	 * This function tries to allocate the buffer randomly in the memory, according to
	 * the yamm_allocation_mode_e
	 *
	 * The buffer argument handle is required to contain a valid size (bigger than zero)
	 *
	 * @param n : The new buffer that is going to get allocated
	 * @param allocation_mode : The allocation mode according to which the allocation will be done
	 *
	 * @return It returns 1 if the buffer was successfully allocated or 0 otherwise. It returns 0 if there is no free space for the buffer to be allocated.
	 * On successful allocation, the buffer handle is updated with additional information: start_addr, end_addr
	 */
	extern function bit allocate(yamm_buffer new_buffer, yamm_allocation_mode_e allocation_mode = RANDOM_FIT);

	/**
	 * This function tries to allocate a buffer with the specified size in the memory,
	 * according to yamm_allocation_mode_e.
	 *
	 * Function creates a new buffer with that size and calls allocate()
	 *
	 * @param size: The size of the new buffer
	 * @param allocation_mode : The allocation mode according to which the allocation will be done
	 *
	 * @return It returns a buffer handle if successful or a null handle otherwise
	 */
	extern function yamm_buffer allocate_by_size(yamm_addr_width_t size, yamm_allocation_mode_e allocation_mode = RANDOM_FIT);

	/**
	 * This function tries to insert a buffer in the memory with the specified start_addr and size.
	 * The function makes use of the field size and the start_addr contained in the specified buffer.
	 *
	 * @param n : The new buffer that is going to be inserted
	 *
	 * @return It returns 1 if the operation is successful or 0 if the buffer would collide with another buffer in the memory.
	 *
	 */
	extern function bit insert(yamm_buffer new_buffer);

	/**
	 * Similar to insert(), this function will try to insert a buffer at a specified address in memory,
	 * but it takes an access as an argument instead of a buffer.
	 *
	 * @param access : The access from which the buffer is created
	 *
	 * @return It returns the allocated buffer handle if the operation is successful or a null handle otherwise.
	 */
	extern function yamm_buffer insert_access(yamm_access access);




	/**
	 * It searches for the buffer located at the specified address.
	 *
	 * @param start : The address for which the search is executed
	 *
	 * @return Returns the buffer which contains the specified address. It returns a NULL handle if no buffer exists at the specfied address
	 */
	extern function yamm_buffer get_buffer(yamm_addr_width_t start);

	/**
	 * It searches for all buffers that span in the address space defined by start_addr and end_addr.
	 *
	 * @param start_addr : The start address of the memory span on which the search is done
	 * @param end_addr : The end address of the memory span on which the search is done
	 *
	 * @return Returns a queue of buffers. If end_addr is less than start_addr or no buffers are found it will return an empty queue.
	 */
	extern function yamm_buffer_q get_buffers_in_range(yamm_addr_width_t start_addr, yamm_addr_width_t end_addr);

	/**
	 * It searches for all buffers that span in the address range specified by access.
	 * The address range is computed using start_addr and size fields of yamm_access.
	 *
	 * @param access : The access from which the search parameters are extracted
	 *
	 * @return It returns a queue of buffers. If no buffers are found, it will return an empty queue.
	 */
	extern function yamm_buffer_q get_buffers_by_access(yamm_access access);

	/**
	 * Because SV doesn’t support type checking, the search will be done according
	 * to the type name set with set_name().
	 *
	 * @param type_name : The name for which the search is done
	 *
	 * @return Function returns a queue with all buffers of a certain kind.
	 */
	extern function yamm_buffer_q get_all_buffers_by_type(string type_name);




	/**
	 * This function tries to deallocate a buffer allocated in the memory.
	 *
	 * @param del : The buffer that is going to be deallocated
	 * @param recursive : If set then it will deallocate the buffer even if it contains other buffers inside
	 *
	 * @return It returns 1 if successful. It returns 0 if the specified buffer can’t be found or is a static buffer.
	 * It also returns 0 if ‘recursive’ bit is not set, and it contains allocated buffers.
	 */
	extern function bit deallocate(yamm_buffer deleted_buffer, bit recursive = 1);

	/**
	 * This function tries to deallocate from the memory the buffer which
	 * contains the specified address.
	 *
	 * A warning is given if the buffer contains other buffers inside.
	 *
	 * @param addr : The address at which the buffer that is going to get deallocated resides.
	 *
	 * @return It returns 1 if successful. It returns 0 if the specified buffer can’t be found or is a static buffer.
	 */
	extern function bit deallocate_by_addr(yamm_addr_width_t addr);




	/**
	 * Store custom data in the buffer. If the size of the data array set
	 * doesn’t match the size of the buffer, a warning will be triggered.
	 * This warning can be turned off.
	 *
	 * @param data[] : The string that is going to be saved as payload inside the buffer
	 * @param warning : If set 1 (default) a warning will be displayed if the size of the contents don't match the size of the buffer
	 *
	 */
	extern virtual function void set_contents(byte data[], bit warning = 1);

	/**
	 * This function returns the data stored in the buffer. If no data
	 * was previously stored with set_contents() it will do a call to
	 * generate_contents() to get data.
	 *
	 * @return Contents stored inside the buffer
	 */
	extern virtual function yamm_byte_s get_contents();

	/**
	 * A hook function which the user can extend to implement a custom generation
	 * rule for data. By default it generates pure random data which is then
	 * stored with set_contents().
	 *
	 * Function can be overwritten by user for custom comparison.
	 */
	extern virtual function void generate_contents();

	/**
	 * It compares cmp data with data stored inside the buffer.
	 * Function can be overwritten by user for custom comparison.
	 *
	 * @param cmp : The string that will be compared to the contents stored in buffer
	 *
	 * @return It returns 1 if they match or 0 otherwise
	 */
	extern virtual function bit compare_contents(yamm_byte_s cmp_data);

	/**
	 * Wipes the data stored in the buffer
	 */
	extern virtual function void reset_contents();




	/**
	 * It returns the structured memory map of the current buffer as a string.
	 *
	 * @param recursive : If set to 1 it will return the maps for all the buffers inside it as well.
	 * @param identation : Shoudn't be changed by user! It updates automatically on recursive calls.
	 *
	 * @return A string of the structured memory map
	 */
	extern function string sprint_buffer(bit recursive=0, int identation=0);

	/**
	 * It computes the memory usage percentage.
	 * @return Returns the percentage of used memory out of the total memory size.
	 */
	extern function real get_usage_statistics();

	/**
	 * It computes the memory fragmentation percentage.
	 * @return Returns the percentage of occupied buffers out of the total number of buffers.
	 */
	extern function real get_fragmentation();




	/**
	 * It checks if an access overlaps the current buffer
	 * @param access : The access for which the check is done
	 *
	 * @return Returns 1 if access overlaps, at least partially, any allocated buffer.
	 */
	extern function bit access_overlaps(yamm_access access);

	/**
	 * This function is used to do a self-check on the memory model to see if all
	 * the buffers are correctly allocated by the model.
	 * It will trigger an error message if any inconsistency is found.
	 * It is used for debug purposes.
	 *
	 * @return Returns 1 if no error are found and 0 otherwise.
	 */
	extern function bit check_address_space_consistency();

	/**
	 * It sets an optional name tag to the buffer.
	 * This name can later be used by function get_all_buffers_by_type().
	 *
	 * @param name : The name that will be saved in buffer for future searches.
	 */
	function void set_name(string name);
		this.name = name;
	endfunction




	/**
	 *  Function used to set the start address of the buffer it is called from
	 */
	extern function void set_start_addr(yamm_addr_width_t new_start_address);

	/**
	 *  Function used to set the size of the buffer it is called from
	 */
	extern function void set_size(yamm_size_width_t new_size);

	/**
	 *  Function used to set both the size and the start_address of the buffer it is called from
	 */
	extern function void set_start_addr_size(yamm_addr_width_t new_start_address, yamm_size_width_t new_size);

	/**
	 *  Function used to set the start_addr_alignment of the buffer it is called from
	 */
	extern function void set_start_addr_alignment(int new_start_addr_alignment);

	/**
	 *  Function used to set the granularity of the buffer it is called from
	 */
	extern function void set_granularity(int new_granularity);

	/**
	 * @return Returns the start_addr of the buffer it is called from.
	 */
	extern function yamm_addr_width_t get_start_addr();

	/**
	 * @return Returns the size of the buffer it is called from.
	 */
	extern function yamm_size_width_t get_size();

	/**
	 * @return Returns the end_addr of the buffer it is called from.
	 */
	extern function yamm_addr_width_t get_end_addr();

	/**
	 * @return Returns the start_addr_alignment of the buffer it is called from.
	 */
	extern function int get_start_addr_alignment();

	/**
	 * @return Returns the granularity of the buffer it is called from.
	 */
	extern function int get_granularity();

	/**
	 * @return Returns the type name of the buffer
	 */
	extern function string get_name();


endclass

`endif
