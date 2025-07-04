#!/bin/bash

# Check if epoch parameter is provided
if [ "$#" -ne 2 ] || [ "$1" != "--epoch" ]; then
    echo "Usage: $0 --epoch <epoch_number>"
    exit 1
fi

epoch=$2

# Rename spectrum file to the specified epoch
cp "spectrum.158" "spectrum.$epoch"

# Parse the spectrum and upload relevant data to the database
./qubic-stats-processor --mongo-username qubic --mongo-password password --app-mode=spectrum_parser --spectrum-parser-spectrum-file="spectrum.$epoch"
