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

#ifndef __yamm_last_fit_test
#define __yamm_last_fit_test

#include <stdio.h>
#include <vector>

#include "yamm.h"
#include "test_utils.h"

using namespace yamm_ns;

// Allocates 'size' bytes aligned to 'align' with LAST_FIT inside 'level'; NULL on failure
static yamm_buffer* alloc_last(yamm_buffer* level, uint_64_t size, uint_32_t align = 1) {
	yamm_buffer* b = new yamm_buffer(size);
	b->set_start_addr_alignment(align);
	if (level->allocate(b, YAMM_LAST_FIT))
		return b;   // owned by the memory from now on
	delete b;   // never linked, so the test still owns it
	return NULL;
}

// Inserts an occupied buffer at a fixed address (builds known layouts)
static void insert_at(yamm_buffer* level, uint_64_t start, uint_64_t size) {
	yamm_buffer* b = new yamm_buffer(start, size);
	if (!level->insert(b)) {
		check(false, "insert_at failed");
		delete b;
	}
}

// Fails unless b was allocated at 'expected'; the consistency check exits on any error
static void expect_at(yamm* m, yamm_buffer* b, uint_64_t expected, const char* id) {
	char msg[160];
	snprintf(msg, sizeof msg, "%s: expected start 0x%llx, got %s0x%llx", id, expected,
			b ? "" : "(null) ", b ? b->get_start_addr() : 0ULL);
	check(b != NULL && b->get_start_addr() == expected, msg);
	check(m->check_address_space_consistency(), id);
}

// Map M1: occupied [0x000, 0x0FF] and [0x200, 0xFC7] in a fresh 0x1000
// Free regions: A = [0x100, 0x1FF] (0x100 bytes) and B = [0xFC8, 0xFFF] (0x38 bytes)
static void build_m1(yamm* m) {
	m->build(0x1000);
	insert_at(m, 0x000, 0x100);
	insert_at(m, 0x200, 0xdc8);
}

