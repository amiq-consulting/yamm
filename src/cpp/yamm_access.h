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

#ifndef __yamm_access_h
#define __yamm_access_h

namespace yamm_ns {

#ifndef uint_64_t
typedef unsigned long long int uint_64_t;
#endif

/**
 * Class that models a basic access which requires a start address and a size
 * End address is computed automatically
 */
class yamm_access {
public:

	/** Start address of the access. Given by user */
	uint_64_t start_addr;
	/** End address of the access. Computed automatically  */
	uint_64_t end_addr;
	/** Size of the access. Given by user */
	uint_64_t size;

	/**
	 *	Access constructor.
	 *	Creates an access with the size and start address given by user.
	 *
	 *	@param start_addr start address of the access
	 *	@param size Size of the access
	 */
	yamm_access(uint_64_t start_addr, uint_64_t size) {
		this->start_addr = start_addr;
		this->size = size;
		this->end_addr = this->compute_end_addr();
	}

protected:
	/**
	 * 	Function that computes the end address of the access
	 * 	@return the access' end address
	 */
	uint_64_t compute_end_addr() {
		return this->start_addr + this->size - 1;
	}

};

}
#endif // __yamm_access_h
