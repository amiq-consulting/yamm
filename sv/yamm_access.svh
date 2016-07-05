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

`ifndef __yamm_access
`define __yamm_access

/**
 * Class that models a basic access which requires a start address and a size
 * End address is computed automatically
 */
class yamm_access;
	
	// The starting address of the access, given by user
	yamm_addr_width start_addr;
	
	// The ending address of the access, computed automatically
	yamm_addr_width end_addr;
	
	// The size of the access, given by user
	yamm_size_width size;
	
	// Represents the direction of the access
	yamm_direction_e direction;
	
	/**
	 * Computes the end address of access for the given start address and size
	 */
	function void compute_end_addr();
		end_addr = start_addr+size-1;
	endfunction
endclass

`endif 
