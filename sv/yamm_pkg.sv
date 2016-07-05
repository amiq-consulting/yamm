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

/**
 * YAMM package that contains all yamm classes.
 * By default YAMM package is not UVM compliant (all classes are pure SV objects and no UVM API is called). 
 * You can define at compile time `YAMM_USE_UVM to make it UVM compliant (classes inherit uvm_object and UVM messaging is used).  
 */
package yamm_pkg;
	
	`ifdef YAMM_USE_UVM
		`include "uvm_macros.svh"
		import uvm_pkg::*;
	`endif
	
	// basic macros and enumerations
	`include "yamm_setup.svh"
	
	// base classes headers
	`include "yamm_access.svh"
	`include "yamm_buffer.svh"	
	`include "yamm.svh"
	
	// API implementations
	`include "yamm_buffer_get_buffers.sv"
	`include "yamm_buffer_locals.sv"
	`include "yamm_buffer_deallocate.sv"
	`include "yamm_buffer_allocate.sv"
	`include "yamm_buffer_insert.sv"
	`include "yamm_buffer_debug.sv"
	`include "yamm_buffer_other.sv"
	`include "yamm_buffer_contents.sv"
	
endpackage
