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

`ifndef __yamm_setup
`define __yamm_setup

`ifndef YAMM_ADDR_WIDTH
	// defines the address bus width
	`define YAMM_ADDR_WIDTH 32
`endif

/**
 * The supported allocation modes, used by buffer allocation operations
 */
typedef enum {RANDOM_FIT=0, FIRST_FIT_RND=1, BEST_FIT_RND=2, FIRST_FIT=3, BEST_FIT=4, UNIFORM_FIT=5 } yamm_allocation_mode_e;

/**
 * Direction for accesses, not used at the moment
 */
typedef enum {YAMM_RD=0, YAMM_WR=1} yamm_direction_e;

/**
 * The width in bits of a memory address, can be modified from YAMM_ADDR_WIDTH definition; default: 31 bits
 */
typedef bit[`YAMM_ADDR_WIDTH-1:0] yamm_addr_width;

/**
 * The width in bits of a memory size, can be modified from YAMM_ADDR_WIDTH definition; default: 32 bits
 */
typedef bit[`YAMM_ADDR_WIDTH:0] yamm_size_width;

`endif
