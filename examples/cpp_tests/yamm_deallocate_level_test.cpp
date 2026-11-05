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

#ifndef __yamm_deallocate_level_test
#define __yamm_deallocate_level_test

#include <stdio.h>

#include "yamm.h"
#include "test_utils.h"

using namespace yamm_ns;

int main(int argc, char* argv[]) {

	// ------------------------------------------------------------------
	// Build a two-level structure:
	//   BigMem -> [ APP0(0..31), APP1(32..63) ]
	//   APP0   -> [ CHILD(0..7), FREE(8..31) ]
	// ------------------------------------------------------------------
	yamm mem;
	mem.build(64);

	yamm other_mem;
	other_mem.build(64);

	yamm_buffer* app0 = new yamm_buffer(32);
	app0->set_name("APP0");
	app0->set_start_addr(0);
	check(mem.allocate(app0, YAMM_FIRST_FIT), "Failed to allocate APP0");

	yamm_buffer* app1 = new yamm_buffer(32);
	app1->set_name("APP1");
	check(mem.allocate(app1, YAMM_FIRST_FIT), "Failed to allocate APP1");

	yamm_buffer* child = new yamm_buffer(8);
	child->set_name("CHILD");
	check(app0->allocate(child, YAMM_FIRST_FIT), "Failed to allocate CHILD inside APP0");

	check(mem.check_address_space_consistency(), "Inconsistent before any deallocation");

	// ------------------------------------------------------------------
	// Case 1: child is a (depth-1) descendant of the caller.
	// mem.deallocate(child) must walk up the parent chain, delegate to
	// APP0 and free the buffer at its own level.
	// ------------------------------------------------------------------
	std::cout << "Case 1: deallocate a depth-1 child from the top level\n";
	bool ok = mem.deallocate(child);
	check(ok, "Ancestor deallocate of a child should have succeeded");
	// Note: deallocate() deletes the buffer object, so 'child' must not be
	// dereferenced from here on. Success + consistency below prove it was freed.
	check(mem.check_address_space_consistency(), "Inconsistent after ancestor deallocate");
	std::cout << mem.sprint(true, 0) << "\n";

	// ------------------------------------------------------------------
	// Case 1b: sole-child edge case — CHILD exactly fills APP0 so its
	// next and prev are both NULL inside APP0's list.  The ancestor-level
	// call must still succeed; the "not linked anywhere" guard must NOT
	// fire when the caller is not the direct owner.
	// ------------------------------------------------------------------
	std::cout << "Case 1b: deallocate a sole child (exact fit, next=NULL prev=NULL) from the top level\n";
	yamm_buffer* sole_child = new yamm_buffer(32);
	sole_child->set_name("SOLE_CHILD");
	check(app0->allocate(sole_child, YAMM_FIRST_FIT), "Failed to allocate SOLE_CHILD inside APP0");
	ok = mem.deallocate(sole_child);
	check(ok, "Ancestor deallocate of a sole child (exact fit) should have succeeded");
	check(mem.check_address_space_consistency(), "Inconsistent after ancestor deallocate of sole child");
	std::cout << mem.sprint(true, 0) << "\n";

	// Rebuild the same structure for the remaining cases.
	child = new yamm_buffer(8);
	child->set_name("CHILD");
	check(app0->allocate(child, YAMM_FIRST_FIT), "Failed to re-allocate CHILD inside APP0");

	// ------------------------------------------------------------------
	// Case 2a: child is NOT a descendant of the caller (sibling branch).
	// app1.deallocate(child) must warn and return 0, leaving everything
	// unchanged.
	// ------------------------------------------------------------------
	std::cout << "Case 2a: deallocate from a sibling level (not an ancestor)\n";
	ok = app1->deallocate(child);
	check(!ok, "Deallocate from a non-ancestor level should have failed");
	check(child->get_size() == 8, "Child was modified even though deallocation should have failed");
	check(mem.check_address_space_consistency(), "Inconsistent after rejected sibling deallocate");

	// ------------------------------------------------------------------
	// Case 2b: buffer belongs to a completely different memory object.
	// Allocate foreign_buf inside other_mem, then try to deallocate it
	// from mem (and vice-versa).  Both must warn and return 0, leaving
	// both memories fully intact.
	// ------------------------------------------------------------------
	std::cout << "Case 2b: deallocate a buffer from a foreign memory\n";
	yamm_buffer* foreign_buf = new yamm_buffer(8);
	foreign_buf->set_name("FOREIGN");
	check(other_mem.allocate(foreign_buf, YAMM_FIRST_FIT), "Failed to allocate FOREIGN inside other_mem");
	// mem must not be able to free a buffer that lives in other_mem
	ok = mem.deallocate(foreign_buf);
	check(!ok, "Deallocate of a foreign buffer from mem should have failed");
	check(foreign_buf->get_size() == 8, "FOREIGN was modified even though deallocation should have failed");
	check(mem.check_address_space_consistency(), "mem inconsistent after rejected foreign deallocate");
	check(other_mem.check_address_space_consistency(), "other_mem became inconsistent after rejected foreign deallocate");
	// other_mem must not be able to free a buffer that lives in mem
	ok = other_mem.deallocate(child);
	check(!ok, "Deallocate of a mem buffer from other_mem should have failed");
	check(child->get_size() == 8, "CHILD was modified even though deallocation should have failed");
	check(mem.check_address_space_consistency(), "mem inconsistent after reverse foreign deallocate");
	check(other_mem.check_address_space_consistency(), "other_mem inconsistent after reverse foreign deallocate");

	// ------------------------------------------------------------------
	// Case 3: give CHILD a child of its own and free CHILD from its direct
	// parent (APP0). In C++ there is no 'recursive' flag, so the call must
	// succeed and free the whole subtree (an info message is emitted because
	// the buffer contains other buffers).
	// ------------------------------------------------------------------
	yamm_buffer* grandchild = new yamm_buffer(4);
	grandchild->set_name("GRANDCHILD");
	check(child->allocate(grandchild, YAMM_FIRST_FIT), "Failed to allocate GRANDCHILD inside CHILD");

	std::cout << "Case 3: deallocate a buffer that still has children\n";
	ok = app0->deallocate(child);
	check(ok, "Deallocate of a buffer with children should have succeeded");
	// 'child' is deleted by deallocate(); success + consistency prove it was freed.
	check(mem.check_address_space_consistency(), "Inconsistent after deallocate of a buffer with children");
	std::cout << mem.sprint(true, 0) << "\n";

	// ------------------------------------------------------------------
	// Case 4: self-deallocation must be rejected. A level can only free
	// buffers that live in its own subtree; a buffer (or the memory root)
	// is not contained in itself, so both calls below must warn and return
	// 0 without corrupting anything.
	// ------------------------------------------------------------------
	std::cout << "Case 4a: a top-level buffer deallocating itself\n";
	ok = app0->deallocate(app0);
	check(!ok, "A buffer deallocating itself should have failed");
	check(app0->get_size() == 32, "APP0 was modified even though self-deallocation should have failed");
	check(mem.check_address_space_consistency(), "Inconsistent after rejected buffer self-deallocate");

	std::cout << "Case 4b: the memory root deallocating itself\n";
	ok = mem.deallocate(&mem);
	check(!ok, "The memory root deallocating itself should have failed");
	check(mem.get_size() == 64, "Memory size changed even though self-deallocation should have failed");
	check(mem.check_address_space_consistency(), "Inconsistent after rejected memory self-deallocate");

	// ------------------------------------------------------------------
	// Case 5: a child trying to free its own parent must be rejected.
	// APP1's parent chain does not lead through CHILD, so the call is
	// refused (no delegation upward). A fresh child is allocated for this
	// case because 'child' above was already freed by Case 3.
	// ------------------------------------------------------------------
	yamm_buffer* child2 = new yamm_buffer(8);
	child2->set_name("CHILD2");
	check(app0->allocate(child2, YAMM_FIRST_FIT), "Failed to allocate CHILD2 inside APP0");

	std::cout << "Case 5: a child deallocate()ing its own parent\n";
	ok = child2->deallocate(app1);
	check(!ok, "A child freeing its parent should have failed");
	check(app1->get_size() == 32, "APP1 was modified even though child-frees-parent should have failed");
	check(mem.check_address_space_consistency(), "Inconsistent after rejected child-frees-parent deallocate");

	// ------------------------------------------------------------------
	// Case 6: cross-level deallocate of a depth-2 buffer. MID lives two
	// levels below other_mem; the call must walk the parent chain and
	// delegate to the direct owner. (The buffer object is deleted by
	// deallocate(), so its handle must not be used afterwards.)
	// ------------------------------------------------------------------
	yamm_buffer* p = other_mem.allocate_by_size(40, YAMM_FIRST_FIT);
	check(p != NULL, "Failed to allocate P inside other_mem");
	if (p == NULL)
		return 1;
	yamm_buffer* mid = p->allocate_by_size(8, YAMM_FIRST_FIT);
	check(mid != NULL, "Failed to allocate MID inside P");
	if (mid == NULL)
		return 1;

	std::cout << "Case 6: deallocate a depth-2 buffer from the memory root\n";
	ok = other_mem.deallocate(mid);
	check(ok, "Ancestor deallocate of a depth-2 buffer should have succeeded");
	check(other_mem.check_address_space_consistency(), "other_mem inconsistent after depth-2 deallocate");

	// ------------------------------------------------------------------
	// Case 7: double allocation. A buffer that exactly fills its level
	// (next/prev null) is still allocated: it must not be allocatable a
	// second time into another level.
	// ------------------------------------------------------------------
	yamm_buffer* h1 = other_mem.allocate_by_size(8, YAMM_FIRST_FIT);
	yamm_buffer* h2 = other_mem.allocate_by_size(8, YAMM_FIRST_FIT);
	check(h1 != NULL && h2 != NULL, "Failed to allocate H1/H2");
	if (h1 == NULL || h2 == NULL)
		return 1;
	yamm_buffer* fill = new yamm_buffer(8);
	fill->set_name("FILL");
	check(h1->allocate(fill, YAMM_FIRST_FIT), "Failed to allocate FILL inside H1");

	std::cout << "Case 7: a buffer that fills its level can't be allocated twice\n";
	ok = h2->allocate(fill, YAMM_FIRST_FIT);
	check(!ok, "A buffer that fills its level was allocated a second time");
	check(fill->get_size() == 8, "FILL was modified even though the second allocation should have failed");
	check(other_mem.check_address_space_consistency(), "Inconsistent after rejected double allocation");
	// FILL is still a valid child of H1 and can be freed normally
	// (deallocate deletes the buffer object, so fill must not be used after)
	ok = h1->deallocate(fill);
	check(ok, "FILL should still be deallocatable from H1");

	// ------------------------------------------------------------------
	// Case 8: a never-allocated buffer can't be allocated inside itself
	// (or one of its descendants): that would create a parent loop and
	// make the ownership walk in deallocate() run forever.
	// ------------------------------------------------------------------
	yamm_buffer selfb(100);
	selfb.set_name("SELF_BUF");

	std::cout << "Case 8: a buffer can't be allocated inside itself\n";
	ok = selfb.allocate(&selfb, YAMM_FIRST_FIT);
	check(!ok, "A buffer was allocated inside itself (parent loop)");
	// The ownership walk in deallocate() must terminate for such a buffer
	ok = mem.deallocate(&selfb);
	check(!ok, "Self buffer was deallocated even though it was never allocated");
	check(mem.check_address_space_consistency(), "Inconsistent after rejected self-allocation");

	if (g_failures == 0) {
		std::cout << "All cross-level deallocate cases passed\n";
		return 0;
	} else {
		std::cerr << g_failures << " check(s) FAILED\n";
		return 1;
	}
}

#endif // __yamm_deallocate_level_test
