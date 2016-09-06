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

#ifndef __yamm_set_up
#define __yamm_set_up

#include "yamm.h"

using namespace yamm_ns;

/** Standard constructor.
 *  Everything is initialized to its default value.
 */
yamm_buffer::yamm_buffer() {

	this->start_addr = 0;
	this->end_addr = 0;
	this->size = 0;

	this->granularity = 1;
	this->start_addr_alignment = 1;

	this->is_free = 0;
	this->is_static = 0;

	this->number_of_buffers = 0;
	this->number_of_free_buffers = 1;

	this->next_free = NULL;
	this->prev_free = NULL;
	this->next = NULL;
	this->prev = NULL;

	this->first_free = NULL;
	this->first = NULL;

	this->contents = NULL;
	this->name = "";

	this->disable_warnings = 0;
	this->disable_info = 0;

}

/** Size constructor.
 *  Creates a buffer of the desired size.
 *  Warning: start address is set to 0.
 */
yamm_buffer::yamm_buffer(uint_64_t size) {

	this->start_addr = 0;
	this->size = size;
	this->end_addr = this->size - 1;

	this->granularity = 1;
	this->start_addr_alignment = 1;

	this->is_free = 0;
	this->is_static = 0;

	this->number_of_buffers = 0;
	this->number_of_free_buffers = 1;

	this->next_free = NULL;
	this->prev_free = NULL;
	this->next = NULL;
	this->prev = NULL;

	this->first_free = NULL;
	this->first = NULL;

	this->contents = NULL;

	this->name = "";

	this->disable_warnings = 0;
	this->disable_info = 0;
}

/**
 *  Constructor that creates a copy of a given buffer
 */
yamm_buffer::yamm_buffer(yamm_buffer* n) {

	this->start_addr = n->start_addr;
	this->end_addr = n->end_addr;
	this->size = n->size;

	this->granularity = n->granularity;
	this->start_addr_alignment = n->start_addr_alignment;

	this->is_free = n->is_free;
	this->is_static = n->is_static;

	this->number_of_buffers = n->number_of_buffers;
	this->number_of_free_buffers = n->number_of_free_buffers;

	this->next_free = NULL;
	this->prev_free = NULL;
	this->next = NULL;
	this->prev = NULL;

	this->first_free = NULL;
	this->first = NULL;

	this->contents = NULL;

	this->name = n->name;

	if (this->granularity == 0)
		this->granularity = 1;

	if (this->start_addr_alignment == 0)
		this->start_addr_alignment = 1;

	this->disable_warnings = 0;
	this->disable_info = 0;

}

/**
 *  Start address + End address
 */
yamm_buffer::yamm_buffer(uint_64_t start, uint_64_t size) {

	this->start_addr = start;
	this->size = size;
	this->end_addr = start + size - 1;

	this->granularity = 1;
	this->start_addr_alignment = 1;

	this->is_free = 0;
	this->is_static = 0;

	this->number_of_buffers = 0;
	this->number_of_free_buffers = 1;

	this->next_free = NULL;
	this->prev_free = NULL;
	this->next = NULL;
	this->prev = NULL;

	this->first_free = NULL;
	this->first = NULL;

	this->contents = NULL;
	this->name = "";

	this->disable_warnings = 0;
	this->disable_info = 0;
}

/**
 *  Just the name
 */
yamm_buffer::yamm_buffer(std::string name) {

	this->start_addr = 0;
	this->end_addr = 0;
	this->size = 0;

	this->granularity = 1;
	this->start_addr_alignment = 1;

	this->is_free = 0;
	this->is_static = 0;

	this->number_of_buffers = 0;
	this->number_of_free_buffers = 1;

	this->next_free = NULL;
	this->prev_free = NULL;
	this->next = NULL;
	this->prev = NULL;

	this->first_free = NULL;
	this->first = NULL;

	this->contents = NULL;
	this->name = name;

	disable_warnings = 0;
	disable_info = 0;

}

/**
 *  Name + size
 */
yamm_buffer::yamm_buffer(uint_64_t size, std::string name) {

	this->start_addr = 0;
	this->end_addr = 0;
	this->size = size;

	this->granularity = 1;
	this->start_addr_alignment = 1;

	this->is_free = 0;
	this->is_static = 0;

	this->number_of_buffers = 0;
	this->number_of_free_buffers = 1;

	this->next_free = NULL;
	this->prev_free = NULL;
	this->next = NULL;
	this->prev = NULL;

	this->first_free = NULL;
	this->first = NULL;

	this->contents = NULL;
	this->name = name;

	disable_warnings = 0;
	disable_info = 0;

}

/**
 *  Standard destructor.
 */
yamm_buffer::~yamm_buffer() {

	this->disable_info = 1;
	this->disable_warnings = 1;

	if (this->contents) {
		this->reset_contents();
	}

	if (this->first) {

		yamm_buffer* it = this->first;
		yamm_buffer* del;

		while (it) {

			del = it;
			it = it->next;
			delete del;

		}

		this->first = NULL;
		this->first_free = NULL;
	}

	this->next = NULL;
	this->prev = NULL;
	this->next_free = NULL;
	this->prev_free = NULL;

}

/**
 * Note: to actually use the memory you need to build it by calling build method
 */
yamm::yamm() {

	this->first_free = NULL;
	this->first = NULL;

	this->init_done = 0;

}

/**
 *  Standard destructor.
 *  Deallocates all the memory and leaves all fields to NULL
 */
yamm::~yamm() {

	this->disable_info = 1;
	this->disable_warnings = 1;

	if (this->first) {
		this->hard_reset();
		delete this->first;

	}

	this->first = NULL;
	this->first_free = NULL;

}

/**
 * Function that builds the memory and allows us to start using it
 * @param size Total size of the memory
 */
void yamm::build(uint_64_t size) {
	if (this->init_done)
		fprintf(stderr,
				"[YAMM_WRN] Memory is already built!\n\t in %s at line %d\n",
				__FILE__, __LINE__);
	else {

		// The initial buffer
		yamm_buffer* mem = new yamm_buffer;

		this->first_free = mem;
		this->first = mem;

		this->init_done = 1;

		this->size = size;

		this->start_addr = 0;
		this->end_addr = this->start_addr + size - 1;

		mem->is_free = 1;
		mem->set_start_addr(0);
		mem->set_size(size);

	}
}

void yamm_buffer::hard_reset() {

	yamm_buffer* it = this->first;
	yamm_buffer* del;

	it = this->first;

	bool warnings = this->disable_warnings;
	bool infos = this->disable_info;

	this->disable_warnings = 1;
	this->disable_info = 1;

	while (it) {

		del = it;
		it = it->next;

		if (del->first) {
			del->hard_reset();
		}

		del->is_static = 0;
		del->disable_warnings = 1;
		del->disable_info = 1;

		if (!del->is_free) {

			if (it && it->is_free)
				it = it->next;

			deallocate(del);

		}

	}

	this->disable_warnings = warnings;
	this->disable_info = infos;

}

void yamm_buffer::soft_reset() {

	yamm_buffer* it = this->first;
	yamm_buffer* del;

	bool warnings = this->disable_warnings;
	bool infos = this->disable_info;

	this->disable_warnings = 1;
	this->disable_info = 1;

	while (it) {

		del = it;
		it = it->next;

		if (del->first) {
			del->soft_reset();
		}

		if (!del->is_free && !del->is_static) {

			if (it && it->is_free)
				it = it->next;

			deallocate(del);

		}

	}

	this->disable_warnings = warnings;
	this->disable_info = infos;

}

#endif // __yamm_set_up

