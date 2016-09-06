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

#ifndef __yamm_buffer_h
#define __yamm_buffer_h

#include "yamm_access.h"
#include <vector>

namespace yamm_ns {

#ifndef uint_32_t
typedef unsigned int uint_32_t;
#endif

/**
 *  Class that defines a buffer
 */
class yamm_buffer {
private:
	friend class yamm;
protected:

	// Top buffer pointers (container level)

	/** first free buffer contained */
	yamm_buffer* first_free;
	/**  first buffer contained (free or occupied) */
	yamm_buffer* first;

	// Links in the list (current level)

	/** next free buffer on current recursion level */
	yamm_buffer* next_free;
	/** previous free buffer on current recursion level */
	yamm_buffer* prev_free;
	/**  next buffer on current recursion level (free or occupied) */
	yamm_buffer* next;
	/**  previous free buffer on current recursion level (free or occupied) */
	yamm_buffer* prev;

	/** buffer's payload */
	char* contents;
	/**  number of occupied buffers */
	uint number_of_buffers;
	/** number of free buffers */
	uint number_of_free_buffers;

	/** Start address of the buffer */
	uint_64_t start_addr;
	/** End address of the buffer */
	uint_64_t end_addr;
	/** Size of the buffer */
	uint_64_t size;

	/** Granularity of the buffer */
	uint_32_t granularity;
	/** Alignment of the buffer */
	uint_32_t start_addr_alignment;

	/** Buffer is not occupied */
	bool is_free;
	/** Buffer is allocated in static mode */
	bool is_static;

	/** Name given by user */
	std::string name;

	/**
	 *  Generates a random unsigned int64
	 *  @return random unsigned int64
	 */
	uint_64_t generate_rand64();

	/**
	 * Used to compute start_addr with alignment, only works for positive increment
	 * Used by allocate() and insert()
	 *
	 * @param alignment The alignment needed
	 * @param free_buffer Free buffer in which the allocation takes place, used for boundaries checking
	 *
	 * @return Aligned start_addr if boundaries checking passes or temp buffer's (end_addr+1) if not
	 */
	uint_64_t get_aligned_addr(const uint_32_t &alignment,
			yamm_buffer* free_buffer);

	/**
	 * Computes the size taking in account alignment using get_aligned_addr()
	 * Used by find_suitable_buffer()
	 *
	 * @param alignment  The regular size of the buffer
	 * @param temp The granularity of the buffer
	 *
	 * @return The new size taking in account the granularity
	 */
	uint_64_t compute_size_with_align(const uint_32_t &alignment,
			yamm_buffer* temp);

	/**
	 * Computes and returns the size of the buffer on which it is called
	 * Used by allocate()
	 *
	 * @param size The regular size of the buffer
	 * @param granularity The granularity of the buffer
	 *
	 * @return The new size taking in account the granularity
	 */
	uint_64_t compute_size_with_gran(uint_64_t size, uint_32_t granularity);

	/**
	 * It computes and updates start_addr for various allocation modes, uses get_aligned_addr() and get_closest_aligned_addr()
	 * Used by allocate()
	 *
	 * @param temp The buffer in which the allocation takes place, used to set boundaries
	 * @param alloc_mode Allocation mode that dictates how the alignment is applied
	 *
	 * @return 1 if success , 0 otherwise
	 */
	bool compute_start_addr(yamm_buffer* temp, int alloc_mode);

	/**
	 * It automatically updates the start_addr taking in account the alignment
	 * It can modify the start_addr both by adding to it or subtracting from it
	 * Used by compute_size_with_align()
	 *
	 * @param temp The buffer in which the allocation takes place, usable for boundaries checking
	 */
	void get_closest_aligned_addr(yamm_buffer* temp);

	/**
	 * It adds buffer n inside free buffer temp, it calls link_in_list to update the pointers
	 *
	 * @param buffer_to_fit The new buffer that will be added to the memory
	 * @param place The free buffer found by find_suitable_buffer() in which n is going to be allocated
	 */
	void add(yamm_buffer* buffer_to_fit, yamm_buffer* place);

