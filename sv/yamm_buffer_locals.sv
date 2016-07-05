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

`ifndef __yamm_buffer_locals
`define __yamm_buffer_locals

function yamm_addr_width yamm_buffer::get_aligned_addr(int alignment, yamm_buffer temp);

	// Compute the displacement needed
	int align = (alignment - temp._start_addr % alignment);
	align = align %alignment;

	// If the buffer displacement start addr fits in the buffer return
	// the new start address
	if((temp._start_addr + align) <= temp._end_addr)
		return temp._start_addr + align;

	// If it doesn't, return _end_addr+1. Usable for error checking
	return temp._end_addr+1;

endfunction

function yamm_size_width yamm_buffer::compute_size_with_gran(yamm_size_width size, int granularity);

	return size + (granularity - size % granularity) % granularity;

endfunction

function yamm_size_width yamm_buffer::compute_size_with_align(int alignment, yamm_buffer temp);

	return temp._end_addr - get_aligned_addr(alignment, temp) + 1;

endfunction

function void yamm_buffer::get_closest_aligned_addr(yamm_buffer temp);
// TODO: If you get buffers out of boundaries the problem is here

	// Compute the displacement needed for alignment
	int negalign = (_start_addr % _start_addr_alignment) % _start_addr_alignment;
	int posalign = (_start_addr_alignment - _start_addr % _start_addr_alignment) % _start_addr_alignment;

	// Apply the lower one of the two
	if((negalign <= posalign) && (_start_addr - negalign >= temp._start_addr))
		_start_addr = _start_addr - negalign;
	else
		_start_addr = _start_addr + posalign;


endfunction

function bit yamm_buffer::compute_start_addr(yamm_buffer temp, yamm_allocation_mode_e alloc_mode);

	// The start_addr for BEST_FIT and FIRST_FIT follows the same rule
	// As close to the start_addr as alignment allows
	if(alloc_mode == BEST_FIT)
		alloc_mode = FIRST_FIT;

	if((alloc_mode == FIRST_FIT_RND) || (alloc_mode == BEST_FIT_RND))
		alloc_mode = RANDOM_FIT;

	case(alloc_mode)
		FIRST_FIT: // same as BEST_FIT
		begin
			_start_addr = get_aligned_addr(_start_addr_alignment, temp);
			if(_start_addr > temp.end_addr())
				return 0;
			else
				return 1;
		end

		RANDOM_FIT: begin

			// Randomize the start_addr with the constrains of being inside
			// the buffer boundaries and respecting the alignment
			if (!randomize(_start_addr) with {
						_start_addr >= temp._start_addr;
						_start_addr <= temp.end_addr()-_size + 1;
						_start_addr % _start_addr_alignment == 0;
					}) begin
				$error($sformatf("Can't randomize!"));
				return 0;
			end

			return 1;

		end

//      FIRST_FIT_RND:
//      begin
//          // Same as RANDOM_FIT
//          if (!randomize(_start_addr) with {
//                      _start_addr >= temp._start_addr;
//                      _start_addr <= temp.end_addr()-_size + 1;
//                      _start_addr % _start_addr_alignment == 0;
//                  })
//              $error($sformatf("Can't randomize!"));
//
//      end
//
//      BEST_FIT_RND:
//      begin
//          // Same
//          if (!randomize(_start_addr) with {
//                      _start_addr >= temp._start_addr;
//                      _start_addr <= temp.end_addr()-_size + 1;
//                      _start_addr % _start_addr_alignment == 0;
//                  })
//              $error($sformatf("Can't randomize!"));
//
//      end

		UNIFORM_FIT: begin

			_start_addr = temp._start_addr + (temp._size - _size)/2;
			this.get_closest_aligned_addr(temp);
			if((_start_addr >= temp._start_addr) && (_start_addr <= temp.end_addr()))
				return 1;
			else
				return 0;
		end

		default:
			return 0;

	endcase
endfunction

