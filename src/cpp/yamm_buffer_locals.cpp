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

#ifndef __yamm_buffer_locals
#define __yamm_buffer_locals

#include "yamm.h"

using namespace yamm_ns;

uint_64_t yamm_buffer::get_aligned_addr(const uint_32_t &start_addr_alignment,
		yamm_buffer* temp) {

	if (start_addr_alignment == 1)
		return temp->start_addr;

	uint_32_t align = (start_addr_alignment
			- temp->start_addr % start_addr_alignment);
	align = align % start_addr_alignment;

	// If the buffer displacement start address fits in the buffer return
	// the new start address
	if ((temp->start_addr + align) <= temp->end_addr)
		return temp->start_addr + align;

	return temp->end_addr + 1;
}

uint_64_t yamm_buffer::compute_size_with_gran(uint_64_t size,
		uint_32_t granularity) {
	return size + (granularity - size % granularity) % granularity;
}

uint_64_t yamm_buffer::compute_size_with_align(
		const uint_32_t &start_addr_alignment, yamm_buffer* temp) {
	return temp->end_addr - get_aligned_addr(start_addr_alignment, temp) + 1;
}

void yamm_buffer::get_closest_aligned_addr(yamm_buffer* temp) {

	// Closest aligned address to the right and left
	uint_64_t negalign = (start_addr % start_addr_alignment)
			% start_addr_alignment;
	uint_64_t posalign = (start_addr_alignment
			- start_addr % start_addr_alignment) % start_addr_alignment;

	// Apply the lower one of the two
	if ((negalign <= posalign) && (start_addr - negalign >= temp->start_addr))
		start_addr = start_addr - negalign;
	else
		start_addr = start_addr + posalign;

}

bool yamm_buffer::compute_start_addr(yamm_buffer* temp, int alloc_mode) {

	switch (alloc_mode) {
	// First fit and best fit have the same behavior
	case YAMM_FIRST_FIT ... YAMM_BEST_FIT: {
		start_addr = get_aligned_addr(start_addr_alignment, temp);
		if (start_addr > temp->end_addr)
			return 0;
		else
			return 1;
		break;
	}
		// All 3 random modes have the same behavior
	case YAMM_RANDOM_FIT ... YAMM_BEST_FIT_RND: {

		if (start_addr_alignment == 1) {
			if ((temp->end_addr - temp->start_addr - size + 1) > 0)
				// Generate a random start address that allows allocation
				start_addr =
						temp->start_addr
								+ (generate_rand64()
										% (temp->end_addr - temp->start_addr
												- size + 1));
			else
				start_addr = temp->start_addr;



		} else {
			if ((temp->end_addr - temp->start_addr - size + 1
					- start_addr_alignment) > 0)
				// Same as above but taking in consideration the alignment
				start_addr = temp->start_addr
						+ (generate_rand64()
								% (temp->end_addr - temp->start_addr - size + 1
										- start_addr_alignment));
			else
				start_addr = temp->start_addr;

			this->get_closest_aligned_addr(temp);
		}
		break;
	}
		// Insert in the middle of the free buffer
	case YAMM_UNIFORM_FIT: {
		start_addr = temp->start_addr + (temp->size - size) / 2;
		this->get_closest_aligned_addr(temp);
		if ((start_addr >= temp->start_addr) && (start_addr <= temp->end_addr))
			return 1;
		else
			return 0;
		break;
	}

	default: {
		return 0;
		break;
	}
	}

	return 1;
}

