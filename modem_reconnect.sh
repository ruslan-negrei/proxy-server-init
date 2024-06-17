#!/bin/bash

# Script to be placed in NetworkManager's dispatcher.d directory
# /etc/NetworkManager/dispatcher.d/99-rename-modems

INTERFACE=$1
EVENT=$2
LOGFILE="/var/log/network-manager-log"

log_message() {
  echo "$(date): $1" >>"$LOGFILE"
}

if [ "$EVENT" = "up" ]; then
  # Skip if interface already starts with "modem_"
  if [[ "$INTERFACE" == modem_* ]]; then
    log_message "Interface $INTERFACE already has a modem_ prefix, ignoring."
    exit 0
  fi

  # Gather details about the connection
  INFO=$(nmcli -t -f GENERAL.VENDOR,IP4.GATEWAY device show "$INTERFACE")
  VENDOR=$(echo "$INFO" | grep 'GENERAL.VENDOR' | cut -d: -f2)
  IP_GATEWAY=$(echo "$INFO" | grep 'IP4.GATEWAY' | cut -d: -f2)

  # Check if the VENDOR contains "Huawei" and IP_GATEWAY is not empty
  if [[ "$VENDOR" == *"Huawei"* ]] && [ -n "$IP_GATEWAY" ]; then
    # Extract the third octet from the IP_GATEWAY
    OCTET=$(echo "$IP_GATEWAY" | cut -d. -f3)

    # Check if OCTET is a number
    if ! [[ "$OCTET" =~ ^[0-9]+$ ]]; then
      log_message "The third octet of the IP gateway is not a number. IP_GATEWAY: $IP_GATEWAY"
      exit 1
    fi

    # Construct the new interface name
    NEW_INTERFACE_NAME="modem_$OCTET"

    # Log the intended change
    log_message "Preparing to rename interface $INTERFACE to $NEW_INTERFACE_NAME based on IP gateway $IP_GATEWAY."

    # Rename the interface
    ip link set "$INTERFACE" down
    ip link set "$INTERFACE" name "$NEW_INTERFACE_NAME"
    ip link set "$NEW_INTERFACE_NAME" up

    # Log the completion
    log_message "Successfully renamed interface $INTERFACE to $NEW_INTERFACE_NAME."

    # Setting iptables for counting traffic
    sudo iptables -C TRAFFIC_STATS -i $NEW_INTERFACE_NAME ! -s 192.168.0.0/16 -m conntrack --ctstate ESTABLISHED || sudo iptables -A TRAFFIC_STATS -i $NEW_INTERFACE_NAME ! -s 192.168.0.0/16 -m conntrack --ctstate ESTABLISHED
    sudo iptables -C TRAFFIC_STATS -o $NEW_INTERFACE_NAME ! -d 192.168.0.0/16 -m conntrack --ctstate ESTABLISHED || sudo iptables -A TRAFFIC_STATS -o $NEW_INTERFACE_NAME ! -d 192.168.0.0/16 -m conntrack --ctstate ESTABLISHED

    log_message "iptables rules for traffic counting have been set for interface $NEW_INTERFACE_NAME."
  else
    if [[ "$VENDOR" != *"Huawei"* ]]; then
      log_message "The device vendor is not Huawei. VENDOR: $VENDOR"
    fi
    if [ -z "$IP_GATEWAY" ]; then
      log_message "The IP gateway is missing."
    fi
  fi
else
  log_message "The event is not 'up'. EVENT: $EVENT"
fi
