

`ifndef yamm_uvm_fit_stress_test
`define yamm_uvm_fit_stress_test

// Unit test for alignment-related allocation bugs, covering every allocation
// mode of yamm_allocation_mode_e (the enum is iterated, never hard-coded).
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
//      bug-triggering values (large alignment relative to gap size);
//      default 200 iterations, override with +iterations=N
//
// Run:
//   xrun -sv -uvm -q +define+YAMM_USE_UVM \
//     +incdir+src/sv +incdir+examples/test \
//     src/sv/yamm_pkg.sv examples/test/yamm_test_pkg.sv \
//     examples/tb/yamm_uvm_testbench.sv -top yamm_uvm_testbench \
//     +UVM_TESTNAME=yamm_uvm_fit_stress_test -svseed 7

class yamm_uvm_fit_stress_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_fit_stress_test)

	// 64 KiB memory for every phase
	int MEM_SIZE = 'h10000;

	// ---------------- state shared across the phases ----------------
	int errs;
	int errs_mode[];
	int used_s[$];
	int used_sz[$];
	int g_s[$];
	int g_e[$];
	bit any_fit;
	int best_sz;
	int uni_sz;
	int last_start;

	function new(string name, uvm_component parent);
		yamm_allocation_mode_e m;
		super.new(name, parent);
		errs = 0;
		errs_mode = new[m.num()];
	endfunction

	// ---------------- reference model ----------------

	// Record a used range, keeping the list sorted by start address
	function void add_used(int s, int sz);
		int j;
		int t;
		used_s.push_back(s);
		used_sz.push_back(sz);
		j = used_s.size() - 1;
		while (j > 0 && (used_s[j-1] > used_s[j])) begin
			t = used_s[j]; used_s[j] = used_s[j-1]; used_s[j-1] = t;
			t = used_sz[j]; used_sz[j] = used_sz[j-1]; used_sz[j-1] = t;
			j--;
		end
	endfunction

	// Brute-force reference over the gaps between the used buffers
	function void compute_reference(int sz, int align);
		int fs;
		int fe;
		int a;
		int gs;
		g_s.delete();
		g_e.delete();
		fs = 0;
		for (int i = 0; i <= used_s.size(); i++) begin
			fe = (i < used_s.size()) ? used_s[i] - 1 : MEM_SIZE - 1;
			if (fe >= fs) begin
				g_s.push_back(fs);
				g_e.push_back(fe);
			end
			if (i < used_s.size())
				fs = used_s[i] + used_sz[i];
		end
		any_fit = 0;
		best_sz = -1;
		uni_sz  = -1;
		last_start = -1;
		foreach (g_s[i]) begin
			a  = ((g_s[i] + align - 1) / align) * align;
			gs = g_e[i] - g_s[i] + 1;
			if (a + sz - 1 <= g_e[i]) begin
				any_fit = 1;
				if ((best_sz < 0) || (gs < best_sz))
					best_sz = gs;
				if (gs > uni_sz)
					uni_sz = gs;
				// Gaps are visited in ascending order, so the last write
				// belongs to the highest fitting gap (LAST_FIT)
				last_start = ((g_e[i] - sz + 1) / align) * align;
			end
		end
	endfunction

	// Rebuild a fresh, identical map from the recorded used ranges
	function yamm build_map();
		yamm m = new;
		m.build("mem", MEM_SIZE);
		for (int i = 0; i < used_s.size(); i++) begin
			yamm_buffer ub = new;
			ub.set_start_addr(used_s[i]);
			ub.set_size(used_sz[i]);
			if (!m.insert(ub))
				`uvm_fatal("FIT_STRESS_FATAL", $sformatf("Failed to re-insert used buffer at 0x%0h", used_s[i]))
		end
		return m;
	endfunction

	// Load the used buffers of a directed scenario (scen 1..3)
	function void load_scenario(int scen);
		used_s.delete();
		used_sz.delete();
		if (scen == 1) begin
			// free: A @0x0800..0x08ff (0x100, 512-aligned start -> fits)
			//       B @0x1ac8..0x1bff (0x138, next 512-aligned addr 0x1c00 is past its end)
			add_used('h0,    'h800);
			add_used('h900,  'h11c8);
			add_used('h1c00, 'he400);
		end
		else if (scen == 2) begin
			// free: A @0x0800..0x08ff (0x100, fits)
			//       B @0x2000..0x20ff (0x100, fits)
			//       C @0x2ac8..0x2bff (0x138, does NOT fit 512-aligned)
			add_used('h0,    'h800);
			add_used('h900,  'h1700);
			add_used('h2100, 'h9c8);
			add_used('h2c00, 'hd400);
		end
		else begin
			// free: A @0x0800..0x08ff (0x100, fits)
			//       B @0x2000..0x20ff (0x100, fits)
			//       C @0x2a40..0x2b3f (0x100, does NOT fit 512-aligned)
			add_used('h0,    'h800);
			add_used('h900,  'h1700);
			add_used('h2100, 'h940);
			add_used('h2b40, 'hd4c0);
		end
	endfunction

	// ---------------- error reporting ----------------

	function void fail(yamm_allocation_mode_e mode, string ctx, string what);
		errs++;
		errs_mode[mode]++;
		if (errs <= 40)
			`uvm_error("FIT_STRESS", $sformatf("%s mode=%-13s: %s", ctx, mode.name(), what))
	endfunction

	function string mode_summary();
		string s;
		yamm_allocation_mode_e m;
		foreach (errs_mode[i]) begin
			m = yamm_allocation_mode_e'(i);
			s = {s, $sformatf(" %s=%0d", m.name(), errs_mode[i])};
		end
		return s;
	endfunction

	// Check one allocation against the reference; returns "" when valid
	function string check_alloc(int align, int sz, bit ok, yamm_buffer b, yamm_allocation_mode_e mode);
		int bs;
		int be;
		int gsz;
		if (!ok) begin
			if (any_fit)
				return "allocate() returned 0 although an aligned fit exists";
			return "";
		end
		bs = int'(b.get_start_addr());
		be = bs + sz - 1;
		if (bs % align != 0)
			return $sformatf("start addr 0x%0h is not %0d-aligned", bs, align);
		if ((be >= MEM_SIZE) || (be < bs))
			return $sformatf("buffer 0x%0h..0x%0h is outside the memory", bs, be);
		// The buffer must lie completely inside exactly one free gap
		gsz = -1;
		foreach (g_s[i]) begin
			if ((bs >= g_s[i]) && (be <= g_e[i]))
				gsz = g_e[i] - g_s[i] + 1;
		end
		if (gsz < 0)
			return $sformatf("buffer 0x%0h..0x%0h does not lie inside a single free gap", bs, be);
		if (((mode == BEST_FIT) || (mode == BEST_FIT_RND)) && (gsz != best_sz))
			return $sformatf("picked a gap of size 0x%0h, the smallest fitting gap is 0x%0h", gsz, best_sz);
		if ((mode == UNIFORM_FIT) && (gsz != uni_sz))
			return $sformatf("picked a gap of size 0x%0h, the largest fitting gap is 0x%0h", gsz, uni_sz);
		if ((mode == LAST_FIT) && (bs != last_start))
			return $sformatf("LAST_FIT expected start 0x%0h, got 0x%0h", last_start, bs);
		return "";
	endfunction

	// ---------------- phase 0: directed scenarios ----------------
	// All modes, size 0xc8, alignment 512 (bug-triggering) and 1 (reference).
	// Scenario 1 has a unique smallest fitting gap, so BEST_FIT must
	// deterministically return 0x800.
	task phase0();
		yamm m;
		yamm_buffer b;
		yamm_allocation_mode_e mode;
		string err;
		bit ok;
		// Hand-checked LAST_FIT values, [scen-1][ai]; ai 0 = align 1, ai 1 = align 512.
		// In the SV scenarios all used ranges reach 0xFFFF, so the highest gaps
		// are: scen1 B [0x1AC8, 0x1BFF] (fails 512-aligned, then A),
		// scen2 C [0x2AC8, 0x2BFF] (fails 512-aligned, then B),
		// scen3 C [0x2A40, 0x2B3F] (fails 512-aligned, then B)
		int last_exp[3][2] = '{'{'h1b38, 'h800}, '{'h2b38, 'h2000}, '{'h2a78, 'h2000}};
		for (int scen = 1; scen <= 3; scen++) begin
			load_scenario(scen);
			for (int ai = 0; ai < 2; ai++) begin
				int al = (ai == 1) ? 512 : 1;
				compute_reference('hc8, al);
				for (int mi = 0; mi < mode.num(); mi++) begin
					mode = yamm_allocation_mode_e'(mi);
					m = build_map();
					b = new;
					b.set_size('hc8);
					b.set_start_addr_alignment(al);
					ok = m.allocate(b, mode);
					err = check_alloc(al, 'hc8, ok, b, mode);
					if ((err == "") && ok && !m.check_address_space_consistency())
						err = "map inconsistent after allocate";
					if (err != "")
						fail(mode, $sformatf("P0 scen%0d align%0d", scen, al), err);
					if ((scen == 1) && (mode == BEST_FIT) && ok && (int'(b.get_start_addr()) != 'h800))
						fail(mode, $sformatf("P0 scen%0d align%0d", scen, al),
							$sformatf("BEST_FIT expected addr 0x800, got 0x%0h", b.get_start_addr()));
					if ((mode == LAST_FIT) && ok && (int'(b.get_start_addr()) != last_exp[scen-1][ai]))
						fail(mode, $sformatf("P0 scen%0d align%0d", scen, al),
							$sformatf("LAST_FIT expected addr 0x%0h, got 0x%0h", last_exp[scen-1][ai], b.get_start_addr()));
				end
			end
		end
	endtask

	// ---------------- phase 1: deterministic sweep ----------------
	// All scenarios x all modes x a grid of alignments and sizes.
	task phase1();
		yamm m;
		yamm_buffer b;
		yamm_allocation_mode_e mode;
		int aligns[5] = '{1, 16, 256, 1024, 4096};
		int sizes[3]  = '{1, 'h100, 'h300};
		string err;
		bit ok;
		for (int scen = 1; scen <= 3; scen++) begin
			load_scenario(scen);
			for (int ai = 0; ai < 5; ai++) begin
				for (int si = 0; si < 3; si++) begin
					compute_reference(sizes[si], aligns[ai]);
					for (int mi = 0; mi < mode.num(); mi++) begin
						mode = yamm_allocation_mode_e'(mi);
						m = build_map();
						b = new;
						b.set_size(sizes[si]);
						b.set_start_addr_alignment(aligns[ai]);
						ok = m.allocate(b, mode);
						err = check_alloc(aligns[ai], sizes[si], ok, b, mode);
						if ((err == "") && ok && !m.check_address_space_consistency())
							err = "map inconsistent after allocate";
						if (err != "")
							fail(mode, $sformatf("P1 scen%0d align%0d size0x%0h", scen, aligns[ai], sizes[si]), err);
					end
				end
			end
		end
	endtask

	// ---------------- phase 2: randomized stress ----------------
	// Fragment a fresh map, then run every mode against the reference.
	// The alignment distribution is biased toward bug-triggering values:
	// 80% power-of-two in 2^3..2^10, 20% in 2^0..2^2.
	task phase2(int iters);
		yamm frag;
		yamm m;
		yamm_buffer fb;
		yamm_buffer b;
		yamm_allocation_mode_e mode;
		string err;
		bit ok;
		for (int it = 0; it < iters; it++) begin
			int e;
			int al;
			int sz;
			// Fragment the memory
			used_s.delete();
			used_sz.delete();
			frag = new;
			frag.build("frag", MEM_SIZE);
			frag.disable_warnings = 1;
			for (int n = $urandom_range(40, 5); n > 0; n--) begin
				fb = new;
				fb.set_size($urandom_range('h300, 1));
				if (frag.allocate(fb, RANDOM_FIT))
					add_used(int'(fb.get_start_addr()), int'(fb.get_size()));
			end
			// Biased power-of-two alignment, small random size
			e  = ($urandom_range(99, 0) < 80) ? $urandom_range(10, 3) : $urandom_range(2, 0);
			al = 1 << e;
			sz = $urandom_range('h200, 1);
			compute_reference(sz, al);
			for (int mi = 0; mi < mode.num(); mi++) begin
				mode = yamm_allocation_mode_e'(mi);
				m = build_map();
				b = new;
				b.set_size(sz);
				b.set_start_addr_alignment(al);
				ok = m.allocate(b, mode);
				err = check_alloc(al, sz, ok, b, mode);
				if ((err == "") && ok && !m.check_address_space_consistency())
					err = "map inconsistent after allocate";
				if (err != "") begin
					fail(mode, $sformatf("P2 it%0d align%0d size0x%0h", it, al, sz), err);
				end
				else if (ok) begin
					void'(m.deallocate(b));
					if (!m.check_address_space_consistency())
						fail(mode, $sformatf("P2 it%0d align%0d size0x%0h", it, al, sz),
							"map inconsistent after allocate/deallocate");
				end
			end
		end
	endtask

	// ---------------- top level ----------------
	task run_phase(uvm_phase phase);
		int iters;
		iters = 200;
		void'($value$plusargs("iterations=%d", iters));
		`uvm_info("FIT_STRESS", $sformatf("Starting fit-stress test with %0d randomized iterations", iters), UVM_LOW)
		phase0();
		phase1();
		phase2(iters);
		`uvm_info("FIT_STRESS", $sformatf("Per-mode errors:%s", mode_summary()), UVM_LOW)
		if (errs > 0)
			`uvm_error("FIT_STRESS", $sformatf("FIT_STRESS FAILED: %0d error(s) detected", errs))
		else
			`uvm_info("FIT_STRESS", "FIT_STRESS PASSED: 0 errors detected", UVM_LOW)
	endtask

endclass

`endif