yamm_buffer* yamm_buffer::find_suitable_buffer(uint_64_t size,
		uint_32_t alignment, int alloc_mode) {

	if (alloc_mode == YAMM_BEST_FIT_RND)
		alloc_mode = YAMM_BEST_FIT;

	if (alloc_mode == YAMM_FIRST_FIT_RND)
		alloc_mode = YAMM_FIRST_FIT;

	yamm_buffer* temp = first_free;

	// Check if there are any free buffers inside and if this is a new allocation inside
	// an existing buffer create one
	if (temp == NULL) {
		if (first)
			return NULL;
		else {
			first_free = new yamm_buffer();
			first_free->start_addr = start_addr;
			first_free->size = this->size;
			first_free->end_addr = first_free->start_addr + first_free->size
					- 1;
			first_free->is_free = 1;
			first = first_free;
			delete temp;
			temp = first_free;
		}
	}

	// Size available inside the free buffer that we search for
	uint_64_t tsize = temp->size;

	switch (alloc_mode) {
	case YAMM_FIRST_FIT: {

		if (alignment != 1) {
			tsize = compute_size_with_align(alignment, temp);
		}

		// Look for the first free buffer that fits
		while ((temp->next_free) && (size > tsize)) {
			temp = temp->next_free;
			if (size <= temp->size)
				if (alignment != 1)
					tsize = compute_size_with_align(alignment, temp);
				else
					tsize = temp->size;
			else {
				tsize = temp->size;
			}
		}

		// If it fits
		if (tsize >= size)
			return temp;
		else
			return NULL;

		break;
	}

	case YAMM_BEST_FIT: {
		yamm_buffer* best_temp = NULL;
		int set = 0;

		if (compute_size_with_align(alignment, temp) >= size)
			best_temp = temp;

		// Traverse the whole memory looking for the smallest free buffer that fits.
		while (temp->next_free) {

			temp = temp->next_free;

			if (size <= temp->size) {
				if (best_temp == NULL)
					if (alignment != 1)
						tsize = compute_size_with_align(alignment, temp);
					else
						tsize = temp->size;
				else if ((alignment != 1) && (temp->size < best_temp->size))
					tsize = compute_size_with_align(alignment, temp);
				else
					tsize = temp->size;

				if (size <= tsize) {
					// The best_temp isn't yet set, take the first buffer that fits as reference
					if (!set) {
						best_temp = temp;
						set = 1;
					}
					if ((temp->size <= best_temp->size) && (size <= tsize))
						best_temp = temp;
				}
			}
		}

		if (best_temp)
			if (compute_size_with_align(alignment, best_temp) >= size)
				return best_temp;
			else
				return NULL;
		else
			return NULL;

		break;
	}

		// Same as YAMM_BEST_FIT but now we are looking for the largest free buffer
	case YAMM_UNIFORM_FIT: {
		yamm_buffer* uniform_temp = temp;
		bool found = 0;

		// Traverse the whole memory looking for the largest buffer that fits
		while (temp->next_free) {
			temp = temp->next_free;

			if (size <= temp->size) {
				if (!found)
					if (alignment != 1) {
						tsize = compute_size_with_align(alignment, temp);
						found = 1;
					} else {
						tsize = temp->size;
						found = 1;
					}
				else
					tsize = temp->size;

				if ((temp->size >= uniform_temp->size) && (size <= tsize))
					uniform_temp = temp;
			}
		}

		if (compute_size_with_align(alignment, uniform_temp) >= size)
			return uniform_temp;
		else
			return NULL;

		break;
	}

	case YAMM_RANDOM_FIT: {

		uint_32_t rnd_buffer = rand() % number_of_free_buffers;
		uint_32_t buffer_cnt = rnd_buffer;
		yamm_buffer* temp_prev;

		// Find the buffer randomized above
		while (buffer_cnt--) {
			temp = temp->next_free;
		}

		if (size <= temp->size) {
			if (alignment != 1)
				tsize = compute_size_with_align(alignment, temp);
			else
				tsize = temp->size;
		} else
			tsize = temp->size;

		if (tsize >= size)
			return temp;

		temp_prev = temp;

		// If we can't allocate in the random buffer we go around it for a suitable one
		while ((temp->next_free) || (temp_prev->prev_free)) {
			// Check buffer to the "right"
			if (temp->next_free) {
				temp = temp->next_free;

				if (size <= temp->size)
					if (alignment != 1)
						tsize = compute_size_with_align(alignment, temp);
					else
						tsize = temp->size;
				else
					tsize = temp->size;

				if (tsize >= size)
					return temp;
			}
			// Check buffer to the "left"
			if (temp_prev->prev_free) {
				temp_prev = temp_prev->prev_free;

				if (size <= temp_prev->size)
					if (alignment != 1)
						tsize = compute_size_with_align(alignment, temp_prev);
					else
						tsize = temp_prev->size;
				else
					tsize = temp_prev->size;

				if (tsize >= size)
					return temp_prev;
			}
		}

		return NULL;
		break;
	}

	default: {
		return NULL;
		break;
	}
	}
}

