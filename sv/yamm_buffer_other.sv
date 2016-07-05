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

`ifndef __yamm_buffer_other
`define __yamm_buffer_other

function bit yamm_buffer::check_address_space_consistency();
	yamm_buffer temp = first;

	while(temp)
	begin
		if(temp.next)
		begin
			if(!(temp.next._start_addr == (temp._end_addr+1)))
			begin
				//$warning("Consistency problem!");
				//$display("Crt end addr: %0d Next start addr: %0d", temp._end_addr, temp.next._start_addr);
				return 0;
			end
			if((temp._end_addr - temp._start_addr + 1) != (temp._size))
			begin
				//$warning("Consistency problem!");
				//$display("Size does not match!");
				//$display("Crt end addr: %0d Next start add: %0d", temp._end_addr, temp.next._start_addr);
				return 0;
			end
			if(temp._size < 1)
			begin
				//$warning("Consistency problem!");
				//$display("Size < 1");
				//$display("Crt end addr: %0d Next start addr: %0d", temp._end_addr, temp._start_addr);
				return 0;
			end
			if(temp.free && temp.next.free)
			begin
				//$warning("Consistency problem!");
				//$display("Crt end addr: %0d Next start addr: %0d", temp._end_addr, temp.next._start_addr);
				//$display("Crt.free: %0d Crt._size: %0d ; Next.free: %0d Next._size %0d", temp.free, temp._size, temp.next.free, temp.next._size);
				//$display("2 free buffers aligned!");
				return 0;
			end
			if(temp.first)
			begin
				if(temp.check_address_space_consistency()==0)
					return 0;
			end
		end
		temp = temp.next;
	end
	return 1;
endfunction

function void yamm_buffer::set_name(string name);

	this.name = name;

endfunction

function bit yamm_buffer::access_overlaps(yamm_access access);
	
	// Use the get_buffer function to get a handle to the buffer
	// specified by the access parameters
	yamm_buffer temp = get_buffer(access.start_addr);
	access.compute_end_addr();

	// If there is a occupied buffer between the start and
	// end address of the access return 1 (buffer overlap)
	while((temp) && (temp._start_addr <= access.end_addr))
	begin
		if(temp.free == 0)
			return 1;
		temp = temp.next;
	end

	return 0;

endfunction

function yamm_addr_width yamm_buffer::end_addr();

	return this._end_addr;

endfunction

//function returns 0 if buffer start_addr is not aligned according to start_addr_alignement
function bit yamm_buffer::check_alignment();
	
	// Don't check free buffers
	if(free == 1)
		return 1;
	
	// Check alignment using modulo property
	if(_start_addr % _start_addr_alignment != 0)
	begin
		return 0;
	end

	return 1;

endfunction


`endif
