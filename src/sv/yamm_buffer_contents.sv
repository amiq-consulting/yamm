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

`ifndef __yamm_buffer_contents
`define __yamm_buffer_contents

function void yamm_buffer::set_contents(byte data[], bit warning = 1);

	// Take the argument and save it inside the local variable
	contents = data;

	// If the warning bit is not deactivated and the size of the data doesn't match the
	// size of the buffer a warning is displayed
	if((data.size() != size) && (warning == 1))
		`ifdef YAMM_USE_UVM
		`uvm_warning("YAMM_WRN", $sformatf("The size of contents doesn't match the size of buffer! Size of buffer: %0h ; Size of contents: %0h", this.size, data.size()));
		`else
	$warning("[YAMM_WRN] The size of contents doesn't match the size of buffer! Size of buffer: %0h ; Size of contents: %0h", this.size, data.size());
		`endif
endfunction

function yamm_byte_s yamm_buffer::get_contents();

	// If there are no contents stored use generate_contents()
	if(contents.size() == 0)
		generate_contents();

	return contents;

endfunction

function void yamm_buffer::generate_contents();

	// Initialize the variable with the size of the buffer
	contents = new[size];

	// Store a random character in each byte
	foreach (contents[i])
		contents[i] = $urandom();

endfunction

function bit yamm_buffer::compare_contents(yamm_byte_s cmp_data);

	if(contents.size() != cmp_data.size())
		return 0;

	foreach(contents[i])
		if(contents[i] != cmp_data[i])
			return 0;

	return 1;

endfunction

function void yamm_buffer::reset_contents();

	contents.delete();

endfunction

`endif
