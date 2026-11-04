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

#ifndef __yamm_recursion_test
#define __yamm_recursion_test

#include <stdio.h>

#include "yamm.h"
#include "test_utils.h"

using namespace yamm_ns;

int main(int argc, char* argv[]) {

	yamm my_memory;
	my_memory.build(3 * 1024);

	yamm_buffer* st = new yamm_buffer(512);
	check(my_memory.allocate_static(st), "Failed to allocate static buffer");

	yamm_buffer* x1 = my_memory.allocate_by_size(512, 4);
	check(x1 != NULL, "Failed to allocate x1");
	check(my_memory.allocate_by_size(512, 4) != NULL, "Failed to allocate top-level buffer");
	check(my_memory.allocate_by_size(512, 4) != NULL, "Failed to allocate top-level buffer");
	check(my_memory.allocate_by_size(512, 4) != NULL, "Failed to allocate top-level buffer");
	check(my_memory.allocate_by_size(512, 4) != NULL, "Failed to allocate top-level buffer");

	yamm_buffer* x2 = (x1 != NULL) ? x1->allocate_by_size(64, 5) : NULL;
	check(x2 != NULL, "Failed to allocate x2 inside x1");
	yamm_buffer* x3 = (st != NULL) ? st->allocate_by_size(64, 5) : NULL;
	check(x3 != NULL, "Failed to allocate x3 inside static buffer");

	check((x2 != NULL) && x2->allocate_by_size(32, 5) != NULL, "Failed to allocate inside x2");
	check((x3 != NULL) && x3->allocate_by_size(32, 5) != NULL, "Failed to allocate inside x3");

	check(my_memory.check_address_space_consistency(), "Inconsistent after allocations");

	std::cout << "Memory map: \n\n";
	std::cout << my_memory.sprint(1, 0) << "\n\n\n";

	my_memory.soft_reset();

	check(my_memory.check_address_space_consistency(), "Inconsistent after soft reset");

	std::cout << "Memory after a soft reset: \n\n";
	std::cout << my_memory.sprint(1, 0) << "\n\n\n";

	if (g_failures == 0) {
		std::cout << "All recursion cases passed\n";
		return 0;
	} else {
		std::cerr << g_failures << " check(s) FAILED\n";
		return 1;
	}
}

#endif // __yamm_recursion_test
