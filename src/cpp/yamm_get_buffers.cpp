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

#ifndef __yamm_get_buffers
#define __yamm_get_buffers

#include "yamm.h"

using namespace yamm_ns;

yamm_buffer* yamm_buffer::get_buffer(uint_64_t start) {
	yamm_buffer* temp;
	temp = first;

	// Verifies if the address is valid
	if (start > this->end_addr || start < this->start_addr) {
		fprintf(stderr,
				"[YAMM_ERR] No such address: %llu !\n\t in %s at line %d\n",
				start, __FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	// Traverse the memory until the buffer containing that address is found
	while ((temp->next) && (temp->end_addr < start)) {
		temp = temp->next;
	}

	if (start >= temp->start_addr)
		if (temp->is_free == 0)
			return temp;
		else
			return NULL;
	else {
		fprintf(stderr,
				"[YAMM_ERR] Could not get buffer at : %llu !  !\n\t in %s at line %d\n",
				start, __FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}
}

yamm_buffer* yamm_buffer::internal_get_buffer(uint_64_t start) {
	yamm_buffer* temp;
	temp = first;

	// Verifies if the address is valid
	if (start > this->end_addr || start < this->start_addr) {
		fprintf(stderr,
				"[YAMM_ERR] No such address: %llu !\n\t in %s at line %d\n",
				start, __FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}

	// Traverse the memory until the buffer containing that address is found
	while ((temp->next) && (temp->end_addr < start)) {
		temp = temp->next;
	}

	if (start >= temp->start_addr)
		return temp;
	else {
		fprintf(stderr,
				"[YAMM_ERR] Could not get buffer at : %llu !\n\t in %s at line %d\n",
				start, __FILE__, __LINE__);
		exit(YAMM_EXIT_CODE);
	}
}

std::vector<yamm_buffer> yamm_buffer::get_buffers_in_range(uint_64_t start_addr,
		uint_64_t end_addr) {
	yamm_buffer* temp = internal_get_buffer(start_addr);
	std::vector<yamm_buffer> queue;

	if (end_addr < start_addr) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Invalid parameters: %llu %llu !\n\t in %s at line %d\n",
					start_addr, end_addr, __FILE__, __LINE__);
		return queue;
	}

	// Traverse the memory
	while ((temp) &&(temp->end_addr <= end_addr)) {
		if (temp->is_free == 0) {
			queue.push_back(temp);
		}
		temp = temp->next;
	}

	return queue;
}

std::vector<yamm_buffer> yamm_buffer::get_buffers_by_access(
		yamm_access* access) {

	uint_64_t start_addr = access->start_addr;
	uint_64_t end_addr = access->end_addr;

	return get_buffers_in_range(start_addr, end_addr);
}

std::vector<yamm_buffer> yamm_buffer::get_buffers_by_name(
		std::string name_to_search) {

	std::vector<yamm_buffer> result;

	if (name_to_search.empty()) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Invalid parameters: null or empty string !\n\t in %s at line %d\n",
					__FILE__, __LINE__);

		return result;
	}

	yamm_buffer* iterator = this->first;

	while (iterator) {

		if (iterator->get_name().compare(name_to_search) == 0)
			result.push_back(iterator);

		iterator = iterator->next;

	}

	return result;

}

std::queue<yamm_buffer*> yamm::get_static_buffers() {
	return this->static_buffers_queue;
}

#endif // __yamm_get_buffers

