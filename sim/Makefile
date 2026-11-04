
YAMM_HOME=${PWD}/..
YAMM_SRC_CPP=${YAMM_HOME}/src/cpp
YAMM_TESTS_CPP=${YAMM_HOME}/examples/cpp_tests

CPP_SRCS += \
./../src/cpp/yamm_contents.cpp \
./../src/cpp/yamm_debug.cpp \
./../src/cpp/yamm_get_buffers.cpp \
./../src/cpp/yamm_allocate.cpp \
./../src/cpp/yamm_buffer_locals.cpp \
./../src/cpp/yamm_deallocate.cpp \
./../src/cpp/yamm_insert.cpp \
./../src/cpp/yamm_set_up.cpp

OBJS += \
./Objects/yamm_contents.o \
./Objects/yamm_debug.o \
./Objects/yamm_get_buffers.o \
./Objects/yamm_allocate.o \
./Objects/yamm_buffer_locals.o \
./Objects/yamm_deallocate.o \
./Objects/yamm_insert.o \
./Objects/yamm_set_up.o

include $(wildcard ./Objects/*.d)

all: lib

help:
	echo -e "Use make lib to generate the objects in the Objects folder"

dir:
	YAMM_HOME=${PWD}/..
	YAMM_SRC_CPP=${YAMM_HOME}/src/cpp
	if [ ! -d "./Objects/" ]; then mkdir -p Objects; fi

lib: dir $(OBJS)

Objects/%.o: ${YAMM_SRC_CPP}/%.cpp
	g++ -g -O3 -Wall -c -o "$@" "$<" -MD -MP -MF"$(@:%.o=%.d)" -MT"$(@)"

yamm_recursion_test: lib
	g++ -g -O3 -Wall -o "YAMM" $(OBJS) ./../examples/cpp_tests/yamm_recursion_test.cpp -I${YAMM_SRC_CPP} -I${YAMM_TESTS_CPP}

yamm_access_test: lib
	g++ -g -O3 -Wall -o "YAMM" $(OBJS) ./../examples/cpp_tests/yamm_access_test.cpp -I${YAMM_SRC_CPP} -I${YAMM_TESTS_CPP}

yamm_benchmark_test: lib
	g++ -g -O3 -Wall -o "YAMM" $(OBJS) ./../examples/cpp_tests/yamm_benchmark_test.cpp -I${YAMM_SRC_CPP} -I${YAMM_TESTS_CPP}

yamm_fit_stress_test: lib
	g++ -g -O3 -Wall -o "YAMM" $(OBJS) ./../examples/cpp_tests/yamm_fit_stress_test.cpp -I${YAMM_SRC_CPP} -I${YAMM_TESTS_CPP}

yamm_deallocate_level_test: lib
	g++ -g -O3 -Wall -o "YAMM" $(OBJS) ./../examples/cpp_tests/yamm_deallocate_level_test.cpp -I${YAMM_SRC_CPP} -I${YAMM_TESTS_CPP}

run: $(TEST_TO_RUN)
	./YAMM

# Run the built test binary under valgrind. If no 'YAMM' binary exists yet,
# it builds one first (default: yamm_deallocate_level_test; override with
# TEST_TO_RUN=<test_target>). Fails non-zero if valgrind reports any error.
# Usage: make valgrind            (builds + checks yamm_deallocate_level_test)
#        make valgrind TEST_TO_RUN=yamm_recursion_test
valgrind:
	if [ ! -f "YAMM" ]; then \
		echo "No 'YAMM' binary found -- building $(or $(TEST_TO_RUN),yamm_deallocate_level_test) ..."; \
		$(MAKE) $(or $(TEST_TO_RUN),yamm_deallocate_level_test); \
	fi; \
	valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes --error-exitcode=99 ./YAMM

clean:
	rm -rf ./Objects YAMM
