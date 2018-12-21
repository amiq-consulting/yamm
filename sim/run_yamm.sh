#!/bin/bash
 #########################################################################################
 # (C) Copyright 2016 AMIQ Consulting
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 # http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 #
 # NAME:        run_yamm.sh
 # PROJECT:     YAMM
 # Description: Script example to compile and run simulation with different simulators
 # Usage:  run_yamm.sh    [-tool          { ius | questa | vcs} ]                                   --> specify what simulator to use (default: ${default_tool})"
 #			  [-top		  {TOP_MODULE_NAME} ]					    --> name of the module
 #			  [-path	  {PATH} ]					            --> path to file relative to {PROJ_HOME}
 #
 #         run_yamm.sh    -h[elp]                                                                   --> print this message"
 # Example of using : ./run_yamm.sh -tool ius -uvm uvm1.2 -f examples/ex_apb/apb_files.f -top apb_top -test x_z_ts -i -c yes  
 # Example of using : ./run_yamm.sh -reg
 #########################################################################################

##########################################################################################
#  Setting the variables
##########################################################################################
# Setting the SCRIPT_DIR variable used to find out where the script is stored

SCRIPT_DIR=`pwd`
SCRIPT_DIR=`cd ${SCRIPT_DIR}&& pwd`

# Setting the PROJ_HOME variable used to find out where the current project is stored
cd $(cd `dirname $0` && pwd)/.. && export PROJ_HOME=`pwd`

# Set variables with default value
default_tool=questa
default_do_clean="no"
default_test_name="yamm_uvm_benchmark"
default_seed="0"

tool=${default_tool}
do_clean=${default_do_clean}
test_name=${default_test_name}
seed=${default_seed}

##########################################################################################
#  Methods
##########################################################################################

# Help command
help() {
    echo "Usage:  run_yamm.sh    [-tool]   { ius | questa | vcs} ]  --> specify what simulator to use (default: ${default_tool})"
    echo "        [-c ]                                             --> delete work folder prior to compilation"
    echo "        [-test]                  {TEST_NAME}              --> specify the name of the test to be run"
    echo "        [-seed]                  {SEED}                   --> specify the seed"
    echo "        "
    echo "        ./run_yamm.sh    -h[elp]                            --> print this message"
    echo " Examples:"
    echo " - Cadence/IUS  : ./run_yamm.sh -c -tool ius -test yamm_uvm_benchmark -seed 33333"
    echo "        "
    echo " - Mentor/Questa: ./run_yamm.sh -c -tool questa -test yamm_uvm_benchmark -seed 33333"
    echo "        "
    echo " - Synopsys/VCS : ./run_yamm.sh -c -tool vcs -test yamm_uvm_benchmark -seed 33333"
    echo "        "
    exit 0;
}

# Compile and run with ius
run_with_ius() {

    if [ ${do_clean} == "yes" ]; then
	rm -rf ${SCRIPT_DIR}/work_ius
    fi
    
    if [ ! -d "${SCRIPT_DIR}/work_ius" ];then
	mkdir ${SCRIPT_DIR}/work_ius
    fi

    cd ${SCRIPT_DIR}/work_ius    
    irun -f ${PROJ_HOME}/sim/run_ncsim.options +SVSEED=${seed} +UVM_TESTNAME=${test_name}
}

run_with_questa() {  

    if [ ${do_clean} == "yes" ]; then
	rm -rf ${SCRIPT_DIR}/work_questa
    fi

    if [ ! -d "${SCRIPT_DIR}/work_q" ];then
	mkdir ${SCRIPT_DIR}/work_q
    fi

    cd ${SCRIPT_DIR}/work_q

    vlib work
    vlog -f $PROJ_HOME/sim/run_questa.options

    vsim yamm_uvm_testbench -sv_seed ${seed} +UVM_TESTNAME=${test_name} 

}

run_with_vcs() {

    if [ ${do_clean} == "yes" ]; then
	rm -rf ${SCRIPT_DIR}/work_vcs
    fi

    if [ ! -d "${SCRIPT_DIR}/work_vcs" ];then 
	mkdir ${SCRIPT_DIR}/work_vcs
    fi

    cd ${SCRIPT_DIR}/work_vcs

    vcsi -ntb_opts uvm -f ${PROJ_HOME}/sim/run_vcs.options -gui -full64 -sverilog -timescale=1ns/1ps 
	./simv +UVM_NO_RELNOTES +UVM_TESTNAME=${test_name} +ntb_random_seed=${seed} 
}		

##########################################################################################
#  Extract options
##########################################################################################
while [ $# -gt 0 ]; do
   case `echo $1 | tr "[A-Z]" "[a-z]"` in
      -h|-help)
                help
                exit 0
                ;;
      -tool)
                tool=$2
                ;;
      -test)
                test_name=$2
                ;;
      -seed)
                seed=$2
                ;;
      -c)
                do_clean="yes"
                ;;
    esac
    shift
done


##########################################################################################
#  Verify that the simulator is one of IUS, QUESTA or VCS
##########################################################################################
case $tool in
    ius)
        echo "Selected tool: IUS..."
    ;;
    vcs)
        echo "Selected tool: VCS..."
    ;;
    questa)
        echo "Selected tool: Questa..."
    ;;
    *)
        echo "Illegal option for tool: $tool"
        help
    ;;
esac

sim_dir=`pwd`
echo "Start running ${top_name} in ${sim_dir}";

run_with_${tool}
