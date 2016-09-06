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

#ifndef __yamm_benchmark_test
#define __yamm_benchmark_test

#include <iostream>
#include <stdio.h>
#include <time.h>
#include <ctime>
#include <math.h>

#include "yamm.h"

using namespace yamm_ns;

int main(int argc, char* argv[]) {

	yamm a;

	uint_64_t custom_size = 1024 * 1024 * 1024;

	int initial_allocations = 5000;
	int initial_allocations_size = 65 * 1024;

	long long int number_of_allocations = 20000;
	int size_for_each_mode = 95 * 1024;

	int number_of_successful_allocations = 0;

	int seed = time(NULL);
	srand(seed);

	a.build(custom_size);

	std::cout << "\n";

	for (int mode = 0; mode < 6; ++mode) {

		const clock_t begin_time = clock();

		size_for_each_mode = 95 * 1024;

		// Initial uniform allocations to fragment the memory
		for (int i = 0; i < initial_allocations; ++i)
			if (!a.allocate_by_size(initial_allocations_size,
			YAMM_UNIFORM_FIT)) {
				std::cout << "INITIAL FAIL!";
				break;
			} else
				number_of_successful_allocations++;

		// Allocations by mode
		for (int i = 0; i < number_of_allocations; ++i) {
			if (!a.allocate_by_size(size_for_each_mode, mode)) {
				if (size_for_each_mode > 1)
					size_for_each_mode /= 2;
			} else
				number_of_successful_allocations++;

		}

		std::cout << "Stats after all allocations: \n";
		std::cout << "Used: " << a.get_usage_statistics()
				<< "%\tFragmentation: " << a.get_fragmentation() << "%\n";

		// Deallocing all buffers
		a.soft_reset();

		// Stats for every mode

		std::cout << "Stats after all deallocations: \n";
		std::cout << "Used: " << a.get_usage_statistics()
				<< "%\tFragmentation: " << a.get_fragmentation() << "%\n";

		std::cout << "Number of successful allocations: "
				<< number_of_successful_allocations << "\n";

		std::cout << "For allocation mode " << mode << " "
				<< float(clock() - begin_time) / CLOCKS_PER_SEC
				<< " seconds.\n";

		if (!a.check_address_space_consistency()) {
			std::cout << "\n\n\nConsistency FAIL!\n\n\n";
			exit(YAMM_EXIT_CODE);
		}

		std::cout << "\n\n";

		// Reset counters and memory
		number_of_successful_allocations = 0;

	}

	return 0;

}

#endif // __yamm_benchmark_test