	/**
	 * It links buffers in memory after adding a new buffer
	 *
	 * @param temp_prev The free buffer created from the start of the old free buffer that spans to the start of the new buffer, can be NULL
	 * @param n The new buffer that was just allocated
	 * @param temp The old buffer that was resized, if the end address of the new buffer matches its end address then it won't get linked
	 */
	void link_in_list(yamm_buffer* temp_prev, yamm_buffer* n,
			yamm_buffer* temp);

	/**
	 * It merges free buffers after deallocation
	 *
	 * @param free_n The buffer that was deallocated, it is going to get merged with neighboring buffers if they are free
	 */
	void merge(yamm_buffer* free_n);

	/**
	 * Used for finding a suitable buffer in which the new buffer can be allocated
	 * Used by compute_size_with_align() and insert()
	 *
	 * @param size The size of the new buffer
	 * @param alignment The alignment of the new buffer
	 * @param alloc_mode The allocation mode, dictates the search rules
	 *
	 * @return A suitable free buffer if it exists or NULL otherwise
	 */
	yamm_buffer* find_suitable_buffer(uint_64_t size, uint_32_t alignment,
			int alloc_mode);

	/**
	 *  Same as get_buffer() but it can also return free buffer, used internally.
	 *
	 * @param address The address for which the search is executed
	 *
	 * @return Returns the buffer which contains the specified address. It returns a NULL handle if no buffer exists at the specfied address
	 */
	yamm_buffer* internal_get_buffer(uint_64_t address);

	// Debug functions

	/**
	 * Function that traverses the entire memory printing each buffer's number, size, start and end address.
	 * @param fp Pointer to the file you want to dump the memory to
	 */
	void print(FILE* fp);

	/**
	 * Function that traverses the FREE memory printing each buffer's number, size, start and end address.
	 * @param fp Pointer to the file you want to dump the memory to
	 */
	void print_free(FILE* fp);

	/**
	 *	Function that prints the size argument according to it's size (Gb,Mb,Kb,bytes).
	 *
	 *	@return Buffer's size
	 */
	std::string print_size();

public:

	/** 0 by default. If set to 1 no YAMM_WRN will be shown */
	bool disable_warnings;
	/** 0 by default. If set to 1 no YAMM_INF will be shown */
	bool disable_info;

	// Constructors

	/** All fields are set to the default value */
	yamm_buffer();
	/** Just size is set. WARNING start_addr == end_addr == 0! */
	yamm_buffer(uint_64_t size);
	/** Set the start and end address. Size is computed automatically */
	yamm_buffer(uint_64_t start, uint_64_t size);
	/** Just the name */
	yamm_buffer(std::string name);
	/** Size + name */
	yamm_buffer(uint_64_t size, std::string name);

	/** All fields will be identical to the buffer given as argument */
	yamm_buffer(yamm_buffer* new_buffer);

	/**
	 *  Removes all buffers that are not static.
	 */
	void soft_reset();

	/**
	 *  Function that deallocates all (including static) buffers.
	 */
	void hard_reset();

	/**
	 * This function tries to allocate the buffer in the memory, according to
	 * the allocation_mode
	 *
	 * The buffer argument handle is required to contain a valid size (bigger than zero)
	 *
	 * @param new_buffer The new buffer that is going to get allocated
	 * @param allocation_mode The allocation mode according to which the allocation will be done
	 *
	 * @return It returns 1 if the buffer was successfully allocated or 0 otherwise. It returns 0 if there is no free space for the buffer to be allocated.
	 * On successful allocation, the buffer handle is updated with additional information: start_addr, end_addr
	 */
	bool allocate(yamm_buffer* new_buffer, int allocation_mode);

