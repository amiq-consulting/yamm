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

#ifndef __yamm_debug
#define __yamm_debug

#include "yamm.h"

using namespace yamm_ns;

#define YAMM_KB 1024
#define YAMM_MB (1024*1024)
#define YAMM_GB (1024*1024*1024)

void yamm_buffer::write_to_file(std::string filename) {

	FILE* fp = fopen(filename.c_str(), "w");

	if (!fp) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Could not open file!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return;
	}

	fprintf(fp,"%s\n",sprint(0,1).c_str());
}

std::string yamm_buffer::print_size() {

	char aux[100];

	switch (this->size) {
	case 1 ... (YAMM_KB - 1): {
		sprintf(aux, "%03llu :", this->size);
		break;
	}
	case (YAMM_KB) ... (YAMM_MB - 1): {
		sprintf(aux, "%03lluK:", this->size / YAMM_KB);
		break;
	}
	case (YAMM_MB) ... (YAMM_GB - 1): {
		sprintf(aux, "%03lluM:", this->size / YAMM_MB);
		break;
	}
	default:
		sprintf(aux, "%03lluG:", this->size / YAMM_GB);

	}

	std::string rez(aux);
	return rez;

}

void yamm_buffer::print(FILE* fp) {

	if (!fp) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] File pointer is null!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return;
	}

	yamm_buffer* temp;
	temp = first;
	uint_32_t i = 0;
	std::cout << "\n";
	while (temp) {

		fprintf(fp, "@%08llx:@%08llx:%08llx", temp->start_addr, temp->end_addr,
				temp->size);

		if (temp->is_free)
			fprintf(fp, " FREE");
		else
			fprintf(fp, " USED");

		if (temp->is_static)
			fprintf(fp, " STATIC");
		else
			fprintf(fp, " NORMAL");

		fprintf(fp, "\n");
		i++;
		temp = temp->next;
	}
}

std::string yamm_buffer::sprint(bool recursive = 0, int indentation = 0) {

	std::string indent = "    ";

	char aux[100] = { 0 };

	sprintf(aux, "@%08llx:@%08llx:%08llx", this->start_addr, this->end_addr,
			this->size);

	if (this->is_free)
		sprintf(aux, "%s FREE", aux);
	else
		sprintf(aux, "%s USED", aux);

	if (this->is_static)
		sprintf(aux, "%s STATIC", aux);
	else
		sprintf(aux, "%s NORMAL", aux);

	std::string rez(aux);

	if (recursive == 1 && this->first) {

		yamm_buffer* iterator = this->first;
		for (int i = 0; i < indentation; ++i)
			indent = indent + "    ";

		while (iterator) {
			std::string child_info = "\n" + indent
					+ iterator->sprint(1, indentation + 1);
			rez = rez + child_info;
			iterator = iterator->next;
		}
	}

	return rez;
}

void yamm_buffer::print_free(FILE* fp) {

	if (!fp) {
		if (!disable_warnings)
			fprintf(stderr, "File pointer is null!\n\t in %s at line %d\n",
			__FILE__, __LINE__);
		return;
	}

	yamm_buffer* temp;
	temp = first_free;
	uint_32_t i = 0;
	std::cout << "\n";
	while (temp) {
		std::cout << i << ". Size:" << temp->size << " Start_addr:"
				<< temp->start_addr << " End_addr:" << temp->end_addr << "\n";

		i++;
		temp = temp->next_free;

	}

}

double yamm_buffer::get_fragmentation() {
	yamm_buffer* temp;
	temp = first;
	double free_buffers = 0;
	double buffers = 0;
	double frag;
	while (temp) {
		if (temp->is_free)
			free_buffers++;
		buffers++;
		temp = temp->next;
	}
	frag = free_buffers / buffers * 100;
	return frag;
}

double yamm_buffer::get_usage_statistics() {
	yamm_buffer* temp;
	temp = first;
	uint_64_t size_free_buffers = 0;
	uint_64_t mem_size = 0;
	double usage_stats;

	while (temp) {
		if (temp->is_free)
			size_free_buffers = size_free_buffers + temp->size;
		mem_size = mem_size + temp->size;
		temp = temp->next;
	}

	usage_stats = 100 - (1.0 * size_free_buffers / mem_size * 100);
	return usage_stats;

}

bool yamm_buffer::check_address_space_consistency() {
	yamm_buffer* temp;
	temp = first;
	while (temp) {

		if (temp->next) {

			// Continuity
			if (!(temp->next->start_addr == temp->end_addr + 1)) {
				fprintf(stderr,
						"Current end address: %llu ; Next start address: %llu !\n\t in %s at line %d\n",
						temp->end_addr, temp->next->start_addr, __FILE__,
						__LINE__);
				exit(YAMM_EXIT_CODE);
			}

			// Free buffers are merged
			if ((temp->is_free) && (temp->next->is_free)) {

				fprintf(stderr,
						"[YAMM_ERR] 2 Free buffers aligned: [%llu,%llu] and [%llu, %llu] !\n\t in %s at line %d\n",
						temp->start_addr, temp->end_addr,
						temp->next->start_addr, temp->next->end_addr, __FILE__,
						__LINE__);
				exit(YAMM_EXIT_CODE);
			}

		}

		// Correct size
		if ((temp->end_addr - temp->start_addr + 1) != (temp->size)) {

			fprintf(stderr,
					"[YAMM_ERR] Size mismatch: %llu for [%llu, %llu] !\n\t in %s at line %d\n",
					temp->size, temp->start_addr, temp->end_addr, __FILE__,
					__LINE__);
			exit(YAMM_EXIT_CODE);

		}

		// Strictly positive size
		if (temp->size < 1) {

			fprintf(stderr,
					"[YAMM_ERR] Size mismatch: %llu for [%llu, %llu] !\n\t in %s at line %d\n",
					temp->size, temp->start_addr, temp->end_addr, __FILE__,
					__LINE__);
			exit(YAMM_EXIT_CODE);
		}

		// If current buffer contains other buffers
		if (temp->first) {

			// Check recursively
			temp->first->check_address_space_consistency();

			// Check that the first child starts at buffer start address
			if (temp->first->start_addr != temp->start_addr) {
				fprintf(stderr,
						"[YAMM_ERR] Current buffer start: %llu, first contained buffer: %llu !\n\t in %s at line %d\n",
						temp->start_addr, temp->first->start_addr, __FILE__,
						__LINE__);
				exit(YAMM_EXIT_CODE);
			}

			// Traverse the children list
			yamm_buffer* it = temp->first;

			while (it->next)
				it = it->next;

			// Compare end addresses
			if (it->end_addr != temp->end_addr) {
				fprintf(stderr,
						"[YAMM_ERR] Current buffer end addr: %llu, last contained buffer: %llu !\n\t in %s at line %d\n",
						temp->end_addr, temp->first->end_addr, __FILE__,
						__LINE__);
				exit(YAMM_EXIT_CODE);
			}

		}

		temp = temp->next;
	}
	return 1;
}

/** Function that checks if any buffers are occupied in the given access range
 *  @param access An access
 *  @return True if we have consistency problems , False otherwise
 */
bool yamm_buffer::access_overlaps(yamm_access* access) {
	yamm_buffer* temp = internal_get_buffer(access->start_addr);

	// Search for occupied buffers in the range specified by access
	while ((temp) &&(temp->start_addr < access->end_addr)) {
		if (temp->is_free == 0)
			return 1;
		temp = temp->next;
	}

	return 0;
}

#endif // __yamm_debug
