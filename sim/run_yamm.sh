#!/bin/bash -i
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
PROJ_HOME=`cd ${SCRIPT_DIR}/../ && pwd`

# Set variables with default value
default_tool=questa
default_top_name="yamm_vs_mam_test"
default_path="examples/sv/yamm_vs_mam_test.sv"
default_do_clean="no"

tool=${default_tool}
top_name=${default_top_name}
path=${default_path}
do_clean=${default_do_clean}

##########################################################################################
#  Methods
##########################################################################################

# Help command
help() {
    echo "Usage:  run_yamm.sh    [-tool]   { ius | questa | vcs} ]  --> specify what simulator to use (default: ${default_tool})"
    echo "        [-top     {TOP_MODULE_NAME} ]                     --> name of the module "
    echo "        [-path    {PATH} ]                                --> path to top-module's file relative to yamm's folder"
    echo "        [-c ]                                             --> delete work folder prior to compilation"
    echo "        "
    echo "        run_yamm.sh    -h[elp]                            --> print this message"
    echo " Examples:"
    echo " - Cadence/IUS  : ./run_yamm.sh -c -tool ius -top yamm_general -path examples/sv/yamm_general.sv"
    echo "        "
    echo " - Mentor/Questa: ./run_yamm.sh -c -tool questa -top yamm_general -path examples/sv/yamm_general.sv"
    echo "        "
    echo " - Synopsys/VCS : ./run_yamm.sh -c -tool vcs -top yamm_general -path examples/sv/yamm_general.sv"
    echo "        "
    exit 0;
}

# Compile and run with ius
run_with_ius() {

    if [ ${do_clean} == "yes" ]; then
	rm -rf work_ius
    fi
    
    if [ ! -d "work_ius" ];then
	mkdir work_ius
    fi

    cd work_ius    

    irun -uvm ${PROJ_HOME}/sv/yamm_pkg.sv \
	 -incdir ${PROJ_HOME}/sv \
	 ${PROJ_HOME}/${path} \
	 -gui -linedebug -access rwc
}

run_with_questa() {  

    if [ ${do_clean} == "yes" ]; then
	rm -rf work_questa
    fi

    if [ ! -d "work_q" ];then
	mkdir work_q
    fi

    cd work_q

    vlib work
    ln -s ${PROJ_HOME}/sv/* .
    vlog ${PROJ_HOME}/sv/yamm_pkg.sv ${PROJ_HOME}/${path}

    vsim ${top_name}

}

run_with_vcs() {

    if [ ${do_clean} == "yes" ]; then
	rm -rf work_vcs
    fi

    if [ ! -d "work_vcs" ];then 
	mkdir work_vcs
    fi

    cd work_vcs

    vcsi -ntb_opts uvm -sverilog +incdir+${PROJ_HOME}/sv +incdir+${PROJ_HOME}/examples/sv ${PROJ_HOME}/sv/yamm_pkg.sv ${PROJ_HOME}/${path} -top ${top_name} -R -gui -full64

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
      -top)
                top_name=$2
                ;;
      -path)
                path=$2
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
