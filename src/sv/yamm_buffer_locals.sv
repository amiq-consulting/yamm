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

function yamm_addr_width_t yamm_buffer::get_aligned_addr(int alignment, yamm_buffer suitable_free_buffer);

	// Compute the displacement needed
	int align = (alignment - suitable_free_buffer.start_addr % alignment);
	align = align %alignment;

	// If the buffer displacement start addr fits in the buffer return
	// the new start address
	if((suitable_free_buffer.start_addr + align) <= suitable_free_buffer.end_addr)
		return suitable_free_buffer.start_addr + align;

	// If it doesn't, return _end_addr+1. Usable for error checking
	return suitable_free_buffer.end_addr+1;

endfunction

function yamm_size_width_t yamm_buffer::compute_size_with_gran(yamm_size_width_t size, int granularity);

	return size + (granularity - size % granularity) % granularity;

endfunction

function yamm_size_width_t yamm_buffer::compute_size_with_align(int alignment, yamm_buffer suitable_free_buffer);

	return suitable_free_buffer.end_addr - get_aligned_addr(alignment, suitable_free_buffer) + 1;

endfunction

function void yamm_buffer::get_closest_aligned_addr(yamm_buffer suitable_free_buffer);

	// Compute the displacement needed for alignment
	int negalign = (start_addr % start_addr_alignment) % start_addr_alignment;
	int posalign = (start_addr_alignment - start_addr % start_addr_alignment) % start_addr_alignment;

	// Apply the lower one of the two
	if((negalign <= posalign) && (start_addr - negalign >= suitable_free_buffer.start_addr))
		start_addr = start_addr - negalign;
	else
		start_addr = start_addr + posalign;


endfunction

function bit yamm_buffer::compute_start_addr(yamm_buffer suitable_free_buffer, yamm_allocation_mode_e alloc_mode);

	// The start_addr for BEST_FIT and FIRST_FIT follows the same rule
	// As close to the start_addr as alignment allows
	if(alloc_mode == BEST_FIT)
		alloc_mode = FIRST_FIT;

	if((alloc_mode == FIRST_FIT_RND) || (alloc_mode == BEST_FIT_RND))
		alloc_mode = RANDOM_FIT;

	case(alloc_mode)
		FIRST_FIT: // same as BEST_FIT
		begin
			start_addr = get_aligned_addr(start_addr_alignment, suitable_free_buffer);
			if(start_addr > suitable_free_buffer.get_end_addr())
				return 0;
			else
				return 1;
		end

		RANDOM_FIT: begin

			// Randomize the start_addr with the constrains of being inside
			// the buffer boundaries and respecting the alignment
			if (!randomize(start_addr) with {
						start_addr >= suitable_free_buffer.start_addr;
						start_addr <= suitable_free_buffer.get_end_addr()-size + 1;
						start_addr % start_addr_alignment == 0;
					}) begin
				$error($sformatf("[YAMM_ERR] Can't randomize!"));
				return 0;
			end

			return 1;

		end

		UNIFORM_FIT: begin

			start_addr = suitable_free_buffer.start_addr + (suitable_free_buffer.size - size)/2;
			this.get_closest_aligned_addr(suitable_free_buffer);
			if((start_addr >= suitable_free_buffer.start_addr) && (start_addr <= suitable_free_buffer.get_end_addr()))
				return 1;
			else
				return 0;
		end

		default:
			return 0;

	endcase
endfunction

