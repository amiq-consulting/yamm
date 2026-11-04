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

#ifndef __yamm_test_utils_h
#define __yamm_test_utils_h

#include <iostream>

/**
 * Shared assertion helper for YAMM C++ unit tests.
 *
 * check(cond, msg) increments g_failures and prints a [FAIL] line whenever
 * cond is false.  Each test's main() should return g_failures != 0 at the end
 * so that the process exits non-zero on any assertion failure.
 */
static int g_failures = 0;

static void check(bool cond, const char* msg) {
	if (!cond) {
		std::cerr << "[FAIL] " << msg << "\n";
		g_failures++;
	}
}

#endif // __yamm_test_utils_h
