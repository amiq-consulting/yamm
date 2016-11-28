

`ifndef yamm_uvm_recursive_test
`define yamm_uvm_recursive_test


class yamm_uvm_recursive_test extends uvm_test;

	`uvm_component_utils(yamm_uvm_recursive_test)

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);

		super.build_phase(phase);

	endfunction

	task run_phase(uvm_phase phase);

		yamm memory = new;
		yamm_buffer handle;
		int i = 10;
		int j = 10;
		memory.build("new_memory", 1024*1024*1024);
		while(i--) begin
			handle = memory.allocate_by_size(1024*1024, UNIFORM_FIT);
			handle.set_name("PARENT_BUFFER");
			while(j--)
				handle.allocate_by_size(1024, UNIFORM_FIT);
			j = 10;
		end

		if(memory.check_address_space_consistency())
			`uvm_info("YAMM_RECURSIVE_INF", "Consistency checked!", UVM_NONE)
		else
			`uvm_fatal("YAMM_RECURSIVE_FATAL", "Consistency not checked!")

		$display(memory.sprint_buffer(1));
		memory.reset();
		$display("---------------------");
		$display("---------------------");
		$display("---------------------");
		$display(memory.sprint_buffer(1));

	endtask

endclass

`endif


