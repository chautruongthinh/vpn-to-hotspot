#!/bin/bash
################################################################
# Author: Max Haase maxhaase@gmail.com
#
# This sript shares a VPN connection and converts a WiFi adapter into a wireless AP sharing your VPN
# run as sudo or root! 
# It makes backups, it displays menus, and you can always roll-back if for some reason fails. 
# Define variables
BACKUP_DIR="/etc/network-config-backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/network-config-backup_${DATE}.tar.gz"
SSID="VPN" # This is the name it will be found by WiFi
PASSWORD="ChangeThis"  # Change this to a secure password!!!
################################################################
# Create a backup
create_backup() {
    echo "Creating backup of current network configuration..."
    mkdir -p ${BACKUP_DIR}
    tar -czvf ${BACKUP_FILE} /etc/sysctl.conf /etc/iptables/rules.v4
    echo "Backup created at ${BACKUP_FILE}"
}

# List and restore backups
restore_backup() {
    echo "Available backups:"
    select file in ${BACKUP_DIR}/*.tar.gz; do
        if [ -f "$file" ]; then
            echo "Restoring backup from $file..."
            tar -xzvf "$file" -C /
            echo "Backup restored from $file"
            break
        else
            echo "Invalid selection. Try again."
        fi
    done
}

# Enable IP forwarding
enable_ip_forwarding() {
    echo "Enabling IP forwarding..."
    if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
    else
        sudo sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    fi
    sudo sysctl -p
    echo "IP forwarding enabled."
}

# Configure iptables
configure_iptables() {
    echo "Configuring iptables for NAT..."
    sudo iptables -t nat -A POSTROUTING -o ${VPN_INTERFACE} -j MASQUERADE
    sudo iptables -A FORWARD -i ${SHARED_INTERFACE} -o ${VPN_INTERFACE} -j ACCEPT
    sudo iptables -A FORWARD -i ${VPN_INTERFACE} -o ${SHARED_INTERFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
    sudo mkdir -p /etc/iptables
    sudo sh -c "iptables-save > /etc/iptables/rules.v4"
    echo "iptables configured."
}

# Set up Wi-Fi hotspot
setup_wifi_hotspot() {
    echo "Setting up Wi-Fi hotspot..."
    nmcli dev wifi hotspot ifname ${SHARED_INTERFACE} ssid ${SSID} password ${PASSWORD}
    echo "Wi-Fi hotspot set with SSID: ${SSID}"
}

# Display client configuration instructions
display_client_instructions() {
    echo "Client Configuration Instructions:"
    echo "1. Set the client device to obtain an IP address automatically (via DHCP)."
    echo "2. Connect the client device to the Wi-Fi network named '${SSID}' with the password '${PASSWORD}'."
    echo "The client device should now be able to connect to the internet through the Linux host's VPN."
}

# Select network interfaces
select_interfaces() {
    interfaces=$(ip -o link show | awk -F': ' '{print $2}')
    
    echo "Select your VPN interface (usually an Ethernet interface):"
    PS3="Please select the VPN interface: "
    select vpn in ${interfaces}; do
        if [[ -n "$vpn" && $(iw dev $vpn info 2>/dev/null) == "" && $vpn != lo && $vpn != docker0 && $vpn != virbr0 ]]; then
            VPN_INTERFACE=$vpn
            echo "Selected VPN interface: $VPN_INTERFACE"
            break
        else
            echo "Invalid selection or not an Ethernet interface. Try again."
        fi
    done

    echo "Select your Wi-Fi interface:"
    PS3="Please select the Wi-Fi interface: "
    select shared in ${interfaces}; do
        if [[ -n "$shared" && $(iw dev $shared info 2>/dev/null) != "" ]]; then
            SHARED_INTERFACE=$shared
            echo "Selected Wi-Fi interface: $SHARED_INTERFACE"
            break
        else
            echo "Invalid selection or not a Wi-Fi interface. Try again."
        fi
    done
}

# Main script
echo "VPN Connection Sharing Script"
PS3="Please select an option: "
options=("Create Backup and Apply Changes" "Restore Backup" "Exit")
select opt in "${options[@]}"; do
    case $opt in
        "Create Backup and Apply Changes")
            create_backup
            select_interfaces
            enable_ip_forwarding
            configure_iptables
            setup_wifi_hotspot
            display_client_instructions
            break
            ;;
        "Restore Backup")
            restore_backup
            break
            ;;
        "Exit")
            break
            ;;
        *) echo "Invalid option $REPLY";;
    esac
done