void yamm_buffer::add(yamm_buffer* new_buffer, yamm_buffer* container_buffer) {

	yamm_buffer* temp_prev = new yamm_buffer;

	// First, check if there is a displacement caused by allocation mode or alignment
	if (new_buffer->start_addr > container_buffer->start_addr) {
		temp_prev->start_addr = container_buffer->start_addr;
		temp_prev->size = new_buffer->start_addr - container_buffer->start_addr;
		temp_prev->end_addr = temp_prev->start_addr + temp_prev->size - 1;
		temp_prev->is_free = 1;
	}

	// Second, check if there remains a free buffer after the one we allocate (if you resize
	// or delete the old free buffer)
	if (new_buffer->end_addr < container_buffer->end_addr) {
		container_buffer->start_addr = new_buffer->end_addr + 1;
		container_buffer->size = container_buffer->end_addr
				- container_buffer->start_addr + 1;
	}

	if (temp_prev->is_free)
		link_in_list(temp_prev, new_buffer, container_buffer);
	else {
		// We didn't need another buffer
		delete temp_prev;
		link_in_list(NULL, new_buffer, container_buffer);
	}

}

void yamm_buffer::link_in_list(yamm_buffer* free_buffer_prev,
		yamm_buffer* new_buffer, yamm_buffer* free_buffer_next) {

	// We have 4 cases
	if (free_buffer_prev == NULL) {
		if (new_buffer->end_addr == free_buffer_next->end_addr) {// Case I:   [ new_buffer | free_buffer_next ]
			// The allocated buffer replaces the free buffer.
			new_buffer->prev = free_buffer_next->prev;
			new_buffer->next = free_buffer_next->next;

			// Any links that the free buffer had should be updated
			if (free_buffer_next->prev_free)
				free_buffer_next->prev_free->next_free =
						free_buffer_next->next_free;
			if (free_buffer_next->next_free)
				free_buffer_next->next_free->prev_free =
						free_buffer_next->prev_free;

			// Link the new buffer to the next buffer
			if (new_buffer->next)
				new_buffer->next->prev = new_buffer;

			// Link the new buffer to the previous buffer
			if (new_buffer->prev)
				new_buffer->prev->next = new_buffer;

			// If the start address of the new buffer matches the start address
			// of the memory map then move the first pointer to the new buffer
			if (new_buffer->start_addr == this->start_addr)
				first = new_buffer;

			// If the free buffer was the first_free buffer move the pointer
			// to the next free buffer
			if (first_free == free_buffer_next)
				first_free = free_buffer_next->next_free;

			// The free buffer was removed and replaced by an occupied one
			delete free_buffer_next;
			free_buffer_next = NULL;
			number_of_buffers++;
			number_of_free_buffers--;
		} else {// Case II:  [ free_buffer_prev | new_buffer | free_buffer_next ]
			new_buffer->prev = free_buffer_next->prev;
			new_buffer->next = free_buffer_next;

			if (new_buffer->prev)
				new_buffer->prev->next = new_buffer;

			free_buffer_next->prev = new_buffer;

			if (new_buffer->start_addr == this->start_addr)
				first = new_buffer;

			number_of_buffers++;
		}
	} else {
		if (new_buffer->end_addr == free_buffer_next->end_addr) {// Case III: [ free_buffer_prev | new_buffer ]
			// If the buffer's end address match the end address of the free buffer then the free buffer
			// should be removed and a new free buffer should be added in front of the new buffer
			free_buffer_prev->next_free = free_buffer_next->next_free;
			free_buffer_prev->prev_free = free_buffer_next->prev_free;
			free_buffer_prev->prev = free_buffer_next->prev;
			free_buffer_prev->next = new_buffer;

			// Fit the new buffer between the alignment/displacement buffer and the next buffer in the memory
			new_buffer->prev = free_buffer_prev;
			new_buffer->next = free_buffer_next->next;

			// The previous will be the new free buffer, only update the pointer of the next buffer
			// after the new one
			if (new_buffer->next)
				new_buffer->next->prev = new_buffer;

			//Update the pointers of the buffers linked to the new free buffer that we created
			if (free_buffer_prev->prev)
				free_buffer_prev->prev->next = free_buffer_prev;
			if (free_buffer_prev->prev_free)
				free_buffer_prev->prev_free->next_free = free_buffer_prev;
			if (free_buffer_prev->next_free)
				free_buffer_prev->next_free->prev_free = free_buffer_prev;

			// If the free buffer in which we allocated was the first free or the overall first buffer
			// then the new free buffer we created will take it's place
			if (first_free == free_buffer_next)
				first_free = free_buffer_prev;
			if (free_buffer_prev->start_addr == this->start_addr)
				first = free_buffer_prev;

			// We removed the old free buffer and replaced it with a new one, also we added
			// a new occupied buffer
			delete free_buffer_next;
			number_of_buffers++;
		} else {			// Case IV: [ new_buffer ]
			// Link it in the memory between the previous buffer and the allocated buffer
			free_buffer_prev->next_free = free_buffer_next;
			free_buffer_prev->prev_free = free_buffer_next->prev_free;
			free_buffer_prev->prev = free_buffer_next->prev;
			free_buffer_prev->next = new_buffer;

			// Link the allocated buffer between the alignment/displacement
			new_buffer->prev = free_buffer_prev;
			new_buffer->next = free_buffer_next;

			// Resize and link the free buffer
			free_buffer_next->prev = new_buffer;
			free_buffer_next->prev_free = free_buffer_prev;

			// Check and change the previous links accordingly
			if (free_buffer_prev->prev)
				free_buffer_prev->prev->next = free_buffer_prev;

			// Move the first_free and first pointers to the new free buffer if it's the case
			if (first_free == free_buffer_next)
				first_free = free_buffer_prev;
			if (free_buffer_prev->start_addr == this->start_addr)
				first = free_buffer_prev;

			// If the new free buffer we created has a buffer before it, update it's next pointer
			if (free_buffer_prev->prev_free)
				free_buffer_prev->prev_free->next_free = free_buffer_prev;

			// We added a new free buffer and the occupied one
			number_of_buffers++;
			number_of_free_buffers++;
		}
	}
}

