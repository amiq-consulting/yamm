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

`include "uvm_macros.svh"

/**
 * A test used to measure performance against MAM for 5000 allocations
 */
module yamm_vs_mam_test;

	import uvm_pkg::*;
	import yamm_pkg::*;

	initial begin

		allocate_using_mam(5000, 1024*1024*1024);

		allocate_using_yamm(5000, 1024*1024*1024);

	end


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
				$display("There is a problem with MAM allocation.");

		end

		fd = $fopen("time_log","r");
		$system("date +\"%s\" > time_log");
		$fscanf(fd,"%d",delta_time);
		$fclose(fd);
		delta_time -= time1;
		$display("Time taken for %d allocations using MAM: %d seconds", nr_alloc, delta_time);

	endtask

	task automatic allocate_using_yamm(int nr_alloc, yamm_addr_width memory_size);
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
				$display("There is a problem with YAMM allocation.");

		end

		$system("date +\"%s\" > time_log");
		fd = $fopen("time_log", "r");
		$fscanf(fd,"%d",delta_time);
		$fclose(fd);
		delta_time -= time1;
		$display("Time taken for %d allocations using YAMM: %d seconds", nr_alloc, delta_time);

		mem.print_stats();
	endtask

endmodule