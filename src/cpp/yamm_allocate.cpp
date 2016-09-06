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

#ifndef __yamm_allocate
#define __yamm_allocate

#include "yamm.h"

using namespace yamm_ns;

// Function allocates buffer n according to allocation_mode
bool yamm_buffer::allocate(yamm_buffer* new_buffer, int allocation_mode) {

	if (size == 0) {
		fprintf(stderr,
				"[YAMM_ERR] Memory wasn't built! (size is 0)\n\t in %s at line %d\n",
				__FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	if (!new_buffer) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] No suitable buffer was given as argument!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Sanitation check: Don't allocate buffers that are already in the memory
	if ((new_buffer->next) || (new_buffer->prev)) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Buffer is already linked in memory!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Check if it has a positive size
	if (new_buffer->size == 0) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Buffer with size 0!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	if (new_buffer->first) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Can't allocate buffers with children!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Compute size with granularity
	new_buffer->size = new_buffer->size
			+ (new_buffer->granularity - new_buffer->size % new_buffer->granularity) % new_buffer->granularity;

	// Find a free buffer that can contain the allocated buffer and matches the selected allocation_mode
	yamm_buffer* temp_free = find_suitable_buffer(new_buffer->size,
			new_buffer->start_addr_alignment, allocation_mode);

	if (!temp_free) {
		return 0;
	}

	// If a valid handle is returned by the search function compute the start and end addr and add it
	// inside the found buffer
	if (!new_buffer->compute_start_addr(temp_free, allocation_mode))
		return 0;

	new_buffer->end_addr = new_buffer->start_addr + new_buffer->size - 1;
	add(new_buffer, temp_free);
	return 1;

}

// Function creates a new buffer with the specified size and then calls allocate for that buffer
yamm_buffer* yamm_buffer::allocate_by_size(uint_64_t size,
		int allocation_mode) {

	// Creates a new buffer with the size and allocation_mode specified then calls function allocate.
	yamm_buffer* n = new yamm_buffer(size);

	if (allocate(n, allocation_mode))
		return n;

	// Allocation failed so we clean up and return a NULL handle
	delete n;
	return NULL;
}

#endif // __yamm_allocate
