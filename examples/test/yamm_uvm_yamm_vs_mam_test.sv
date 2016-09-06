

`ifndef __yamm_uvm_yamm_vs_mam_test
`define __yamm_uvm_yamm_vs_mam_test


class yamm_uvm_yamm_vs_mam_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_yamm_vs_mam_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		allocate_using_mam(5000, 1024*1024*1024);

		allocate_using_yamm(5000, 1024*1024*1024);

	endtask

	task automatic allocate_using_mam(int nr_alloc,longint memory_size);
		int fd;
		int allocs_to_do = nr_alloc;
		longint time1, delta_time;

		uvm_mem_mam_cfg my_cfg= new();
		uvm_mem my_mem = new("my_mem", memory_size, 32);
		uvm_mem_mam my_mam = new("my_mam", my_cfg, my_mem);
		my_cfg.n_bytes = 1;
		my_cfg.start_offset = 0;
		my_cfg.end_offset = memory_size;

		$system("date +\"%s\" > time_log");
		fd = $fopen("time_log","r");
		$fscanf(fd,"%d",time1);
		$fclose(fd);

		while(allocs_to_do--) begin

			if(my_mam.request_region(100) == null)
				`uvm_error("YAMM_VS_MAM_TEST", "There is a problem with MAM allocation.")

		end

		fd = $fopen("time_log","r");
		$system("date +\"%s\" > time_log");
		$fscanf(fd,"%d",delta_time);
		$fclose(fd);
		delta_time -= time1;
		`uvm_info("YAMM_VS_MAM_TEST", $sformatf("Time taken for %d allocations using MAM: %d seconds", nr_alloc, delta_time), UVM_NONE)

	endtask

	task automatic allocate_using_yamm(int nr_alloc, yamm_addr_width_t memory_size);
		int fd;
		int allocs_to_do = nr_alloc;
		longint time1, delta_time;
		yamm mem = new;
		mem.build("Name", memory_size);
		mem.reset();

		$system("date +\"%s\" > time_log");
		fd = $fopen("time_log","r");
		$fscanf(fd,"%d",time1);
		$fclose(fd);

		while(allocs_to_do--) begin

			if(!mem.allocate_by_size(100, RANDOM_FIT))
				`uvm_error("YAMM_VS_MAM_TEST", "There is a problem with YAMM allocation.")

		end

		$system("date +\"%s\" > time_log");
		fd = $fopen("time_log", "r");
		$fscanf(fd,"%d",delta_time);
		$fclose(fd);
		delta_time -= time1;
		`uvm_info("YAMM_VS_MAM_TEST", $sformatf("Time taken for %d allocations using YAMM: %d seconds", nr_alloc, delta_time), UVM_NONE)

		mem.print_stats();
	endtask


endclass

`endif