//Function used to find a suitable free buffer for allocation
function yamm_buffer yamm_buffer::find_suitable_buffer(yamm_size_width size, int alignment, yamm_allocation_mode_e alloc_mode);

	// Take a handle to the first free buffer in memory
	yamm_buffer temp = first_free;
	yamm_size_width tsize;

	// Check if there are any free buffers inside and if this is a new allocation inside
	// an existing buffer create one
	if(temp==null) begin
		if(first)
			return null;
		else begin
			first_free = new();
			first_free._start_addr = _start_addr;
			first_free._size = _size;
			first_free._end_addr = first_free._start_addr + first_free._size - 1;
			first_free.free = 1;
			first = first_free;
			temp = first_free;
		end
	end

	tsize = temp._size;

	// Same rule for finding free buffers
	if(alloc_mode == FIRST_FIT_RND)
		alloc_mode = FIRST_FIT;

	// Same rule for finding free buffers
	if(alloc_mode == BEST_FIT_RND)
		alloc_mode = BEST_FIT;

	case(alloc_mode)
		FIRST_FIT: begin

			if(alignment != 1)
				tsize = compute_size_with_align(alignment, temp);

			// Look for the first free buffer that fits
			while((temp.next_free) && (size > tsize)) begin
				temp = temp.next_free;
				if(size <= temp._size)
					if(alignment != 1)
						tsize = compute_size_with_align(alignment, temp);
					else
						tsize = temp._size;
				else
					tsize = temp._size;
			end

			// If a suitable buffer is found return it
			if(tsize >= size)
				return temp;
			else
				return null;

		end

		BEST_FIT: begin
			yamm_buffer best_temp;
			int set = 0;

			if(compute_size_with_align(alignment, temp) >= size)
				best_temp = temp;

			// Traverse the whole mem. looking for the smallest free buffer that fits.
			while(temp.next_free) begin
				temp = temp.next_free;

				if(size <= temp._size) begin
					if(!best_temp)
						if(alignment != 1)
							tsize = compute_size_with_align(alignment, temp);
						else
							tsize = temp._size;
					else
						if((alignment != 1) && (temp._size <= best_temp._size))
							tsize = compute_size_with_align(alignment, temp);
						else
							tsize = temp._size;

					if(size <= tsize) begin
						// The best_temp isn't yet set, take the first buffer that fits as reference
						if(!set) begin
							best_temp = temp;
							set = 1;
						end
						if((temp._size <= best_temp._size) && (size <= tsize))
							best_temp = temp;
					end
				end

			end

			if(best_temp)
				if(compute_size_with_align(alignment, best_temp) >= size)
					return best_temp;
				else
					return null;
			else
				return null;

		end

		UNIFORM_FIT: begin

			yamm_buffer uniform_temp = temp;
			bit found = 0;

			// Traverse the whole mem looking for the largest buffer that fits
			while(temp.next_free) begin
				temp = temp.next_free;

				if(size <= temp._size) begin
					if(!found)
						if(alignment != 1) begin
							tsize = compute_size_with_align(alignment, temp);
							found = 1;
						end
						else begin
							tsize = temp._size;
							found = 1;
						end
					else
						tsize = temp._size;

					if((temp._size >= uniform_temp._size) && (size <= tsize)) begin
						uniform_temp = temp;
					end
				end

			end

			if(compute_size_with_align(alignment, uniform_temp) >= size)
				return uniform_temp;
			else
				return null;

		end

		RANDOM_FIT: begin

			int rnd_buffer = $urandom_range(number_of_free_buffers-1, 0);
			int buffer_cnt = rnd_buffer;
			yamm_buffer temp_prev;

			// Find the buffer randomized above
			while(buffer_cnt--)
			begin
				//if(temp.next_free == null)
				//  print_stats();
				temp = temp.next_free;
			end

			if(size <= temp._size)
				if(alignment != 1)
					tsize = compute_size_with_align(alignment, temp);
				else
					tsize = temp._size;
			else
				tsize = temp._size;

			if(tsize >= size)
				return temp;

			temp_prev = temp;

			// Search the memory for a suitable free buffer
			while((temp.next_free) || (temp_prev.prev_free)) begin

				if(temp.next_free) begin
					temp = temp.next_free;

					if(size <= temp._size)
						if(alignment != 1)
							tsize = compute_size_with_align(alignment, temp);
						else
							tsize = temp._size;
					else
						tsize = temp._size;

					if(tsize >= size)
						return temp;
				end

				if(temp_prev.prev_free) begin
					temp_prev = temp_prev.prev_free;

					if(size <= temp_prev._size)
						if(alignment != 1)
							tsize = compute_size_with_align(alignment, temp_prev);
						else
							tsize = temp_prev._size;
					else
						tsize = temp_prev._size;

					if(tsize >= size)
						return temp_prev;
				end
			end

			return null;

		end
		default: begin
			//$display("No\Wrong allocation mode.");
			return null;
		end
	endcase