//Function used to find a suitable free buffer for allocation
function yamm_buffer yamm_buffer::find_suitable_buffer(yamm_size_width_t size, int alignment, yamm_allocation_mode_e alloc_mode);

	// Take a handle to the first free buffer in memory
	yamm_buffer temp = first_free;
	yamm_size_width_t tsize;

	// Check if there are any free buffers inside and if this is a new allocation inside
	// an existing buffer create one
	if(temp==null) begin
		if(first)
			return null;
		else begin
			first_free = new();
			first_free.start_addr = start_addr;
			first_free.size = this.size;
			first_free.end_addr = first_free.start_addr + first_free.size - 1;
			first_free.is_free = 1;
			first = first_free;
			temp = first_free;
		end
	end

	tsize = temp.size;

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
				if(size <= temp.size)
					if(alignment != 1)
						tsize = compute_size_with_align(alignment, temp);
					else
						tsize = temp.size;
				else
					tsize = temp.size;
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

				if(size <= temp.size) begin
					if(!best_temp)
						if(alignment != 1)
							tsize = compute_size_with_align(alignment, temp);
						else
							tsize = temp.size;
					else
						if((alignment != 1) && (temp.size <= best_temp.size))
							tsize = compute_size_with_align(alignment, temp);
						else
							tsize = temp.size;

					if(size <= tsize) begin
						// The best_temp isn't yet set, take the first buffer that fits as reference
						if(!set) begin
							best_temp = temp;
							set = 1;
						end
						if((temp.size <= best_temp.size) && (size <= tsize))
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

				if(size <= temp.size) begin
					if(!found)
						if(alignment != 1) begin
							tsize = compute_size_with_align(alignment, temp);
							found = 1;
						end
						else begin
							tsize = temp.size;
							found = 1;
						end
					else
						tsize = temp.size;

					if((temp.size >= uniform_temp.size) && (size <= tsize)) begin
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
				temp = temp.next_free;
			end

			if(size <= temp.size)
				if(alignment != 1)
					tsize = compute_size_with_align(alignment, temp);
				else
					tsize = temp.size;
			else
				tsize = temp.size;

			if(tsize >= size)
				return temp;

			temp_prev = temp;

			// Search the memory for a suitable free buffer
			while((temp.next_free) || (temp_prev.prev_free)) begin

				if(temp.next_free) begin
					temp = temp.next_free;

					if(size <= temp.size)
						if(alignment != 1)
							tsize = compute_size_with_align(alignment, temp);
						else
							tsize = temp.size;
					else
						tsize = temp.size;

					if(tsize >= size)
						return temp;
				end

				if(temp_prev.prev_free) begin
					temp_prev = temp_prev.prev_free;

					if(size <= temp_prev.size)
						if(alignment != 1)
							tsize = compute_size_with_align(alignment, temp_prev);
						else
							tsize = temp_prev.size;
					else
						tsize = temp_prev.size;

					if(tsize >= size)
						return temp_prev;
				end
			end

			return null;

		end
		default: begin
			return null;
		end
	endcase
endfunction

// Function used to insert buffer n in the FREE buffer temp
function void yamm_buffer::add(yamm_buffer new_buffer, yamm_buffer suitable_free_buffer);

	yamm_buffer temp_prev = new;

// First, check if there is a displacement caused by allocation mode or alignment
	if(new_buffer.start_addr > suitable_free_buffer.start_addr) begin
		temp_prev.start_addr = suitable_free_buffer.start_addr;
		temp_prev.size = new_buffer.start_addr-suitable_free_buffer.start_addr;
		temp_prev.end_addr = temp_prev.start_addr + temp_prev.size-1;
		temp_prev.is_free = 1;
	end

// Second, check if there remains a free buffer after the one we allocate (if you resize or delete the old free buffer)
	if(new_buffer.end_addr < suitable_free_buffer.end_addr) begin
		suitable_free_buffer.start_addr = new_buffer.end_addr+1;
		suitable_free_buffer.size = suitable_free_buffer.end_addr - suitable_free_buffer.start_addr + 1;
	end

	if(temp_prev.is_free)
		link_in_list(temp_prev, new_buffer, suitable_free_buffer);
	else
		link_in_list(null, new_buffer, suitable_free_buffer);
endfunction

