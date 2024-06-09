#!/bin/bash

# Function to fetch instance name from instance ID and zone
get_instance_name() {
  local instance_id=$1
  local zone=$2
  gcloud compute instances describe "$instance_id" --zone="$zone" --format="get(name)"
}

# Function to fetch project ID
get_project_id() {
  gcloud config get-value project
}

# Function to fetch notification channel ID based on display name
get_notification_channel_id() {
  local channel_name=$1
  gcloud beta monitoring channels list --format="value(name)" --filter="displayName=\"$channel_name\""
}

# Function to create memory utilization alert policy JSON
create_memory_alert_policy_json() {
  local instance_id=$1
  local instance_name=$2
  local notification_channel_id=$3
  local project_id=$(get_project_id)
  local alert_policy_json=$(cat <<EOF
{
  "displayName": "$instance_name - Memory utilization 75%",
  "userLabels": {},
  "conditions": [
    {
      "displayName": "$instance_name - Memory utilization 75%",
      "conditionThreshold": {
        "filter": "resource.type = \"gce_instance\" AND resource.labels.instance_id = \"$instance_id\" AND metric.type = \"agent.googleapis.com/memory/percent_used\" AND metric.labels.state = \"used\"",
        "aggregations": [
          {
            "alignmentPeriod": "600s",
            "crossSeriesReducer": "REDUCE_NONE",
            "perSeriesAligner": "ALIGN_MEAN"
          }
        ],
        "comparison": "COMPARISON_GT",
        "duration": "0s",
        "trigger": {
          "count": 1
        },
        "thresholdValue": 75
      }
    }
  ],
  "alertStrategy": {
    "autoClose": "86400s"
  },
  "combiner": "OR",
  "enabled": true,
  "notificationChannels": [
    "$notification_channel_id"
  ],
  "severity": "WARNING"
}
EOF
)
  echo "$alert_policy_json"
}

# Function to fetch zone based on instance ID
get_zone_from_instance_id() {
  local instance_id=$1
  gcloud compute instances list --filter="id=$instance_id" --format="value(zone)" | awk -F/ '{print $NF}'
}

# Main function to process instance IDs
main() {
  local instance_ids=("$@")
  local notification_channel_name="venkat"
  local notification_channel_id=$(get_notification_channel_id "$notification_channel_name")

  if [ -z "$notification_channel_id" ]; then
    echo "Notification channel with display name '$notification_channel_name' not found."
    exit 1
  fi

  for instance_id in "${instance_ids[@]}"; do
    local zone=$(get_zone_from_instance_id "$instance_id")

    if [ -n "$zone" ]; then
      local instance_name=$(get_instance_name "$instance_id" "$zone")

      if [ -n "$instance_name" ]; then
        local alert_policy_json=$(create_memory_alert_policy_json "$instance_id" "$instance_name" "$notification_channel_id")
        local json_file="${instance_name}_memory_alert_policy.json"

        echo "$alert_policy_json" > "$json_file"
        echo "Created alert policy JSON for $instance_name at $json_file"

        # Create the alert policy using gcloud
        gcloud alpha monitoring policies create --policy-from-file="$json_file"

        # Remove the JSON file after creating the alert policy
        rm "$json_file"
      else
        echo "Instance ID $instance_id not found in zone $zone."
      fi
    else
      echo "Zone for instance ID $instance_id not found."
    fi
  done
}

# Read instance IDs from output.txt and process them
if [[ -f "output.txt" ]]; then
  instance_ids=($(cat "output.txt"))
  main "${instance_ids[@]}"
else
  echo "Error: output.txt not found."
  exit 1
fi
