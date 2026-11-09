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

// Unit test for alignment-related allocation bugs, covering every allocation
// mode (the enum is iterated, never hard-coded). C++ counterpart of
// examples/test/yamm_uvm_fit_stress_test.sv - same scenarios, same checks.
//
// Every allocation is checked against a brute-force reference model built
// from the gaps between the used buffers:
//   - allocate() succeeds iff some gap can hold the size at an aligned address
//   - the allocated buffer is aligned and lies completely inside one gap
//   - BEST_FIT / BEST_FIT_RND use the smallest gap that fits
//   - UNIFORM_FIT uses the largest gap that fits
//   - LAST_FIT starts at floor_align(gap_end - size + 1) of the highest fitting gap
//
// Phases (each iterating the full enum over a range of sizes and alignments):
//   0: deterministic directed scenarios with known free-gap layouts
//   1: deterministic sweep of layout x alignment x size
//   2: randomized stress with the alignment distribution biased toward
//      bug-triggering values (large alignment relative to gap size)
//
// Build:
//   g++ -std=c++11 -Isrc/cpp examples/cpp_tests/yamm_fit_stress_test.cpp
//       src/cpp/*.cpp -o fit_stress
// Usage:
//   ./fit_stress [iterations] [seed]        (defaults: 200, 1)

#ifndef __yamm_fit_stress_test
#define __yamm_fit_stress_test

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>
#include <algorithm>

#include "yamm.h"

using namespace yamm_ns;

static const uint_64_t MEM_SIZE = 0x10000;

struct range_t { uint_32_t s; uint_32_t e; };

struct ref_t {
	bool any_fit;
	uint_64_t best_sz;
	uint_64_t uni_sz;
	uint_64_t last_start;
	std::vector<range_t> gaps;
};

static int g_errs = 0;
static int g_errs_mode[YAMM_NUM_ALLOC_MODES] = {0};

static const char* mname(int m) {
	static const char* n[] = {"RANDOM_FIT", "FIRST_FIT_RND", "BEST_FIT_RND",
			"FIRST_FIT", "BEST_FIT", "UNIFORM_FIT", "LAST_FIT"};
	static_assert(sizeof(n) / sizeof(n[0]) == YAMM_NUM_ALLOC_MODES,
			"mname() must name every allocation mode");
	return n[m];
}

static void fail(int mode, const char* ctx, const std::string& what) {
	g_errs++;
	g_errs_mode[mode]++;
	if (g_errs <= 40)
		printf("%s mode=%-13s: %s\n", ctx, mname(mode), what.c_str());
}

static std::string mode_summary() {
	char buf[512];
	int off = 0;
	for (int i = 0; i < YAMM_NUM_ALLOC_MODES; i++)
		off += snprintf(buf + off, sizeof(buf) - off, " %s=%d", mname(i), g_errs_mode[i]);
	return std::string(buf);
}

static void add_used(std::vector<range_t>& used, uint_32_t s, uint_32_t e) {
	used.push_back({s, e});
	std::sort(used.begin(), used.end(), [](const range_t& a, const range_t& b) {
			return a.s < b.s;
		});
}

// Brute-force reference over the gaps between the used buffers
static void compute_reference(const std::vector<range_t>& used, uint_64_t sz,
		uint_32_t align, ref_t& ref) {
	// Half-open [fs, fe) arithmetic so a used buffer at address 0 cannot
	// underflow the gap start.
	uint_64_t fs = 0;
	ref.gaps.clear();
	for (size_t i = 0; i <= used.size(); i++) {
		uint_64_t fe = (i < used.size()) ? used[i].s : MEM_SIZE;
		if (fe > fs)
			ref.gaps.push_back({(uint_32_t)fs, (uint_32_t)(fe - 1)});
		if (i < used.size())
			fs = (uint_64_t)used[i].e + 1;
	}
	ref.any_fit = false;
	ref.best_sz = 0;
	ref.uni_sz  = 0;
	ref.last_start = 0;
	for (size_t i = 0; i < ref.gaps.size(); i++) {
		uint_64_t a = ((ref.gaps[i].s + align - 1) / align) * align;
		uint_64_t gs = (uint_64_t)ref.gaps[i].e - ref.gaps[i].s + 1;
		if (a + sz - 1 <= ref.gaps[i].e) {
			ref.any_fit = true;
			if (ref.best_sz == 0 || gs < ref.best_sz)
				ref.best_sz = gs;
			if (gs > ref.uni_sz)
				ref.uni_sz = gs;
			// Gaps are visited in ascending order, so the last write
			// belongs to the highest fitting gap (LAST_FIT)
			ref.last_start = ((uint_64_t)ref.gaps[i].e - sz + 1) / align * align;
		}
	}
}

