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

#ifndef __yamm_insert
#define __yamm_insert

#include "yamm.h"

using namespace yamm_ns;

bool yamm_buffer::insert(yamm_buffer* n) {
	yamm_buffer* temp;

	// Check given buffer
	if (!n) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Buffer argument is null!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Sanitation check: don't insert buffers already in the memory
	if ((n->next) || (n->prev) || (n->next_free) || (n->prev_free)) {
		fprintf(stderr,
				"[YAMM_WRN] Buffer is already in the memory!\n\t in %s at line %d\n",
				__FILE__, __LINE__);
		return 0;
	}

	// If there is no handle to the first buffer then the memory map is not initialized
	if (!first) {
		first_free = new yamm_buffer; // Initialize it with a new free buffer of the same size as the memory map
		first_free->start_addr = start_addr;
		first_free->size = size;
		first_free->end_addr = first_free->start_addr + first_free->size - 1;
		first_free->is_free = 1;
		first = first_free;
		temp = first_free;
	}

	if (n->start_addr_alignment == 0) {
		fprintf(stderr,
				"[YAMM_ERR] Alignment can't be 0!\n\t in %s at line %d\n",
				__FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	if (n->granularity == 0) {
		fprintf(stderr,
				"[YAMM_ERR] Granularity can't be 0!\n\t in %s at line %d\n",
				__FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	if ((n->start_addr % n->start_addr_alignment)
			|| (n->size % n->granularity)) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Buffer doesn't respect alignment or granulation!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		if (!disable_info)
			fprintf(stderr,
					"[YAMM_INF] Buffer will be inserted anyways.\n\t in %s at line %d\n",
					__FILE__, __LINE__);
	}

	// Get the buffer the contains the address of n
	temp = internal_get_buffer(n->start_addr);
	// Calculate buffer end address
	n->end_addr = n->start_addr + n->size - 1;

	if (!temp) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN]  The starting address of the buffer is not in memory!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Returned buffer is ocupied
	if (!temp->is_free) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Address is already used!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	if (n->size < 1) {
		fprintf(stderr,
				"[YAMM_ERR] Size: %llu is invalid!\n\t in %s at line %d\n",
				n->size, __FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	if (n->end_addr > temp->end_addr) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Not enough space to insert!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	add(n, temp);
	return 1;

}

bool yamm::allocate_static(yamm_buffer* n) {

	if (!init_done) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Memory wasn't built!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	n->is_static = 1;

	if (this->insert(n)) {
		// Save the static buffers in a separated queue
		static_buffers_queue.push(n);
		return 1;
	} else {
		return 0;
	}

	return 1;
}

yamm_buffer* yamm_buffer::insert_access(yamm_access* access) {

	yamm_buffer* n = new yamm_buffer;
	n->start_addr = access->start_addr;
	n->end_addr = access->end_addr;
	n->size = access->size;

	if (insert(n))
		return n;
	else
		return NULL;

}

#endif // __yamm_insert
