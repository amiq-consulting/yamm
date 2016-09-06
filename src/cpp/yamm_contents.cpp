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

#ifndef __yamm_contents
#define __yamm_contents

#include "yamm.h"
#include <string.h>

using namespace yamm_ns;

bool yamm_buffer::set_contents(char* new_payload, uint_64_t size) {
	// Input check
	if (!new_payload) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] Payload is null!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
		return 0;
	}

	// If we previously had anything we just wipe it
	if (this->contents)
		delete this->contents;

	contents = new char[this->size];

	if (size > this->size) {
		if (!disable_warnings)
			fprintf(stderr,
					"[YAMM_WRN] You allocated more content than the buffer's size!\n\t in %s at line %d\n",
					__FILE__, __LINE__);
	}

	// Copy as much as we can from the new payload into the buffer
	memcpy((this->contents), new_payload, std::min(this->size,size));

	return 1;
}

void yamm_buffer::reset_contents() {

	if (this->contents) {
		delete (this->contents);
		this->contents = NULL;
	}

}

char* yamm_buffer::get_contents() {
	if ((this->contents) == NULL)
		generate_random_contents();

	return (this->contents);
}

bool yamm_buffer::generate_random_contents() {
	int size = this->size;
	this->contents = new char[size];
	int i;
	for (i = 0; i < size; i++) {
		(this->contents)[i] = rand() % 256;
	}

	return 1;
}
bool yamm_buffer::compare_contents(char* reference, uint_64_t ref_size) {

	if(!reference && !(this->contents))
		return 1;

	if(!reference)
		return 0;

	if(!(this->contents))
		return 0;

	for (uint_64_t i = 0; i < std::min(ref_size, this->size); ++i)
		if (this->contents[i] != reference[i])
			return 0;

	return 1;
}

#endif //  __yamm_contents