	/**
	 * This function tries to allocate a buffer with the specified size in the memory,
	 * according to allocation_mode.
	 *
	 * Function creates a new buffer with that size and calls allocate()
	 *
	 * @param size The size of the new buffer
	 * @param allocation_mode The allocation mode according to which the allocation will be done
	 *
	 * @return It returns a buffer handle if successful or a null handle otherwise
	 */
	yamm_buffer* allocate_by_size(uint_64_t size, int allocation_mode);

	/**
	 * This function tries to insert a buffer in the memory with the specified start_addr and size.
	 * The function makes use of the field size and the start_addr contained in the specified buffer.
	 *
	 * @param new_buffer The new buffer that is going to be inserted
	 *
	 * @return It returns 1 if the operation is successful or 0 if the buffer would collide with another buffer in the memory.
	 *
	 */
	bool insert(yamm_buffer* new_buffer);

	/**
	 * Similar to insert(), this function will try to insert a buffer at a specified address in memory,
	 * but it takes an access as an argument instead of a buffer.
	 *
	 * @param access The access from which the buffer is created
	 *
	 * @return It returns the allocated buffer handle if the operation is successful or a null handle otherwise.
	 *
	 */
	yamm_buffer* insert_access(yamm_access* access);

	// Functions to do with contents

	/**
	 * Store custom data in the buffer. If the size of the data array set
	 * doesn’t match the size of the buffer, a warning will be triggered.
	 *
	 * @param payload The string that is going to be saved as payload inside the buffer
	 * @param size Size in bytes of the payload
	 * @return 1 if success , 0 otherwise
	 *
	 */
	virtual bool set_contents(char* payload, uint_64_t size);

	/**
	 * A hook function which the user can extend to implement a custom generation
	 * rule for data. By default it generates pure random data which is then
	 * stored with set_contents().
	 *
	 * Function can be overwritten by user for custom comparison.
	 */
	virtual bool generate_random_contents();

	/**
	 *  Function that wipes the data stored in the buffer
	 */
	void reset_contents();

	/**
	 * This function returns the data stored in the buffer. If no data
	 * was previously stored with set_contents() it will do a call to
	 * generate_contents() to get data.
	 *
	 * @return Contents stored inside the buffer
	 */
	virtual char* get_contents();

	/**
	 * Function that compares the content from current buffer to the reference
	 *
	 * @param reference Content that will be compared
	 * @param ref_size Size in bytes of the reference param
	 *
	 * @return 1 if contents are equal, 0 otherwise
	 */
	virtual bool compare_contents(char* reference, uint_64_t ref_size);

	// Functions used to free buffers

	/**
	 * This function tries to deallocate a buffer allocated in the memory.
	 *
	 * A warning is given if the buffer contains other buffers inside.
	 *
	 * @param buffer The buffer that is going to be deallocated
	 *
	 * @return It returns 1 if successful. It returns 0 if the specified buffer can’t be found or is a static buffer.
	 */

	bool deallocate(yamm_buffer* buffer);

	/**
	 * This function tries to deallocate from the memory the buffer which
	 * contains the specified address.
	 *
	 * A warning is given if the buffer contains other buffers inside.
	 *
	 * @param address The address at which the buffer that is going to get deallocated resides.
	 *
	 * @return It returns 1 if successful. It returns 0 if the specified buffer can’t be found or is a static buffer.
	 */
	bool deallocate_by_addr(uint_64_t address);

	// Functions used to find buffers

	/**
	 * It searches for the buffer located at the specified address.
	 *
	 * @param address The address for which the search is executed
	 *
	 * @return Returns the buffer which contains the specified address. It returns a NULL handle if no buffer used exists at the specfied address
	 */
	yamm_buffer* get_buffer(uint_64_t address);

	/**
	 * It searches for all buffers that span in the address space defined by start_addr and end_addr.
	 *
	 * @param start_addr The start address of the memory span on which the search is done
	 * @param end_addr The end address of the memory span on which the search is done
	 *
	 * @return Returns a vector of buffers. If end_addr is less than start_addr or no buffers used are found it will return an empty queue.
	 */
	std::vector<yamm_buffer> get_buffers_in_range(uint_64_t start_addr,
			uint_64_t end_addr);