endfunction

// Function used to insert buffer n in the FREE buffer temp
function void yamm_buffer::add(yamm_buffer n, yamm_buffer temp);

	yamm_buffer temp_prev = new;

// First, check if there is a displacement caused by allocation mode or alignment
	if(n._start_addr > temp._start_addr) begin
		temp_prev._start_addr = temp._start_addr;
		temp_prev._size = n._start_addr-temp._start_addr;
		temp_prev._end_addr = temp_prev._start_addr + temp_prev._size-1;
		temp_prev.free = 1;
	end

// Second, check if there remains a free buffer after the one we allocate (if you resize or delete the old free buffer)
	if(n._end_addr < temp._end_addr) begin
		temp._start_addr = n._end_addr+1;
		temp._size = temp._end_addr - temp._start_addr + 1;
	end

	if(temp_prev.free)
		link_in_list(temp_prev, n, temp);
	else
		link_in_list(null, n, temp);
endfunction

function void  yamm_buffer::link_in_list(yamm_buffer temp_prev, yamm_buffer n, yamm_buffer temp);

	// In this case the new buffer's start addr is equal to the free buffer's one
	// The new buffer comes between the previous buffer and the resized free one
	// or the new buffer should completely replace the free one if the sizes match
	if(temp_prev == null) begin

		// First case: The new buffer's size match the free buffer's size
		if(n._end_addr == temp._end_addr) begin
			// The allocated buffer replaces the free buffer.
			n.prev = temp.prev;
			n.next = temp.next;

			// Any links that the free buffer had should be updated
			if(temp.prev_free)
				temp.prev_free.next_free = temp.next_free;
			if(temp.next_free)
				temp.next_free.prev_free = temp.prev_free;

			// Link the new buffer to the next buffer
			if(n.next)
				n.next.prev = n;

			// Link the new buffer to the previous buffer
			if(n.prev)
				n.prev.next = n;

			// If the start address of the new buffer matches the start address
			// of the memory map then move the first pointer to the new buffer
			if(n._start_addr == this._start_addr)
				first = n;

			// If the free buffer was the first_free buffer move the pointer to
			// the next free buffer
			if(first_free == temp)
				first_free = temp.next_free;

			// The free buffer was removed and replaced by an occupied one
			number_of_buffers++;
			number_of_free_buffers--;
		end
		else begin
			// Link the allocated buffer in mem
			n.prev = temp.prev;
			n.next = temp;

			if(n.prev)
				n.prev.next = n;

			temp.prev = n;

			if(n._start_addr == this._start_addr)
				first = n;

			number_of_buffers++;
		end
	end

	// Second case: the new buffer is smaller than the free buffer
	else begin

		// If the buffer's end address match the end address of the free buffer then the free buffer
		// should be removed and a new free buffer should be added in front of the new buffer
		if(n._end_addr == temp._end_addr) begin
			// Link the buffer between the previous buffer and the allocated buffer
			temp_prev.next_free = temp.next_free;
			temp_prev.prev_free = temp.prev_free;
			temp_prev.prev = temp.prev;
			temp_prev.next = n;

			// Fit the new buffer between the alignment/displacement buffer and the next buffer in mem
			n.prev = temp_prev;
			n.next = temp.next;

			// The previous will be the new free buffer, only update the pointer of the next buffer
			// after the new one
			if(n.next)
				n.next.prev = n;

			// Update the pointers of the buffers linked to the new free buffer that we created
			if(temp_prev.prev)
				temp_prev.prev.next = temp_prev;
			if(temp_prev.prev_free)
				temp_prev.prev_free.next_free = temp_prev;
			if(temp_prev.next_free)
				temp_prev.next_free.prev_free = temp_prev;

			// If the free buffer in which we allocated was the first free or the overall first buffer
			// then the new free buffer we created will take it's place
			if(first_free == temp)
				first_free = temp_prev;
			if(temp_prev._start_addr == this._start_addr)
				first = temp_prev;

			// We removed the old free buffer and replaced it with a new one, also we added
			// a new occupied buffer
			number_of_buffers++;
		end

		// If the buffer's end address doesn't match the free buffer's one then the free buffer is resized,
		// a new free buffer is created and the new buffer is added in between them
		else begin
			//Link it in the mem between the previous buffer and the allocated buffer
			temp_prev.next_free = temp;
			temp_prev.prev_free = temp.prev_free;
			temp_prev.prev = temp.prev;
			temp_prev.next = n;

			// Link the allocated buffer between the alignment/displacement
			n.prev = temp_prev;
			n.next = temp;

			// Resize and link the free buffer
			temp.prev = n;
			temp.prev_free = temp_prev;

			// Check and change the previous links accordingly
			if(temp_prev.prev)
				temp_prev.prev.next = temp_prev;

			// Move the first_free and first pointers to the new free buffer if it's the case
			if(first_free == temp)
				first_free = temp_prev;
			if(temp_prev._start_addr == this._start_addr)
				first = temp_prev;

			// If the new free buffer we created has a buffer before it, update it's next pointer
			if(temp_prev.prev_free)
				temp_prev.prev_free.next_free = temp_prev;

			// We added a new free buffer and the occupied one
			number_of_buffers++;
			number_of_free_buffers++;
		end

	end
