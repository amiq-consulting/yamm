#!/usr/bin/env bash
# Regenerate the user manual PDF (docs/YAMM_User_Manual.pdf) from the
# hand-maintained Word file (docs/YAMM_User_Manual.docx) using headless
# LibreOffice.
#
# Usage: docs/scripts/gen_manual_pdf.sh
#
# Prerequisites:
#   - libreoffice on PATH (e.g. 'sudo apt install libreoffice-writer').
#   - python3-uno on PATH (e.g. 'sudo apt install python3-uno'), used to
#     refresh the Word table-of-contents fields before exporting.
#
# The Word TOC is a field that only Word/LibreOffice can re-paginate, so
# instead of a plain '--convert-to pdf' the script drives a headless
# LibreOffice instance over a UNO socket: it loads the docx, updates all
# document indexes (TOC / table of figures / table of tables), and exports
# the PDF. A private user profile is used so a LibreOffice session the user
# has open in the desktop is never touched.
set -euo pipefail
cd "$(dirname "$0")/../.."   # repository root

command -v soffice >/dev/null 2>&1 || { echo "ERROR: libreoffice (soffice) not found on PATH (e.g. 'sudo apt install libreoffice-writer')" >&2; exit 1; }
python3 -c "import uno" >/dev/null 2>&1 || { echo "ERROR: python3-uno not available (e.g. 'sudo apt install python3-uno')" >&2; exit 1; }

DOCX=docs/YAMM_User_Manual.docx
PDF=docs/YAMM_User_Manual.pdf
[ -f "${DOCX}" ] || { echo "ERROR: ${DOCX} not found" >&2; exit 1; }

PORT=22027
PROFILE=/tmp/yamm_soffice_profile

# Start a headless LibreOffice instance accepting a UNO socket connection.
rm -rf "${PROFILE}"
soffice --headless --invisible --nocrashreport --nodefault --nofirststartwizard \
    --nologo --norestore \
    "-env:UserInstallation=file://${PROFILE}" \
    --accept="socket,host=127.0.0.1,port=${PORT};urp;" \
    >/dev/null 2>&1 &
SOFFICE_PID=$!
trap 'kill "${SOFFICE_PID}" 2>/dev/null || true' EXIT

python3 - "${PORT}" "${DOCX}" "${PDF}" <<'PYEOF'
import sys, time
from pathlib import Path
import uno
from com.sun.star.beans import PropertyValue

port, docx, pdf = sys.argv[1], sys.argv[2], sys.argv[3]

def prop(name, value):
    p = PropertyValue(); p.Name = name; p.Value = value
    return p

# Connect to the headless instance (it needs a few seconds to come up).
resolver = uno.getComponentContext().ServiceManager.createInstanceWithContext(
    'com.sun.star.bridge.UnoUrlResolver', uno.getComponentContext())
ctx = None
for _ in range(60):
    try:
        ctx = resolver.resolve(f'uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext')
        break
    except Exception:
        time.sleep(1)
if ctx is None:
    sys.exit('ERROR: could not connect to the headless soffice UNO socket')

desktop = ctx.ServiceManager.createInstanceWithContext('com.sun.star.frame.Desktop', ctx)
doc = desktop.loadComponentFromURL(Path(docx).absolute().as_uri(), '_blank', 0, (prop('Hidden', True),))

# Refresh all TOC / table-of-figures / table-of-tables indexes so their
# page numbers match the current content, then export the PDF.
for index in doc.getDocumentIndexes():
    index.update()
doc.refresh()

doc.storeToURL(Path(pdf).absolute().as_uri(), (prop('FilterName', 'writer_pdf_Export'),))
doc.close(False)
desktop.terminate()
print(f'Done: {pdf} regenerated from {docx} (TOC refreshed).')
PYEOF

[ -f "${PDF}" ] || { echo "ERROR: ${PDF} was not produced" >&2; exit 1; }