	/**
	 * It searches for all buffers that span in the address range specified by access.
	 * The address range is computed using start_addr and size fields of yamm_access.
	 *
	 * @param access The access from which the search parameters are extracted
	 *
	 * @return It returns a queue of buffers. If no buffers are found, it will return an empty queue.
	 */
	std::vector<yamm_buffer> get_buffers_by_access(yamm_access* access);

	/**
	 * Searches by the name given to the buffers
	 *
	 * @param name_to_find The name for which the search is done
	 *
	 * @return Function returns a queue with all buffers of a certain kind.
	 */
	std::vector<yamm_buffer> get_buffers_by_name(std::string name_to_find);

	// Other functions
	bool access_overlaps(yamm_access* access);

	/**
	 *  Returns the memory structure as a string.
	 *
	 *	@param recursive If set to 1 it will print the memory recursive
	 *	@param indentation Used when going in recursion
	 *
	 *	@return The memory structure as a string
	 */
	std::string sprint(bool recursive, int indentation);

	/**
	 *  Writes the memory structure to file
	 *
	 *  @param filename Path to the file
	 */
	void write_to_file(std::string filename);
	/**
	 *  Returns the percentage of fragmentation
	 */
	double get_fragmentation();

	/**
	 *  Returns the percentage of free memory compared to the whole memory.
	 */
	double get_usage_statistics();

	/**
	 * This function is used to do a self-check on the memory model to see if all
	 * the buffers are correctly allocated by the model.
	 * It will trigger an error message if any inconsistency is found.
	 * It is used for debug purposes.
	 *
	 * @return Returns 1 if no errors are found and 0 otherwise.
	 */
	bool check_address_space_consistency();

	std::string get_name() {
		return this->name;
	}
	;

	uint_64_t get_start_addr() {
		return this->start_addr;
	}

	uint_64_t get_end_addr() {
		return this->end_addr;
	}

	uint_64_t get_size() {
		return this->size;
	}

	bool get_is_free() {
		return this->is_free;
	}

	bool get_is_static() {
		return this->is_static;
	}

	uint_32_t get_start_addr_alignment() {
		return this->start_addr_alignment;
	}

	uint_32_t get_granularity() {
		return this->granularity;
	}

	void set_name(std::string new_name) {
		this->name = new_name;
	}

	void set_start_addr(uint_64_t start_addr) {

		if (this->next || this->prev) {
			if (!disable_warnings)
				fprintf(stderr,
						"[YAMM_WRN] Can't modify a linked buffer!\n\t in %s at line %d\n",
						__FILE__, __LINE__);
			return;
		}

		this->start_addr = start_addr;
		this->end_addr = this->start_addr + this->size - 1;
	}

	void set_size(uint_64_t size) {

		if (this->next || this->prev) {
			if (!disable_warnings)
				fprintf(stderr,
						"[YAMM_WRN] Can't modify a linked buffer!\n\t in %s at line %d\n",
						__FILE__, __LINE__);
			return;
		}

		this->size = size;
		this->end_addr = this->start_addr + this->size - 1;
	}

	void set_start_addr_alignment(uint_32_t alignment) {

		if (this->next || this->prev) {
			if (!disable_warnings)
				fprintf(stderr,
						"[YAMM_WRN] Can't modify a linked buffer!\n\t in %s at line %d\n",
						__FILE__, __LINE__);
			return;
		}

		this->start_addr_alignment = alignment;
	}

	void set_granularity(uint_32_t granularity) {

		if (this->next || this->prev) {
			if (!disable_warnings)
				fprintf(stderr,
						"[YAMM_WRN] Can't modify a linked buffer!\n\t in %s at line %d\n",
						__FILE__, __LINE__);
			return;
		}

		this->granularity = granularity;
	}

	/**
	 * Destructor
	 * Frees everything
	 */
	virtual ~yamm_buffer();

};

}
#endif // __yamm_buffer_h