function void  yamm_buffer::link_in_list(yamm_buffer prev_free_buffer, yamm_buffer new_buffer, yamm_buffer next_free_buffer);

	// In this case the new buffer's start addr is equal to the free buffer's one
	// The new buffer comes between the previous buffer and the resized free one
	// or the new buffer should completely replace the free one if the sizes match
	if(prev_free_buffer == null) begin

		// First case: The new buffer's size match the free buffer's size
		if(new_buffer.end_addr == next_free_buffer.end_addr) begin
			// The allocated buffer replaces the free buffer.
			new_buffer.prev = next_free_buffer.prev;
			new_buffer.next = next_free_buffer.next;

			// Any links that the free buffer had should be updated
			if(next_free_buffer.prev_free)
				next_free_buffer.prev_free.next_free = next_free_buffer.next_free;
			if(next_free_buffer.next_free)
				next_free_buffer.next_free.prev_free = next_free_buffer.prev_free;

			// Link the new buffer to the next buffer
			if(new_buffer.next)
				new_buffer.next.prev = new_buffer;

			// Link the new buffer to the previous buffer
			if(new_buffer.prev)
				new_buffer.prev.next = new_buffer;

			// If the start address of the new buffer matches the start address
			// of the memory map then move the first pointer to the new buffer
			if(new_buffer.start_addr == this.start_addr)
				first = new_buffer;

			// If the free buffer was the first_free buffer move the pointer to
			// the next free buffer
			if(first_free == next_free_buffer)
				first_free = next_free_buffer.next_free;

			// The free buffer was removed and replaced by an occupied one
			number_of_buffers++;
			number_of_free_buffers--;
		end
		else begin
			// Link the allocated buffer in mem
			new_buffer.prev = next_free_buffer.prev;
			new_buffer.next = next_free_buffer;

			if(new_buffer.prev)
				new_buffer.prev.next = new_buffer;

			next_free_buffer.prev = new_buffer;

			if(new_buffer.start_addr == this.start_addr)
				first = new_buffer;

			number_of_buffers++;
		end
	end

	// Second case: the new buffer is smaller than the free buffer
	else begin

		// If the buffer's end address match the end address of the free buffer then the free buffer
		// should be removed and a new free buffer should be added in front of the new buffer
		if(new_buffer.end_addr == next_free_buffer.end_addr) begin
			// Link the buffer between the previous buffer and the allocated buffer
			prev_free_buffer.next_free = next_free_buffer.next_free;
			prev_free_buffer.prev_free = next_free_buffer.prev_free;
			prev_free_buffer.prev = next_free_buffer.prev;
			prev_free_buffer.next = new_buffer;

			// Fit the new buffer between the alignment/displacement buffer and the next buffer in mem
			new_buffer.prev = prev_free_buffer;
			new_buffer.next = next_free_buffer.next;

			// The previous will be the new free buffer, only update the pointer of the next buffer
			// after the new one
			if(new_buffer.next)
				new_buffer.next.prev = new_buffer;

			// Update the pointers of the buffers linked to the new free buffer that we created
			if(prev_free_buffer.prev)
				prev_free_buffer.prev.next = prev_free_buffer;
			if(prev_free_buffer.prev_free)
				prev_free_buffer.prev_free.next_free = prev_free_buffer;
			if(prev_free_buffer.next_free)
				prev_free_buffer.next_free.prev_free = prev_free_buffer;

			// If the free buffer in which we allocated was the first free or the overall first buffer
			// then the new free buffer we created will take it's place
			if(first_free == next_free_buffer)
				first_free = prev_free_buffer;
			if(prev_free_buffer.start_addr == this.start_addr)
				first = prev_free_buffer;

			// We removed the old free buffer and replaced it with a new one, also we added
			// a new occupied buffer
			number_of_buffers++;
		end

		// If the buffer's end address doesn't match the free buffer's one then the free buffer is resized,
		// a new free buffer is created and the new buffer is added in between them
		else begin
			//Link it in the mem between the previous buffer and the allocated buffer
			prev_free_buffer.next_free = next_free_buffer;
			prev_free_buffer.prev_free = next_free_buffer.prev_free;
			prev_free_buffer.prev = next_free_buffer.prev;
			prev_free_buffer.next = new_buffer;

			// Link the allocated buffer between the alignment/displacement
			new_buffer.prev = prev_free_buffer;
			new_buffer.next = next_free_buffer;

			// Resize and link the free buffer
			next_free_buffer.prev = new_buffer;
			next_free_buffer.prev_free = prev_free_buffer;

			// Check and change the previous links accordingly
			if(prev_free_buffer.prev)
				prev_free_buffer.prev.next = prev_free_buffer;

			// Move the first_free and first pointers to the new free buffer if it's the case
			if(first_free == next_free_buffer)
				first_free = prev_free_buffer;
			if(prev_free_buffer.start_addr == this.start_addr)
				first = prev_free_buffer;

			// If the new free buffer we created has a buffer before it, update it's next pointer
			if(prev_free_buffer.prev_free)
				prev_free_buffer.prev_free.next_free = prev_free_buffer;

			// We added a new free buffer and the occupied one
			number_of_buffers++;
			number_of_free_buffers++;
		end

	end
