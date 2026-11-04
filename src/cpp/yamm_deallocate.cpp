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

	// This guard is only meaningful when del is a direct child of this level.
	// When called from an ancestor level, del lives in a deeper list and its
	// next/prev are relative to that list, not ours — so skip the check and
	// let the parent-chain walk below determine ownership.
	if (del->parent == this) {
		if ((del->next == NULL) && (del->prev == NULL) && (first != del)) {
			if (!disable_warnings)
				fprintf(stderr,
						"[YAMM_WRN] Buffer is not linked anywhere!\n\t in %s at line %d\n",
						__FILE__, __LINE__);
			return 0;
		}
	}

	// Walk the parent chain to check ownership: reject buffers whose
	// chain doesn't reach this level (sibling/foreign branch).
	// Self-deallocate is naturally rejected, since the chain starts
	// at the buffer's parent, not the buffer itself.
	bool buffer_in_memory = false;
	yamm_buffer* owner = del->parent;
	// Guard against hypothetical parent-chain cycles with a bounded walk.
	int depth = 0;
	while (owner && !buffer_in_memory && depth < 256) {
		if (owner == this)
			buffer_in_memory = true;
		else
			owner = owner->parent;
		depth++;
	}

	// The buffer isn't allocated anywhere inside this memory
	if (!buffer_in_memory) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] The buffer is not allocated in this memory. Deallocation failed.\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// If the buffer is a child of a deeper level of this memory, delegate
	// the deallocation to the level that directly contains it, so the
	// buffer is removed from the correct list
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
		}
	}

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
	delete del;

	return 1;

}

bool yamm_buffer::deallocate_by_addr(uint_64_t addr) {
	return deallocate(internal_get_buffer(addr));
}

#endif // __yamm_deallocate
