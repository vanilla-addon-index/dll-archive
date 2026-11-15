#!/bin/sh -eu

BUILDDIR="${BUILDDIR:-./build}"
DI_PRINT="${DI_PRINT:-${BUILDDIR}/test/di-print}"

workdir="$(mktemp -d)"
cleanup() {
	rm -rf "$workdir"
}
trap cleanup EXIT

for blob in "$@"; do
	"$DI_PRINT" <"$blob" >"${blob%.*}.print"
done
