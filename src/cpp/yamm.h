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

#ifndef __yamm_h
#define __yamm_h

#include <iostream>
#include <stdio.h>
#include <stdlib.h>
#include <queue>
#include <vector>
#include <string>

#include "yamm_buffer.h"
#include "yamm_access.h"

namespace yamm_ns {

#define YAMM_RANDOM_FIT 0
#define YAMM_FIRST_FIT_RND 1
#define YAMM_BEST_FIT_RND 2
#define YAMM_FIRST_FIT 3
#define YAMM_BEST_FIT 4
#define YAMM_UNIFORM_FIT 5

#define YAMM_EXIT_CODE 19420

typedef unsigned long long int uint_64_t;
typedef unsigned int uint_32_t;

/**
 * Top level class
 */
class yamm: public yamm_buffer {
	bool init_done;
	std::queue<yamm_buffer*> static_buffers_queue;

public:

	/**
	 * Default constructor.
	 * Everything is initialized to it's default value.
	 */
	yamm();

	/**
	 *  Function that builds the memory and allows usage.
	 *
	 *  @param size Total size of the memory
	 */
	void build(uint_64_t size);

	/** Getter for memory size
	 *	@return Memory's total size
	 */
	uint_64_t get_size() {
		return this->size;
	}

	/** Inserts ( if it cans) the buffer n in static mode.
	 *  If the buffer is in static mode it won't be affected by soft resets or deallocations.
	 *  The function should only be called from the top module (main)
	 *  @param n The buffer created by the user that will be inserted
	 */
	bool allocate_static(yamm_buffer* n);

	/**
	 *  Getter for the static buffers queue
	 */
	std::queue<yamm_buffer*> get_static_buffers();

	/**
	 * Standard destructor.
	 */
	~yamm();
};

}

#endif // __yamm_h
