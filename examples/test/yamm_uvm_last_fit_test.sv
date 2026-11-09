

`ifndef __yamm_uvm_last_fit_test
`define __yamm_uvm_last_fit_test

/**
 * Directed tests for the LAST_FIT allocation mode
 */
class yamm_uvm_last_fit_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_last_fit_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	// A fresh memory of the given size
	function yamm new_mem(yamm_size_width_t size);
		yamm m = new;
		m.build("LAST_FIT_MEM", size);
		return m;
	endfunction

	// Allocates 'size' bytes aligned to 'align' with LAST_FIT inside 'level'; null on failure
	function yamm_buffer alloc_last(yamm_buffer level, yamm_size_width_t size, int align = 1);
		yamm_buffer b = new;
		b.set_size(size);
		b.set_start_addr_alignment(align);
		if(!level.allocate(b, LAST_FIT))
			return null;
		return b;
	endfunction

	// Inserts an occupied buffer at a fixed address (builds known layouts)
	function void insert_at(yamm_buffer level, yamm_addr_width_t start, yamm_size_width_t size);
		yamm_buffer b = new;
		b.set_start_addr_size(start, size);
		if(!level.insert(b))
			`uvm_fatal("LAST_FIT_FATAL", $sformatf("insert at 0x%0h failed", start))
	endfunction

	// Fails unless b was allocated at 'expected' and the whole memory is consistent
	function void expect_at(yamm m, yamm_buffer b, yamm_addr_width_t expected, string id);
		if(b == null)
			`uvm_fatal("LAST_FIT_FATAL", $sformatf("%s: allocation failed, expected start 0x%0h", id, expected))
		if(b.get_start_addr() != expected)
			`uvm_fatal("LAST_FIT_FATAL", $sformatf("%s: start 0x%0h, expected 0x%0h", id, b.get_start_addr(), expected))
		if(!m.check_address_space_consistency())
			`uvm_fatal("LAST_FIT_FATAL", $sformatf("%s: memory inconsistent", id))
	endfunction

	// Map M1: occupied [0x000, 0x0FF] and [0x200, 0xFC7] in a fresh 0x1000
	// Free regions: A = [0x100, 0x1FF] (0x100 bytes) and B = [0xFC8, 0xFFF] (0x38 bytes)
	function yamm build_m1();
		yamm m = new_mem('h1000);
		insert_at(m, 'h000, 'h100);
		insert_at(m, 'h200, 'hdc8);
		return m;
	endfunction

	task run_phase(uvm_phase phase);

		// D1 + D2: displacement + exact end, then the search starts at the tail
		begin
			yamm m = new_mem('h1000);
			yamm_buffer b1, b2;
			b1 = alloc_last(m, 'h100);
			expect_at(m, b1, 'hf00, "D1");
			b2 = alloc_last(m, 'h100);
			expect_at(m, b2, 'he00, "D2");
		end

		// D3: displacement + middle (free [0xFFB, 0xFFF] after the buffer)
		begin
			yamm m = new_mem('h1000);
			yamm_buffer b = alloc_last(m, 'h13, 8);
			expect_at(m, b, 'hfe8, "D3");
		end

		// D4/D5: non-power-of-two alignment
		begin
			yamm m = new_mem('h1000);
			yamm_buffer b = alloc_last(m, 'h11, 3);
			expect_at(m, b, 'hfed, "D4");
		end
		begin
			yamm m = new_mem('h1000);
			yamm_buffer b = alloc_last(m, 'h11, 6);
			expect_at(m, b, 'hfea, "D5");
		end

		// D6: the top region is chosen
		begin
			yamm m = build_m1();
			yamm_buffer b = alloc_last(m, 'h30);
			expect_at(m, b, 'hfd0, "D6");
		end

		// D7: the top region fails once aligned; shrink of region A
		begin
			yamm m = build_m1();
			yamm_buffer b = alloc_last(m, 'h30, 'h100);
			expect_at(m, b, 'h100, "D7");
		end

		// D8: size guard, no unsigned wrap-around
		begin
			yamm m = new_mem('h1000);
			yamm_buffer b = alloc_last(m, 'h1001);
			if(b != null)
				`uvm_fatal("LAST_FIT_FATAL", "D8: allocation of 0x1001 in a 0x1000 memory must fail")
			if(m.get_usage_statistics() != 0)
				`uvm_fatal("LAST_FIT_FATAL", "D8: usage changed after a failed allocation")
		end

		// D9: no region big enough
		begin
			yamm m = build_m1();
			yamm_buffer b = alloc_last(m, 'h101);
			if(b != null)
				`uvm_fatal("LAST_FIT_FATAL", "D9: 0x101 does not fit in M1")
		end

		// D10: exact fill, then a full level
		begin
			yamm m = new_mem('h1000);
			yamm_buffer b1, b2;
			b1 = alloc_last(m, 'h1000);
			expect_at(m, b1, 'h000, "D10a");
			b2 = alloc_last(m, 'h1);
			if(b2 != null)
				`uvm_fatal("LAST_FIT_FATAL", "D10b: allocation in a full level must fail")
		end

		// ---------------- S1: packing at scale (O(1) per search) ----------------
		begin
			yamm m = new_mem('h10000);
			yamm_buffer bufs[$];
			yamm_buffer b;
			for (int k = 1; k <= 4096; k++) begin
				b = alloc_last(m, 'h10);
				if(b == null)
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S1: allocation %0d failed", k))
				if(b.get_start_addr() != ('h10000 - k*16))
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S1: buffer %0d at 0x%0h, expected 0x%0h", k, b.get_start_addr(), 'h10000 - k*16))
				bufs.push_back(b);
				if((k % 256 == 0) && !m.check_address_space_consistency())
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S1: inconsistent after %0d allocations", k))
			end
			if(!m.check_address_space_consistency())
				`uvm_fatal("LAST_FIT_FATAL", "S1: inconsistent at the end")
			// The 4097th allocation must fail (the level is full)
			if(alloc_last(m, 'h10) != null)
				`uvm_fatal("LAST_FIT_FATAL", "S1: allocation in a full level must fail")
		end

		// ---------------- S2: alignment slack, search skipping small regions ----------------
		begin
			yamm m = new_mem('h10000);
			yamm_buffer bufs[$];
			yamm_buffer b;
			for (int k = 1; k <= 64; k++) begin
				b = alloc_last(m, 'h18, 'h10);
				if(b == null)
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S2: allocation %0d failed", k))
				if(b.get_start_addr() != ('h10000 - k*32))
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S2: buffer %0d at 0x%0h, expected 0x%0h", k, b.get_start_addr(), 'h10000 - k*32))
				bufs.push_back(b);
			end
			if(!m.check_address_space_consistency())
				`uvm_fatal("LAST_FIT_FATAL", "S2: inconsistent")
		end

		// ---------------- S3-S6: freeing and re-allocating from the tail ----------------
		begin
			yamm m = new_mem('h10000);
			yamm_buffer bufs[$];
			yamm_buffer b;
			// Stack of 64 buffers of size 0x10: buffer k at 0x10000 - k*16
			for (int k = 1; k <= 64; k++) begin
				b = alloc_last(m, 'h10);
				if(b == null)
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S3: stack allocation %0d failed", k))
				bufs.push_back(b);
			end
			// S3: free buffer 10 (0xFF60); the forward walk ends on an occupied node
			void'(m.deallocate(bufs[9]));
			expect_at(m, alloc_last(m, 'h10), 'hff60, "S3");
			// S4: free buffer 20 then 21; merge() absorbs the old tail as the next neighbor
			void'(m.deallocate(bufs[19]));
			void'(m.deallocate(bufs[20]));
			expect_at(m, alloc_last(m, 'h20), 'hfeb0, "S4");
			// S5: free buffer 30 then 29; merge() absorbs the old tail as the previous neighbor
			void'(m.deallocate(bufs[29]));
			void'(m.deallocate(bufs[28]));
			expect_at(m, alloc_last(m, 'h20), 'hfe20, "S5");
			// S6: free buffer 1 (0xFFF0); the freed node is the last node of the level
			void'(m.deallocate(bufs[0]));
			expect_at(m, alloc_last(m, 'h10), 'hfff0, "S6");
			if(!m.check_address_space_consistency())
				`uvm_fatal("LAST_FIT_FATAL", "S3-S6: inconsistent")
		end

		// ---------------- S7/S8: nested levels (lazy init in both places) ----------------
		begin
			yamm m = new_mem('h10000);
			yamm_buffer p, q;
			// S7: lazy init in find_suitable_buffer()
			p = alloc_last(m, 'h1000);
			expect_at(m, p, 'hf000, "S7a");
			expect_at(m, alloc_last(p, 'h100), 'hff00, "S7b");
			// S8: lazy init in insert()
			q = alloc_last(m, 'h1000);
			expect_at(m, q, 'he000, "S8a");
			insert_at(q, 'he000, 'h10);
			expect_at(m, alloc_last(q, 'h10), 'heff0, "S8b");
		end

		// ---------------- S9: reset of a full level ----------------
		begin
			yamm m = new_mem('h10000);
			yamm_buffer b;
			for (int k = 1; k <= 4096; k++) begin
				b = alloc_last(m, 'h10);
				if(b == null)
					`uvm_fatal("LAST_FIT_FATAL", $sformatf("S9: failed to fill the memory at %0d", k))
			end
			m.reset();
			expect_at(m, alloc_last(m, 'h10), 'hfff0, "S9");
		end

		// ---------------- S10: static buffer survives reset (SV only) ----------------
		begin
			yamm m = new_mem('h1000);
			yamm_buffer s = new;
			s.set_start_addr_size('h800, 'h100);
			if(!m.allocate_static_buffer(s))
				`uvm_fatal("LAST_FIT_FATAL", "S10: static allocation failed")
			expect_at(m, alloc_last(s, 'h10), 'h8f0, "S10a");
			m.reset();
			expect_at(m, alloc_last(s, 'h20), 'h8e0, "S10b");
		end

		// ---------------- S11: deallocate cleanup and reuse (SV only) ----------------
		begin
			yamm m = new_mem('h1000);
			yamm_buffer r = alloc_last(m, 'h100);
			expect_at(m, r, 'hf00, "S11a");
			expect_at(m, alloc_last(r, 'h10), 'hff0, "S11b");
			if(!m.deallocate(r))
				`uvm_fatal("LAST_FIT_FATAL", "S11: deallocate(R) failed")
			if(!r.check_address_space_consistency())
				`uvm_fatal("LAST_FIT_FATAL", "S11: R inconsistent after deallocate")
			r.set_size('h100);
			if(!m.allocate(r, LAST_FIT))
				`uvm_fatal("LAST_FIT_FATAL", "S11: re-allocation of R failed")
			if(r.get_start_addr() != 'hf00)
				`uvm_fatal("LAST_FIT_FATAL", $sformatf("S11: R at 0x%0h, expected 0xf00", r.get_start_addr()))
			expect_at(m, alloc_last(r, 'h10), 'hff0, "S11c");
		end

		`uvm_info("LAST_FIT_INF", "All LAST_FIT cases passed", UVM_LOW)
	endtask

endclass

`endif