// Check one allocation against the reference; returns "" when valid
static std::string check_alloc(uint_32_t align, uint_64_t sz, bool ok,
		yamm_buffer* b, int mode, const ref_t& ref) {
	if (!ok)
		return ref.any_fit ? "allocate() returned 0 although an aligned fit exists" : "";
	uint_64_t bs = b->get_start_addr();
	uint_64_t be = bs + sz - 1;
	char buf[128];
	if (bs % align) {
		snprintf(buf, sizeof buf, "start addr 0x%llx is not %u-aligned",
				(unsigned long long)bs, align);
		return buf;
	}
	if (be >= MEM_SIZE || be < bs) {
		snprintf(buf, sizeof buf, "buffer 0x%llx..0x%llx is outside the memory",
				(unsigned long long)bs, (unsigned long long)be);
		return buf;
	}
	// The buffer must lie completely inside exactly one free gap
	uint_64_t gsz = 0;
	bool in_gap = false;
	for (size_t i = 0; i < ref.gaps.size(); i++) {
		if (bs >= ref.gaps[i].s && be <= ref.gaps[i].e) {
			in_gap = true;
			gsz = (uint_64_t)ref.gaps[i].e - ref.gaps[i].s + 1;
		}
	}
	if (!in_gap) {
		snprintf(buf, sizeof buf, "buffer 0x%llx..0x%llx does not lie inside a single free gap",
				(unsigned long long)bs, (unsigned long long)be);
		return buf;
	}
	if ((mode == YAMM_BEST_FIT || mode == YAMM_BEST_FIT_RND) && gsz != ref.best_sz) {
		snprintf(buf, sizeof buf, "picked a gap of size 0x%llx, the smallest fitting gap is 0x%llx",
				(unsigned long long)gsz, (unsigned long long)ref.best_sz);
		return buf;
	}
	if (mode == YAMM_UNIFORM_FIT && gsz != ref.uni_sz) {
		snprintf(buf, sizeof buf, "picked a gap of size 0x%llx, the largest fitting gap is 0x%llx",
				(unsigned long long)gsz, (unsigned long long)ref.uni_sz);
		return buf;
	}
	if (mode == YAMM_LAST_FIT && bs != ref.last_start) {
		snprintf(buf, sizeof buf, "LAST_FIT expected start 0x%llx, got 0x%llx",
				(unsigned long long)ref.last_start, (unsigned long long)bs);
		return buf;
	}
	return "";
}

// Load the used buffers of a directed scenario (scen 1..3)
static void load_scenario(int scen, std::vector<range_t>& used) {
	used.clear();
	if (scen == 1) {
		// free: A @0x0800..0x08ff (0x100, 512-aligned start -> fits)
		//       B @0x1ac8..0x1bff (0x138, next 512-aligned addr 0x1c00 is past its end)
		add_used(used, 0x0, 0x7ff);
		add_used(used, 0x900, 0x1ac7);
		add_used(used, 0x1c00, 0x9fff);
	} else if (scen == 2) {
		// free: A @0x0800..0x08ff (0x100, fits)
		//       B @0x2000..0x20ff (0x100, fits)
		//       C @0x2ac8..0x2bff (0x138, does NOT fit 512-aligned)
		add_used(used, 0x0, 0x7ff);
		add_used(used, 0x900, 0x1fff);
		add_used(used, 0x2100, 0x2ac7);
		add_used(used, 0x2c00, 0xffff);
	} else {
		// free: A @0x0800..0x08ff (0x100, fits)
		//       B @0x2000..0x20ff (0x100, fits)
		//       C @0x2a40..0x2b3f (0x100, does NOT fit 512-aligned)
		add_used(used, 0x0, 0x7ff);
		add_used(used, 0x900, 0x1fff);
		add_used(used, 0x2100, 0x2a3f);
		add_used(used, 0x2b40, 0xffff);
	}
}