void yamm_buffer::merge(yamm_buffer* free_n) {
	// Check if the previous buffer exists and it's free

	if ((free_n->prev) && (free_n->prev->is_free)) {
		// Update our buffer's size to include the previous one
		free_n->start_addr = free_n->prev->start_addr;
		free_n->size = free_n->end_addr - free_n->start_addr + 1;
		yamm_buffer* del = free_n->prev;
		// If there is a previous buffer to the new concatenated ones update the pointers
		if (free_n->prev->prev) {
			free_n->prev->prev->next = free_n;
			free_n->prev = free_n->prev->prev;
			if (free_n->prev->prev_free) {
				free_n->prev_free = free_n->prev->prev_free;
				free_n->prev_free->next_free = free_n;
			}
		} else {
			free_n->prev = NULL;
		}

		delete del;
		// We removed one free buffer by merging
		number_of_free_buffers--;
	}

	// Check if the next buffer exists and it's free
	if ((free_n->next) && (free_n->next->is_free)) {
		// Update our buffer's size to include the next one
		free_n->end_addr = free_n->next->end_addr;
		free_n->size = free_n->end_addr - free_n->start_addr + 1;

		yamm_buffer* del = free_n->next;

		// If there is a next buffer to the concatenated one update the pointers
		if (free_n->next->next) {
			free_n->next->next->prev = free_n;
			free_n->next = free_n->next->next;
			if (free_n->next->next_free) {
				free_n->next_free = free_n->next->next_free;
				free_n->next_free->prev_free = free_n;
			}
		} else {
			free_n->next = NULL;
		}

		delete del;
		// We removed one free buffer by merging
		number_of_free_buffers--;
	}

}

uint_64_t yamm_buffer::generate_rand64() {
	uint_64_t result = ((uint_64_t) rand()) << 32;
	result |= rand();
	return result;
}

#endif // __yamm_buffer_locals
