#!/bin/sh
sed -i 's/blockdiag-[0-9a-f]*/docfolders/g' _build/html/mingw.html
test -e _build/html/_images/blockdiag-*.png && mv -v _build/html/_images/blockdiag-*.png _build/html/_images/docfolders.png
exit 0