endfunction

function void yamm_buffer:: merge(yamm_buffer free_n);

	// Check if the previous buffer exists and it's free
	if((free_n.prev)&&(free_n.prev.free))
	begin
		// Update our buffer's size to include the previous one
		free_n._start_addr = free_n.prev._start_addr;
		free_n._size = free_n._end_addr - free_n._start_addr + 1;

		// If there is a previous buffer to the new concatenated ones update the pointers
		if(free_n.prev.prev)
		begin

			free_n.prev.prev.next = free_n;
			free_n.prev = free_n.prev.prev;
			if(free_n.prev.prev_free)
			begin
				free_n.prev_free = free_n.prev.prev_free;
				free_n.prev_free.next_free = free_n;
			end
		end
		else
		begin
			free_n.prev = null;
		end

		// We removed one free buffer by merging them
		number_of_free_buffers--;
	end

	// Check if the next buffer exists and it's free
	if((free_n.next) && (free_n.next.free))
	begin
		// Update our buffer's size to include the next one
		free_n._end_addr = free_n.next._end_addr;
		free_n._size = free_n._end_addr - free_n._start_addr + 1;

		// If there is a next buffer to the concatenated one update the pointers
		if(free_n.next.next)
		begin
			free_n.next.next.prev = free_n;
			free_n.next = free_n.next.next;
			if(free_n.next.next_free)
			begin
				free_n.next_free = free_n.next.next_free;
				free_n.next_free.prev_free = free_n;
			end
		end
		else
		begin
			free_n.next = null;
		end

		// We removed one free buffer by merging them
		number_of_free_buffers--;
	end
endfunction

function void yamm_buffer::intern_reset();
	yamm_buffer temp = first;
	yamm_buffer del;

	while(temp) begin
		if(temp.free == 0) begin
			if(temp._static == 0) begin
				del = temp;
				temp = temp.next;
				if(del.first != null)
					del.intern_reset();
				void'(this.deallocate(del));
			end
			else begin
				temp.contents.delete();
				if(temp.first != null)
					temp.intern_reset();
				temp = temp.next;
			end
		end
		else
			temp = temp.next;
	end
endfunction

`endif
