# Doxyfile for the yamm C++ API documentation (docs/yamm_cpp_html).
# Invoked by: docs/scripts/gen_cpp_docs.sh
#
# Requirement: document only the yamm C++ API (src/cpp). The examples
# (examples/cpp_tests) are intentionally NOT part of INPUT.

PROJECT_NAME           = YAMM
PROJECT_BRIEF          = "YAMM C++ API"

# Scratch output area; the script copies the result into docs/yamm_cpp_html.
OUTPUT_DIRECTORY       = /tmp/yamm_cpp_doxygen

# Paths are relative to the current working directory (the script runs doxygen
# from the repository root).
INPUT                  = src/cpp
RECURSIVE              = YES

# Document all classes/members, including undocumented ones.
EXTRACT_ALL            = YES
EXTRACT_STATIC         = YES
EXTRACT_PRIVATE        = YES

# Class diagrams (hierarchy + collaboration) via graphviz.
HAVE_DOT               = YES
COLLABORATION_GRAPH    = YES

# HTML output only.
GENERATE_HTML          = YES
HTML_OUTPUT            = yamm_cpp_html
GENERATE_LATEX         = NO
GENERATE_MAN           = NO

QUIET                  = YES
WARNINGS               = YES
# Capture warnings to a log file so gen_cpp_docs.sh can point users to it on
# failure (instead of them being lost to stderr).
WARN_LOGFILE           = /tmp/yamm_cpp_doxygen/doxygen.log