int main() {

	// D1 + D2: displacement + exact end, then the search starts at the tail
	{
		yamm m;
		m.build(0x1000);
		yamm_buffer* b1 = alloc_last(&m, 0x100);
		expect_at(&m, b1, 0xf00, "D1");
		yamm_buffer* b2 = alloc_last(&m, 0x100);
		expect_at(&m, b2, 0xe00, "D2");
	}

	// D3: displacement + middle (free [0xFFB, 0xFFF] after the buffer)
	{
		yamm m;
		m.build(0x1000);
		yamm_buffer* b = alloc_last(&m, 0x13, 8);
		expect_at(&m, b, 0xfe8, "D3");
	}

	// D4/D5: non-power-of-two alignment
	{
		yamm m;
		m.build(0x1000);
		yamm_buffer* b = alloc_last(&m, 0x11, 3);
		expect_at(&m, b, 0xfed, "D4");
	}
	{
		yamm m;
		m.build(0x1000);
		yamm_buffer* b = alloc_last(&m, 0x11, 6);
		expect_at(&m, b, 0xfea, "D5");
	}

	// D6: the top region is chosen
	{
		yamm m;
		build_m1(&m);
		yamm_buffer* b = alloc_last(&m, 0x30);
		expect_at(&m, b, 0xfd0, "D6");
	}

	// D7: the top region fails once aligned; shrink of region A
	{
		yamm m;
		build_m1(&m);
		yamm_buffer* b = alloc_last(&m, 0x30, 0x100);
		expect_at(&m, b, 0x100, "D7");
	}

	// D8: size guard, no unsigned wrap-around
	{
		yamm m;
		m.build(0x1000);
		yamm_buffer* b = alloc_last(&m, 0x1001);
		check(b == NULL, "D8: allocation of 0x1001 in a 0x1000 memory must fail");
		check(m.get_usage_statistics() == 0, "D8: usage changed after a failed allocation");
	}

	// D9: no region big enough
	{
		yamm m;
		build_m1(&m);
		yamm_buffer* b = alloc_last(&m, 0x101);
		check(b == NULL, "D9: 0x101 does not fit in M1");
	}

	// D10: exact fill, then a full level
	{
		yamm m;
		m.build(0x1000);
		yamm_buffer* b1 = alloc_last(&m, 0x1000);
		expect_at(&m, b1, 0x000, "D10a");
		yamm_buffer* b2 = alloc_last(&m, 0x1);
		check(b2 == NULL, "D10b: allocation in a full level must fail");
	}

	// S1: packing at scale (O(1) per search); buffer k at 0x10000 - k*16
	{
		yamm m;
		m.build(0x10000);
		std::vector<yamm_buffer*> bufs;
		bufs.reserve(4096);
		for (int k = 1; k <= 4096; k++) {
			yamm_buffer* b = alloc_last(&m, 0x10);
			uint_64_t expected = 0x10000 - (uint_64_t)k * 16;
			char msg[96];
			snprintf(msg, sizeof msg, "S1: buffer %d at %s0x%llx, expected 0x%llx", k,
					b ? "" : "(null) ", b ? b->get_start_addr() : 0ULL, expected);
			check(b != NULL && b->get_start_addr() == expected, msg);
			if (b)
				bufs.push_back(b);
			if (k % 256 == 0)
				check(m.check_address_space_consistency(), "S1: inconsistent");
		}
		check(m.check_address_space_consistency(), "S1: inconsistent at the end");
		check(alloc_last(&m, 0x10) == NULL, "S1: allocation in a full level must fail");
		// S9: soft_reset and hard_reset of the full memory
		m.soft_reset();
		expect_at(&m, alloc_last(&m, 0x10), 0xfff0, "S9a");
		m.hard_reset();
		expect_at(&m, alloc_last(&m, 0x10), 0xfff0, "S9b");
	}

	// S2: alignment slack, search skipping small regions; buffer k at 0x10000 - k*32
	{
		yamm m;
		m.build(0x10000);
		std::vector<yamm_buffer*> bufs;
		bufs.reserve(64);
		for (int k = 1; k <= 64; k++) {
			yamm_buffer* b = alloc_last(&m, 0x18, 0x10);
			uint_64_t expected = 0x10000 - (uint_64_t)k * 32;
			char msg[96];
			snprintf(msg, sizeof msg, "S2: buffer %d at %s0x%llx, expected 0x%llx", k,
					b ? "" : "(null) ", b ? b->get_start_addr() : 0ULL, expected);
			check(b != NULL && b->get_start_addr() == expected, msg);
			if (b)
				bufs.push_back(b);
		}
		check(m.check_address_space_consistency(), "S2: inconsistent");
	}

	// S3-S6: freeing and re-allocating from the tail
	{
		yamm m;
		m.build(0x10000);
		std::vector<yamm_buffer*> bufs(64);
		// Stack of 64 buffers of size 0x10: buffer k at 0x10000 - k*16
		for (int k = 0; k < 64; k++) {
			bufs[k] = alloc_last(&m, 0x10);
			check(bufs[k] != NULL, "S3: stack allocation failed");
		}
		// S3: free buffer 10 (0xFF60); the forward walk ends on an occupied node
		m.deallocate(bufs[9]);
		expect_at(&m, alloc_last(&m, 0x10), 0xff60, "S3");
		// S4: free buffer 20 then 21; merge() absorbs the old tail as the next neighbor
		m.deallocate(bufs[19]);
		m.deallocate(bufs[20]);
		expect_at(&m, alloc_last(&m, 0x20), 0xfeb0, "S4");
		// S5: free buffer 30 then 29; merge() absorbs the old tail as the previous neighbor
		m.deallocate(bufs[29]);
		m.deallocate(bufs[28]);
		expect_at(&m, alloc_last(&m, 0x20), 0xfe20, "S5");
		// S6: free buffer 1 (0xFFF0); the freed node is the last node of the level
		m.deallocate(bufs[0]);
		expect_at(&m, alloc_last(&m, 0x10), 0xfff0, "S6");
		check(m.check_address_space_consistency(), "S3-S6: inconsistent");
	}

	// S7/S8: nested levels (lazy init in both places)
	{
		yamm m;
		m.build(0x10000);
		// S7: lazy init in find_suitable_buffer()
		yamm_buffer* p = alloc_last(&m, 0x1000);
		expect_at(&m, p, 0xf000, "S7a");
		expect_at(&m, alloc_last(p, 0x100), 0xff00, "S7b");
		// S8: lazy init in insert()
		yamm_buffer* q = alloc_last(&m, 0x1000);
		expect_at(&m, q, 0xe000, "S8a");
		insert_at(q, 0xe000, 0x10);
		expect_at(&m, alloc_last(q, 0x10), 0xeff0, "S8b");
	}

	if (g_failures == 0) {
		std::cout << "All LAST_FIT cases passed\n";
		return 0;
	}
	std::cerr << g_failures << " check(s) FAILED\n";
	return 1;
}

#endif // __yamm_last_fit_test