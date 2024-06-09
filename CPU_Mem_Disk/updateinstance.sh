#!/bin/bash

# Set current directory
current_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Manually specify the instance IDs
instance_ids=("6101432072806540570" "3239663752519492521")

# Write the instance IDs to output.txt
output_file="$current_dir/output.txt"
> "$output_file" # Clear the file if it already exists
for id in "${instance_ids[@]}"; do
    echo "$id" >> "$output_file"
done

# Read instance IDs from output.txt
if [[ -f "$output_file" ]]; then
    instance_ids=($(cat "$output_file"))
else
    echo "Error: output.txt not found in $current_dir"
    exit 1
fi

# Call the scripts with instance IDs
"$current_dir/cpu75.sh" "${instance_ids[@]}"
"$current_dir/cpu85.sh" "${instance_ids[@]}"
"$current_dir/disk75.sh" "${instance_ids[@]}"
"$current_dir/disk85.sh" "${instance_ids[@]}"
"$current_dir/mem75.sh" "${instance_ids[@]}"
"$current_dir/mem85.sh" "${instance_ids[@]}"
