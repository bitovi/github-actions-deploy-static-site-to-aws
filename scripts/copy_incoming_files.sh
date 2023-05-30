#!/bin/bash

set -e 

source_folder="$GITHUB_WORKSPACE/"
destination_folder="/path/to/destination/folder"
files="file1.txt,file2.txt,file3.txt"  # Replace with your comma-separated file list

IFS=',' read -ra file_list <<< "$files"

for file in "${file_list[@]}"; do
    source_file="${source_folder}/${file}"
    destination_file="${destination_folder}/${file}"

    if [ -f "$source_file" ]; then
        cp "$source_file" "$destination_file"
        echo "Copied $source_file to $destination_file"
    else
        echo "File $source_file does not exist"
    fi
done