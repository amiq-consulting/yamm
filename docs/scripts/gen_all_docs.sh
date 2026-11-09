#!/usr/bin/env bash
# Regenerate all checked-in documentation for the yamm project:
#   1. Doxygen C++ API docs  -> docs/yamm_cpp_html    (gen_cpp_docs.sh)
#   2. Specador SV/UVM docs  -> docs/yamm_html        (gen_specador_docs.sh)
#   3. User manual PDF       -> docs/YAMM_User_Manual.pdf (gen_manual_pdf.sh)
#
# Usage: docs/scripts/gen_all_docs.sh
#
# Run this whenever the public API (src/cpp, src/sv) or the user manual
# (docs/YAMM_User_Manual.docx) changes, then commit the updated docs/ tree.
#
# Note: the user manual .docx is hand-maintained in Word; only its PDF is
# regenerated here. After editing the .docx in Word, re-run this script.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repository root

docs/scripts/gen_cpp_docs.sh
docs/scripts/gen_specador_docs.sh
docs/scripts/gen_manual_pdf.sh

echo "All documentation regenerated."
