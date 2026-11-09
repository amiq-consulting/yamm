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

#ifndef __yamm_deallocate
#define __yamm_deallocate

#include "yamm.h"

using namespace yamm_ns;

bool yamm_buffer::deallocate(yamm_buffer* del) {

	if (!del) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Can't deallocate a NULL buffer!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	if (del->is_static) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Can't deallocate a static buffer!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	if (del->size <= 0) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Buffer size has to be > 0! Probably already deallocated.\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	if (del->is_free) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Can't deallocate a free buffer!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Only a direct child's next/prev are relative to this level's lists;
	// for deeper buffers the parent-chain walk below determines ownership
	if (del->parent == this) {
		if ((del->next == NULL) && (del->prev == NULL) && (first != del)) {
			if (!disable_warnings)
				fprintf(stderr,
						"[YAMM_WRN] Buffer is not linked anywhere!\n\t in %s at line %d\n",
						__FILE__, __LINE__);
			return 0;
		}
	}

	// Reject buffers whose chain doesn't reach this level (sibling/foreign);
	// self-deallocate is naturally rejected: the chain starts at the parent
	bool buffer_in_memory = false;
	yamm_buffer* owner = del->parent;
	// The parent chain can't loop: allocate()/insert() refuse buffers that
	// already have a parent, so no depth guard is needed
	while (owner && !buffer_in_memory) {
		if (owner == this)
			buffer_in_memory = true;
		else
			owner = owner->parent;
	}

	// The buffer isn't allocated anywhere inside this memory
	if (!buffer_in_memory) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] The buffer is not allocated in this memory. Deallocation failed.\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// Delegate to the direct owner so the buffer is removed from the
	// correct (deepest) list
	if ((del->parent != NULL) && (del->parent != this))
		return del->parent->deallocate(del);

	if (del->first != NULL) {
		if (!disable_info)
			fprintf(stderr,
					"[YAMM_INF] Buffer has other buffers inside!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
	}

	yamm_buffer* temp;

	// Create a new buffer to replace the deallocated one
	yamm_buffer* new_free_buffer = new yamm_buffer(del->start_addr, del->size);
	new_free_buffer->is_free = 1;
	new_free_buffer->parent = this;
	new_free_buffer->next = del->next;
	new_free_buffer->prev = del->prev;
	if (del->prev)
		del->prev->next = new_free_buffer;
	if (del->next)
		del->next->prev = new_free_buffer;

	// One less occupied buffer and one more free
	number_of_buffers--;
	number_of_free_buffers++;

	// Merge adjacent free buffers
	merge(new_free_buffer);

	if (new_free_buffer->start_addr == start_addr)
		first = new_free_buffer;

	// Link the new buffer in the lists
	temp = new_free_buffer;

	if (temp->next) {
		temp = temp->next;
		while ((!temp->is_free) && (temp->next))
			temp = temp->next;
		if (temp->is_free) {
			temp->prev_free = new_free_buffer;
			new_free_buffer->next_free = temp;
		} else
			// No free buffer after the new one: it is the tail of the free list
			last_free = new_free_buffer;
	} else
		// The new free buffer is the last buffer of this level
		last_free = new_free_buffer;

	temp = new_free_buffer;

	if (temp->prev) {
		temp = temp->prev;
		while ((!temp->is_free) && (temp->prev))
			temp = temp->prev;
		if (temp->is_free) {
			temp->next_free = new_free_buffer;
			new_free_buffer->prev_free = temp;
		} else
			first_free = new_free_buffer;
	} else
		first_free = new_free_buffer;

	del->parent = NULL;
	// delete del: the destructor recursively deletes the child list and
	// severs all its links
	delete del;

	return 1;

}

bool yamm_buffer::deallocate_by_addr(uint_64_t addr) {
	return deallocate(internal_get_buffer(addr));
}

#endif // __yamm_deallocate