// Rebuild a fresh, identical map from the recorded used ranges
static yamm* build_map(const std::vector<range_t>& used) {
	yamm* m = new yamm();
	m->build(MEM_SIZE);
	m->disable_warnings = 1;
	for (size_t i = 0; i < used.size(); i++) {
		yamm_buffer* ub = new yamm_buffer();
		ub->set_start_addr(used[i].s);
		ub->set_size((uint_64_t)used[i].e - used[i].s + 1);
		if (!m->insert(ub)) {
			printf("re-insert failed at 0x%x\n", used[i].s);
			exit(2);
		}
	}
	return m;
}

// Run one allocation in the given mode against the reference; returns true
// on error. On error the map is leaked on purpose: a corrupted map (e.g. an
// out-of-range start address) may crash or hang in the yamm destructor.
// Note: the allocated buffer belongs to the map once allocate() succeeds, so
// only the map is ever deleted (its destructor cleans up the whole tree).
static bool g_trace = false;

static bool run_one(const char* ctx, const std::vector<range_t>& used,
		uint_64_t sz, uint_32_t align, int mode, const ref_t& ref,
		bool check_consistency, uint_64_t* start_out = 0) {
	yamm* m = build_map(used);
	yamm_buffer* b = new yamm_buffer();
	b->set_size(sz);
	b->set_start_addr_alignment(align);
	if (g_trace)
		printf("trace: %s mode=%s sz=0x%llx align=%u\n", ctx, mname(mode),
				(unsigned long long)sz, align);
	bool ok = m->allocate(b, mode);
	if (!ok) {
		delete b; // allocate() leaves the buffer owned by the caller on failure
		b = NULL;
	}
	if (start_out && ok)
		*start_out = b->get_start_addr();
	std::string err = check_alloc(align, sz, ok, b, mode, ref);
	bool error = !err.empty();
	if (!error && ok && !m->check_address_space_consistency()) {
		err = "map inconsistent after allocate";
		error = true;
		// b is intentionally left allocated inside m: a corrupted map may
		// crash or loop in deallocate(). The map is leaked on the error
		// path (see comment above run_one) so b is cleaned up with it.
	}
	if (!error && ok && check_consistency) {
		m->deallocate(b);
		if (!m->check_address_space_consistency()) {
			err = "map inconsistent after allocate/deallocate";
			error = true;
		}
	}
	if (error) {
		fail(mode, ctx, err);
		return true;
	}
	delete m;
	return false;
}

// Phase 0: deterministic directed scenarios, all modes, size 0xc8,
// alignment 512 (bug-triggering) and 1 (reference). Scenario 1 has a unique
// smallest fitting gap, so BEST_FIT must deterministically return 0x800.
static void phase0() {
	std::vector<range_t> used;
	const uint_32_t aligns[2] = {1, 512};
	// Hand-checked LAST_FIT values, [scen-1][ai]; ai 0 = align 1, ai 1 = align 512.
	// Scenario 1's used ranges stop at 0x9FFF, so the top gap [0xA000, 0xFFFF]
	// is chosen there (0xFF38 / floor512 -> 0xFE00); scenarios 2 and 3 are
	// used up to 0xFFFF, so the highest gaps are C (0x2AC8..0x2BFF) and C
	// (0x2A40..0x2B3F) respectively.
	static const uint_64_t last_exp[3][2] = {{0xff38, 0xfe00}, {0x2b38, 0x2000},
			{0x2a78, 0x2000}};
	for (int scen = 1; scen <= 3; scen++) {
		load_scenario(scen, used);
		for (int ai = 0; ai < 2; ai++) {
			uint_32_t al = aligns[ai];
			ref_t ref;
			compute_reference(used, 0xc8, al, ref);
			char ctx[64];
			snprintf(ctx, sizeof ctx, "P0 scen%d align%u", scen, al);
			for (int mi = 0; mi < YAMM_NUM_ALLOC_MODES; mi++) {
				uint_64_t start = 0;
				bool err = run_one(ctx, used, 0xc8, al, mi, ref, false, &start);
				if (!err && scen == 1 && mi == YAMM_BEST_FIT && start != 0x800)
					fail(mi, ctx, "BEST_FIT expected addr 0x800");
				if (!err && mi == YAMM_LAST_FIT && start != last_exp[scen - 1][ai])
					fail(mi, ctx, "LAST_FIT start differs from the hand-checked value");
			}
		}
	}
}

