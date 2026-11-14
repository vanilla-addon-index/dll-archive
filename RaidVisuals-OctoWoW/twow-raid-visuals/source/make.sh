#!/bin/bash

# Build the MPQ file
./target/release/wow_dbc_patcher build --mpq patch-O.mpq

# Check if --zip option is passed
if [[ "$1" == "--zip" ]]; then
    echo "Zipping patch-O.mpq to patch-O.zip..."
    zip patch-O.zip patch-O.mpq
    echo "Created patch-O.zip"
fi