endfunction

function void yamm_buffer:: merge(yamm_buffer new_free_buffer);

	// Check if the previous buffer exists and it's free
	if((new_free_buffer.prev)&&(new_free_buffer.prev.is_free))
	begin
		// Update our buffer's size to include the previous one
		new_free_buffer.start_addr = new_free_buffer.prev.start_addr;
		new_free_buffer.size = new_free_buffer.end_addr - new_free_buffer.start_addr + 1;

		// If there is a previous buffer to the new concatenated ones update the pointers
		if(new_free_buffer.prev.prev)
		begin

			new_free_buffer.prev.prev.next = new_free_buffer;
			new_free_buffer.prev = new_free_buffer.prev.prev;
			if(new_free_buffer.prev.prev_free)
			begin
				new_free_buffer.prev_free = new_free_buffer.prev.prev_free;
				new_free_buffer.prev_free.next_free = new_free_buffer;
			end
		end
		else
		begin
			new_free_buffer.prev = null;
		end

		// We removed one free buffer by merging them
		number_of_free_buffers--;
	end

	// Check if the next buffer exists and it's free
	if((new_free_buffer.next) && (new_free_buffer.next.is_free))
	begin
		// Update our buffer's size to include the next one
		new_free_buffer.end_addr = new_free_buffer.next.end_addr;
		new_free_buffer.size = new_free_buffer.end_addr - new_free_buffer.start_addr + 1;

		// If there is a next buffer to the concatenated one update the pointers
		if(new_free_buffer.next.next)
		begin
			new_free_buffer.next.next.prev = new_free_buffer;
			new_free_buffer.next = new_free_buffer.next.next;
			if(new_free_buffer.next.next_free)
			begin
				new_free_buffer.next_free = new_free_buffer.next.next_free;
				new_free_buffer.next_free.prev_free = new_free_buffer;
			end
		end
		else
		begin
			new_free_buffer.next = null;
		end

		// We removed one free buffer by merging them
		number_of_free_buffers--;
	end
endfunction

function void yamm_buffer::intern_reset();
	yamm_buffer temp = first;
	yamm_buffer del;

	while(temp) begin
		if(temp.is_free == 0) begin
			if(temp.is_static == 0) begin
				del = temp;
				temp = temp.next;
				if(del.first != null)
					del.intern_reset();
				void'(this.deallocate(del));
			end
			else begin
				temp.contents.delete();
				temp.number_of_buffers = 0;
				temp.number_of_free_buffers = 1;
				if(temp.first != null) begin
					// If recursive static buffers are implemented make this a recursive call
					// temp.intern_reset();
					temp.first = null;
					temp.first_free = null;
				end
				temp = temp.next;
			end
		end
		else
			temp = temp.next;
	end
endfunction

function yamm_buffer yamm_buffer::internal_get_buffer(yamm_addr_width_t start);

	yamm_buffer handle_to_buffer;
	handle_to_buffer = first;

	// Check if the address given is valid (it exists in the memory map)
	if((start>end_addr) || (start<start_addr))
	begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Address is outside current memory map boundaries. Search failed.");
		`else
		$warning("[YAMM_WRN] Address is outside current memory map boundaries. Search failed.");
		`endif
		return null;
	end

	if(first == null) begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "The buffer searched is empty.");
		`else
		$warning("[YAMM_WRN] The buffer searched is empty.");
		`endif
		return null;
	end

	// Look for the buffer that contains the given address
	while((handle_to_buffer.next) && (handle_to_buffer.end_addr < start))
		handle_to_buffer = handle_to_buffer.next;

	// If the buffer is found return it.
	if(start>=handle_to_buffer.start_addr)
	begin
		return handle_to_buffer;
	end else begin
		if(!disable_warnings)
		`ifdef YAMM_USE_UVM
			`uvm_warning("YAMM_WRN", "Search failed.");
		`else
		$warning("[YAMM_WRN] Search failed.");
		`endif
		return null;
	end
endfunction


`endif