// Phase 1: deterministic sweep of all scenarios x all modes x a grid of
// alignments and sizes.
static void phase1() {
	std::vector<range_t> used;
	const uint_32_t aligns[5] = {1, 16, 256, 1024, 4096};
	const uint_64_t sizes[3] = {1, 0x100, 0x300};
	for (int scen = 1; scen <= 3; scen++) {
		load_scenario(scen, used);
		for (int ai = 0; ai < 5; ai++) {
			for (int si = 0; si < 3; si++) {
				ref_t ref;
				compute_reference(used, sizes[si], aligns[ai], ref);
				char ctx[80];
				snprintf(ctx, sizeof ctx, "P1 scen%d align%u size0x%llx",
						scen, aligns[ai], (unsigned long long)sizes[si]);
				for (int mi = 0; mi < YAMM_NUM_ALLOC_MODES; mi++)
					run_one(ctx, used, sizes[si], aligns[ai], mi, ref, false);
			}
		}
	}
}

// Phase 2: randomized stress. Fragment a fresh map, then run every mode
// against the reference. The alignment distribution is biased toward
// bug-triggering values: 80% power-of-two in 2^3..2^10, 20% in 2^0..2^2.
static void phase2(int iters) {
	for (int it = 0; it < iters; it++) {
		// Fragment the memory
		std::vector<range_t> used;
		yamm* frag = new yamm();
		frag->build(MEM_SIZE);
		frag->disable_warnings = 1;
		int n = 5 + rand() % 36;
		for (int k = 0; k < n; k++) {
			yamm_buffer* fb = new yamm_buffer();
			fb->set_size(1 + rand() % 0x300);
			if (frag->allocate(fb, YAMM_RANDOM_FIT))
				add_used(used, (uint_32_t)fb->get_start_addr(),
						(uint_32_t)fb->get_end_addr());
			else
				delete fb;
		}
		delete frag;
		// Biased power-of-two alignment, small random size
		int e = (rand() % 100 < 80) ? 3 + rand() % 8 : rand() % 3;
		uint_32_t al = 1u << e;
		uint_64_t sz = 1 + rand() % 0x200;
		ref_t ref;
		compute_reference(used, sz, al, ref);
		char ctx[80];
		snprintf(ctx, sizeof ctx, "P2 it%d align%u size0x%llx",
				it, al, (unsigned long long)sz);
		for (int mi = 0; mi < YAMM_NUM_ALLOC_MODES; mi++)
			run_one(ctx, used, sz, al, mi, ref, true);
	}
}

int main(int argc, char** argv) {
	int iters = (argc > 1) ? atoi(argv[1]) : 200;
	int seed = (argc > 2) ? atoi(argv[2]) : 1;
	srand(seed);
	setvbuf(stdout, NULL, _IONBF, 0);
	g_trace = getenv("FIT_STRESS_TRACE") != NULL;
	printf("FIT_STRESS: %d randomized iterations, seed %d\n", iters, seed);
	phase0();
	phase1();
	phase2(iters);
	printf("Per-mode errors:%s\n", mode_summary().c_str());
	if (g_errs > 0) {
		printf("FIT_STRESS FAILED: %d error(s) detected\n", g_errs);
		return 1;
	}
	printf("FIT_STRESS PASSED: 0 errors detected\n");
	return 0;
}

#endif // __yamm_fit_stress_test


