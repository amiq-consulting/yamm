#!/usr/bin/env bash
# Regenerate the Doxygen C++ API documentation (docs/yamm_cpp_html) for the
# yamm project.
#
# Usage: docs/scripts/gen_cpp_docs.sh
#
# Prerequisites:
#   - doxygen on PATH (e.g. 'sudo apt install doxygen').
#   - graphviz (dot) for class diagrams.
#
# Only the yamm C++ API (src/cpp) is documented; the examples
# (examples/cpp_tests) are excluded by the Doxyfile (docs/scripts/Doxyfile.cpp).
set -euo pipefail
cd "$(dirname "$0")/../.."   # repository root

command -v doxygen >/dev/null 2>&1 || { echo "ERROR: doxygen not found on PATH (e.g. 'sudo apt install doxygen')" >&2; exit 1; }

SCRATCH=/tmp/yamm_cpp_doxygen

# Build the docs into the scratch area configured in the Doxyfile.
rm -rf "${SCRATCH}"
doxygen docs/scripts/Doxyfile.cpp

HTML_OUT="${SCRATCH}/yamm_cpp_html"
[ -f "${HTML_OUT}/index.html" ] || { echo "ERROR: HTML output not found at ${HTML_OUT} (see ${SCRATCH}/doxygen.log)" >&2; exit 1; }

# Replace the checked-in documentation with the freshly built pages.
rm -rf docs/yamm_cpp_html
cp -r "${HTML_OUT}" docs/yamm_cpp_html

echo "Done: docs/yamm_cpp_html regenerated ($(find docs/yamm_cpp_html -name '*.html' | wc -l) HTML pages)."
