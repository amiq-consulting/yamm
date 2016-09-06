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

#include <iostream>
#include <stdio.h>

#include "yamm.h"

using namespace yamm_ns;

int main(int argc, char* argv[]) {

	yamm my_memory;
	my_memory.build(3 * 1024);

	yamm_buffer* st = new yamm_buffer(512);
	my_memory.allocate_static(st);

	yamm_buffer* x1 = my_memory.allocate_by_size(512, 4);
	my_memory.allocate_by_size(512, 4);
	my_memory.allocate_by_size(512, 4);
	my_memory.allocate_by_size(512, 4);
	my_memory.allocate_by_size(512, 4);

	yamm_buffer* x2 = x1->allocate_by_size(64, 5);
	yamm_buffer* x3 = st->allocate_by_size(64, 5);

	x2->allocate_by_size(32, 5);
	x3->allocate_by_size(32, 5);

	std::cout << "Memory map: \n\n";
	std::cout << my_memory.sprint(1, 0) << "\n\n\n";

	my_memory.soft_reset();

	std::cout << "Memory after a soft reset: \n\n";
	std::cout << my_memory.sprint(1, 0) << "\n\n\n";

}

#endif // __yamm_recursion_test
