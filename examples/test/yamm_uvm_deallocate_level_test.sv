

`ifndef __yamm_uvm_deallocate_level_test
`define __yamm_uvm_deallocate_level_test


/**
 * Tests the level-aware behavior of yamm_buffer::deallocate():
 *  - deallocate() called from an ancestor level on a buffer that is a
 *    (possibly deep) descendant must succeed and remove the buffer at its
 *    own level (the parent chain is walked and the operation delegated).
 *  - deallocate() called from a level that does NOT contain the buffer
 *    (sibling branch or a completely different memory) must fail with a
 *    warning and leave the memory untouched.
 *  - the 'recursive' flag only applies to the buffer being deallocated:
 *    when the buffer has children and recursive == 0 the call must fail,
 *    while recursive == 1 allows it.
 */
class yamm_uvm_deallocate_level_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_deallocate_level_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		yamm mem = new;
		yamm other_mem = new;
		yamm_buffer app0;
		yamm_buffer app1;
		yamm_buffer child;
		yamm_buffer grandchild;
		yamm_buffer child2;
		bit ok;

		mem.build("BigMem", 64);
		other_mem.build("OtherMem", 64);

		// ------------------------------------------------------------------
		// Build a two-level structure:
		//   BigMem -> [ APP0(0..31), APP1(32..63) ]
		//   APP0   -> [ CHILD(0..7), FREE(8..31) ]
		// ------------------------------------------------------------------
		app0 = new;
		app0.set_name("APP0");
		app0.set_start_addr(0);
		app0.set_size(32);
		if(!mem.allocate(app0, FIRST_FIT))
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate APP0")

		app1 = new;
		app1.set_name("APP1");
		app1.set_size(32);
		if(!mem.allocate(app1, FIRST_FIT))
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate APP1")

		child = new;
		child.set_name("CHILD");
		child.set_size(8);
		if(!app0.allocate(child, FIRST_FIT))
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate CHILD inside APP0")

		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent before any deallocation")


		// ------------------------------------------------------------------
		// Case 1: buffer2 IS a (deep) child of the caller.
		// mem.deallocate(child) must walk up the parent chain, delegate to
		// APP0 and free the buffer at its own level.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 1: deallocate a depth-1 child from the top level", UVM_NONE)
		ok = mem.deallocate(child);
		if(!ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Ancestor deallocate of a child should have succeeded")
		if(child.get_size() != 0)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Child was not actually deallocated")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after ancestor deallocate")
		`uvm_info("YAMM_DEALLOC_LVL_INF", $sformatf("%s", mem.sprint_buffer(1)), UVM_MEDIUM)

		// ------------------------------------------------------------------
		// Case 1b: sole-child edge case — SOLE_CHILD exactly fills APP0 so
		// its next and prev are both null inside APP0's list.  The ancestor-
		// level call must still succeed; the "not linked anywhere" guard must
		// NOT fire when the caller is not the direct owner.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 1b: deallocate a sole child (exact fit, next=null prev=null) from the top level", UVM_NONE)
		begin
			yamm_buffer sole_child = new;
			sole_child.set_name("SOLE_CHILD");
			sole_child.set_size(32);
			if(!app0.allocate(sole_child, FIRST_FIT))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate SOLE_CHILD inside APP0")
			ok = mem.deallocate(sole_child);
			if(!ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Ancestor deallocate of a sole child (exact fit) should have succeeded")
			if(!mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after ancestor deallocate of sole child")
			`uvm_info("YAMM_DEALLOC_LVL_INF", $sformatf("%s", mem.sprint_buffer(1)), UVM_MEDIUM)
		end

		// Rebuild the same structure for the remaining cases.
		child = new;
		child.set_name("CHILD");
		child.set_size(8);
		if(!app0.allocate(child, FIRST_FIT))
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to re-allocate CHILD inside APP0")

		// ------------------------------------------------------------------
		// Case 2a: buffer2 is NOT a child of the caller (sibling branch).
		// app1.deallocate(child) must warn and return 0, leaving everything
		// unchanged.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 2a: deallocate from a sibling level (not an ancestor)", UVM_NONE)
		ok = app1.deallocate(child);
		if(ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Deallocate from a non-ancestor level should have failed")
		if(child.get_size() != 8)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Child was modified even though deallocation should have failed")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected sibling deallocate")

		// ------------------------------------------------------------------
		// Case 2b: buffer belongs to a completely different memory object.
		// Allocate foreign_buf inside other_mem, then verify that mem cannot
		// deallocate it, and that other_mem cannot deallocate child from mem.
		// Both calls must warn and return 0, leaving both memories intact.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 2b: deallocate a buffer from a foreign memory", UVM_NONE)
		begin
			yamm_buffer foreign_buf = new;
			foreign_buf.set_name("FOREIGN");
			foreign_buf.set_size(8);
			if(!other_mem.allocate(foreign_buf, FIRST_FIT))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate FOREIGN inside other_mem")
			// mem must not be able to free a buffer that lives in other_mem
			ok = mem.deallocate(foreign_buf);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Deallocate of a foreign buffer from mem should have failed")
			if(foreign_buf.get_size() != 8)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "FOREIGN was modified even though deallocation should have failed")
			if(!mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "mem inconsistent after rejected foreign deallocate")
			if(!other_mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "other_mem inconsistent after rejected foreign deallocate")
			// other_mem must not be able to free a buffer that lives in mem
			ok = other_mem.deallocate(child);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Deallocate of a mem buffer from other_mem should have failed")
			if(child.get_size() != 8)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "CHILD was modified even though deallocation should have failed")
			if(!mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "mem inconsistent after reverse foreign deallocate")
			if(!other_mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "other_mem inconsistent after reverse foreign deallocate")
		end

		// ------------------------------------------------------------------
		// Case 3: the recursive flag. Give CHILD a child of its own and try
		// to free CHILD from its direct parent (APP0) with recursive == 0
		// and recursive == 1. The flag is evaluated only at the level where
		// the buffer actually lives.
		// ------------------------------------------------------------------
		grandchild = new;
		grandchild.set_name("GRANDCHILD");
		grandchild.set_size(4);
		if(!child.allocate(grandchild, FIRST_FIT))
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate GRANDCHILD inside CHILD")

		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 3a: recursive=0 on a buffer with children must fail", UVM_NONE)
		ok = app0.deallocate(child, 0);
		if(ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "recursive=0 deallocate of a buffer with children should have failed")
		if(child.get_size() != 8)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Child was modified even though recursive=0 deallocation should have failed")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected recursive=0 deallocate")

		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 3b: recursive=1 on a buffer with children must succeed", UVM_NONE)
		ok = app0.deallocate(child, 1);
		if(!ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "recursive=1 deallocate of a buffer with children should have succeeded")
		if(child.get_size() != 0)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Child was not actually deallocated with recursive=1")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after recursive=1 deallocate")
		`uvm_info("YAMM_DEALLOC_LVL_INF", $sformatf("%s", mem.sprint_buffer(1)), UVM_MEDIUM)

		// ------------------------------------------------------------------
		// Case 4: self-deallocation must be rejected. A level can only free
		// buffers that live in its own subtree; a buffer (or the memory root)
		// is not contained in itself, so both calls below must warn and return
		// 0 without corrupting anything.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 4a: a top-level buffer deallocating itself", UVM_NONE)
		ok = app0.deallocate(app0);
		if(ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "A buffer deallocating itself should have failed")
		if(app0.get_size() != 32)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "APP0 was modified even though self-deallocation should have failed")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected buffer self-deallocate")

		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 4b: the memory root deallocating itself", UVM_NONE)
		ok = mem.deallocate(mem);
		if(ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "The memory root deallocating itself should have failed")
		if(mem.get_size() != 64)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Memory size changed even though self-deallocation should have failed")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected memory self-deallocate")

		// ------------------------------------------------------------------
		// Case 5: a child trying to free its own parent must be rejected.
		// APP1's parent chain does not lead through CHILD, so the call is
		// refused (no delegation upward). A fresh child is allocated for this
		// case because 'child' above was already freed by Case 3.
		// ------------------------------------------------------------------
		child2 = new;
		child2.set_name("CHILD2");
		child2.set_size(8);
		if(!app0.allocate(child2, FIRST_FIT))
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate CHILD2 inside APP0")

		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 5: a child deallocate()ing its own parent", UVM_NONE)
		ok = child2.deallocate(app1);
		if(ok)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "A child freeing its parent should have failed")
		if(app1.get_size() != 32)
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "APP1 was modified even though child-frees-parent should have failed")
		if(!mem.check_address_space_consistency())
			`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected child-frees-parent deallocate")

		// ------------------------------------------------------------------
		// Case 6: a reset() drops a static buffer's child list. The
		// orphaned children keep their old handles but must no longer
		// pass the parent-chain ownership check (stale parent links).
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 6: reset orphans a static buffer's children", UVM_NONE)
		begin
			yamm_buffer sb = new;
			yamm_buffer sc1;
			yamm_buffer sc2;
			mem.reset();
			sb.set_name("STATIC_BUF");
			sb.set_start_addr_size(0, 'h20);
			if(!mem.allocate_static_buffer(sb))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate STATIC_BUF")
			sc1 = sb.allocate_by_size('h10, FIRST_FIT);
			sc2 = sb.allocate_by_size('h10, FIRST_FIT);
			if(sc1 == null || sc2 == null)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate inside STATIC_BUF")
			mem.reset();
			if(sb.get_buffer('h0) != null)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "STATIC_BUF's child list should have been dropped by reset")
			if(!sb.allocate_by_size('h20, FIRST_FIT))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to re-allocate inside STATIC_BUF after reset")
			// The stale child must be rejected both from the memory root
			// and from the static buffer that used to own it
			ok = mem.deallocate(sc1);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Stale child after reset was deallocated through the memory")
			ok = sb.deallocate(sc1);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Stale child was deallocated from the static buffer itself")
			if(!mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after stale child rejection")
			if(!sb.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "STATIC_BUF inconsistent after stale child rejection")
		end

		// ------------------------------------------------------------------
		// Case 7: a buffer that is deallocated recursively and then
		// re-allocated must start with consistent child counters.
		// RANDOM_FIT uses number_of_free_buffers, so a stale count walks
		// past the end of the rebuilt free list and hits a null reference
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 7: re-allocation after recursive deallocate has consistent counters", UVM_NONE)
		begin
			yamm_buffer p = new;
			yamm_buffer mid = new;
			p.set_name("COUNTER_P");
			p.set_size('h30);
			if(!other_mem.allocate(p, FIRST_FIT))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate COUNTER_P")
			// Insert a buffer in the middle so P ends up with two free buffers
			mid.set_name("COUNTER_MID");
			mid.set_size('h08);
			mid.set_start_addr(p.get_start_addr() + 'h08);
			if(!p.insert(mid))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to insert COUNTER_MID")
			if(!other_mem.deallocate(p))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Recursive deallocate of COUNTER_P failed")
			p.set_size('h10);
			if(!other_mem.allocate(p, FIRST_FIT))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to re-allocate COUNTER_P")
			if(p.allocate_by_size('h08, RANDOM_FIT) == null)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "RANDOM_FIT allocation in re-allocated COUNTER_P failed (stale free count)")
		end

		// ------------------------------------------------------------------
		// Case 8: the recursive flag. A buffer whose children have all
		// been freed (child list reduced to a single free buffer spanning
		// the whole range) can be deallocated with recursive == 0. A
		// buffer that still has an occupied child must be refused.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 8: recursive=0 on a buffer whose children are all free", UVM_NONE)
		begin
			yamm_buffer q = other_mem.allocate_by_size('h10, FIRST_FIT);
			yamm_buffer qc = q.allocate_by_size('h08, FIRST_FIT);
			yamm_buffer r = other_mem.allocate_by_size('h10, FIRST_FIT);
			yamm_buffer rc = r.allocate_by_size('h04, FIRST_FIT);
			if(q == null || qc == null || r == null || rc == null)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate Q/R structures")
			// Free Q's only child: its list is now a single free buffer
			if(!q.deallocate(qc))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to deallocate Q's child")
			ok = other_mem.deallocate(q, 0);
			if(!ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Non-recursive deallocate of a buffer with only free children should have succeeded")
			// R still has an occupied child: recursive=0 must be refused
			ok = other_mem.deallocate(r, 0);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Non-recursive deallocate of a buffer with occupied children should have failed")
			if(r.get_size() != 'h10)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "R was modified even though deallocation should have failed")
			// recursive=1 still works
			if(!other_mem.deallocate(r, 1))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Recursive deallocate of R failed")
			if(!other_mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after Case 8")
		end

		// ------------------------------------------------------------------
		// Case 9: double allocation. A buffer that exactly fills its
		// level (next/prev null) is still allocated: it must not be
		// allocatable a second time into another level.
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 9: a buffer that fills its level can't be allocated twice", UVM_NONE)
		begin
			yamm_buffer h1 = other_mem.allocate_by_size(8, FIRST_FIT);
			yamm_buffer h2 = other_mem.allocate_by_size(8, FIRST_FIT);
			yamm_buffer fill = new;
			if(h1 == null || h2 == null)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate H1/H2")
			fill.set_name("FILL");
			fill.set_size(8);
			if(!h1.allocate(fill, FIRST_FIT))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Failed to allocate FILL inside H1")
			// FILL now fills H1 exactly: next and prev are both null
			ok = h2.allocate(fill, FIRST_FIT);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "A buffer that fills its level was allocated a second time")
			if(fill.get_size() != 8)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "FILL was modified even though the second allocation should have failed")
			if(!other_mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected double allocation")
			// FILL is still a valid child of H1 and can be freed normally
			if(!h1.deallocate(fill))
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "FILL should still be deallocatable from H1")
		end

		// ------------------------------------------------------------------
		// Case 10: a never-allocated buffer can't be allocated inside
		// itself (or one of its descendants): that would create a parent
		// loop and make the ownership walk in deallocate() run forever
		// ------------------------------------------------------------------
		`uvm_info("YAMM_DEALLOC_LVL_INF", "Case 10: a buffer can't be allocated inside itself", UVM_NONE)
		begin
			yamm_buffer selfb = new;
			selfb.set_name("SELF_BUF");
			selfb.set_size(100);
			ok = selfb.allocate(selfb, FIRST_FIT);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "A buffer was allocated inside itself (parent loop)")
			// The ownership walk in deallocate() must terminate for such a buffer
			ok = mem.deallocate(selfb);
			if(ok)
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Self buffer was deallocated even though it was never allocated")
			if(!mem.check_address_space_consistency())
				`uvm_fatal("YAMM_DEALLOC_LVL_FATAL", "Inconsistent after rejected self-allocation")
		end

		`uvm_info("YAMM_DEALLOC_LVL_INF", "All cross-level deallocate cases passed", UVM_LOW)

	endtask

endclass

`endif

