#!/bin/sh -eu

workdir="$(mktemp -d)"
cleanup() {
	rm -rf "$workdir"
}
trap cleanup EXIT

blob="$1"
ref="${blob%.*}.print"
"$DI_PRINT" <"$blob" >"$workdir/printout"

diff -u "$ref" "$workdir/printout"
