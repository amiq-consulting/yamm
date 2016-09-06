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

#ifndef __yamm_access_test
#define __yamm_access_test

#include <iostream>
#include <stdio.h>

#include "yamm.h"

using namespace yamm_ns;

int main(int argc, char* argv[]) {

	yamm a;

	uint_64_t custom_size = 1024*1024*1024;

	a.build(custom_size);

	std::cout << "Start filling the memory\n";

	uint_64_t number_of_allocations = 1024;

	// Fill the memory by doing inserts by access

	yamm_access* acs = new yamm_access(0,1024*1024);

	for(uint_64_t i=0;i<number_of_allocations; ++i) {
		acs->start_addr = 1024*1024*i;
		a.insert_access(acs);

	}

	std::cout << "Usage statistics\n";
	std::cout << "Used: " << a.get_usage_statistics() << "%\tFrag: " << a.get_fragmentation() << "%\n";

	acs->start_addr = 0;
	acs->end_addr =custom_size - 1;

	// Get all buffers

	std::cout << "Getting all the buffers in the memory\n";

	std::vector<yamm_buffer> buffers = a.get_buffers_by_access(acs);


	std::cout << "Expected " << number_of_allocations << " \tFound:" << buffers.size() << "\n";

	delete acs;
	return 0;

}

#endif // __yamm_access_test
