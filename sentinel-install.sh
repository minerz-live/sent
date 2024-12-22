#!/bin/bash

# Function for formatted colored output
function format:color() {
    NOCOLOR='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    ORANGE='\033[0;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
}

# Function for displaying messages
function echo:info() {
    echo -e "${CYAN}[INFO]${NOCOLOR} $1"
}

function echo:error() {
    echo -e "${RED}[ERROR]${NOCOLOR} $1"
    exit 1
}

# Check if the script is being run as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Aborting: run as root user!"
    exit 1
fi

# Prompt the user for the moniker
read -p "Enter the moniker for your node: " MONIKER

# Ensure the moniker is not empty
if [ -z "$MONIKER" ]; then
    echo "[ERROR] Moniker cannot be empty. Please rerun the script and provide a valid moniker."
    exit 1
fi

# Variables
USER="root"
HOME_STAGE="/"
HOME_NODE="${HOME_STAGE}/${USER}"
WALLET_IMPORT_ENABLE="true"

IP_PUBLIC=$(ip addr show $(ip route get 8.8.8.8 | grep -oP '(?<=dev )(\S+)') | grep inet | grep -v inet6 | awk '{print $2}' | awk -F"/" '{print $1}')

# Install dependencies
function tools:dependency() {
    echo:info "Installing dependencies..."
    apt-get update -y
    apt-get install -y curl git openssl ca-certificates gnupg lsb-release jq ufw docker-compose
}

# Configure UFW
function setup:firewall() {
    echo:info "Configuring UFW rules..."
    ufw allow 15363/tcp comment "sentinel-dvpn"
    ufw allow 51647/udp comment "sentinel-dvpn"
}

# Setup and run Sentinel dVPN node
function setup:node() {
    echo:info "Setting up Sentinel dVPN node..."
    mkdir -p "${HOME_NODE}/.sentinelnode"
    docker pull ghcr.io/sentinel-official/dvpn-node:latest
    docker tag ghcr.io/sentinel-official/dvpn-node:latest sentinel-dvpn-node
    docker run --rm --volume "${HOME_NODE}/.sentinelnode:/root/.sentinelnode" sentinel-dvpn-node process config init
    docker run --rm --volume "${HOME_NODE}/.sentinelnode:/root/.sentinelnode" sentinel-dvpn-node process wireguard config init

    echo:info "Updating configuration..."
    sed -i 's/backend = "[^"]*"/backend = "test"/' "${HOME_NODE}/.sentinelnode/config.toml"
    sed -i 's/moniker = "[^"]*"/moniker = "'"${MONIKER}"'"/' "${HOME_NODE}/.sentinelnode/config.toml"
}

# Generate and apply TLS certificates
function setup:certificates() {
    echo:info "Generating TLS certificates..."
    COUNTRY=$(curl -s http://ip-api.com/json/${IP_PUBLIC} | jq -r ".countryCode")
    STATE=$(curl -s http://ip-api.com/json/${IP_PUBLIC} | jq -r ".country")
    CITY=$(curl -s http://ip-api.com/json/${IP_PUBLIC} | jq -r ".city")
    ORGANIZATION="Sentinel DVPN"
    ORGANIZATION_UNIT="IT Department"

    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -x509 -sha256 -days 365 -nodes -keyout "${HOME_NODE}/.sentinelnode/tls.key" -out "${HOME_NODE}/.sentinelnode/tls.crt" -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORGANIZATION_UNIT}/CN=."
    chown root:root "${HOME_NODE}/.sentinelnode"
}

# Run the Sentinel dVPN node
function run:node() {
    echo:info "Starting Sentinel dVPN node..."
    GET_PORT_WIREGUARD=$(cat "${HOME_NODE}/.sentinelnode/wireguard.toml" | grep listen_port | awk -F"=" '{print $2}' | sed "s/ //")
    docker run -d --name sentinel-dvpn-node \
        --restart unless-stopped \
        --volume "${HOME_NODE}/.sentinelnode:/root/.sentinelnode" \
        --volume /lib/modules:/lib/modules \
        --cap-drop ALL \
        --cap-add NET_ADMIN \
        --cap-add NET_BIND_SERVICE \
        --cap-add NET_RAW \
        --cap-add SYS_MODULE \
        --sysctl net.ipv4.ip_forward=1 \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv6.conf.all.forwarding=1 \
        --sysctl net.ipv6.conf.default.forwarding=1 \
        --publish "${GET_PORT_WIREGUARD}:${GET_PORT_WIREGUARD}/udp" \
        --publish 15363:15363/tcp \
        sentinel-dvpn-node process start
}

# Execute functions in sequence
tools:dependency
setup:firewall
setup:node
setup:certificates
run:node

echo:info "Sentinel dVPN node setup complete. Use the following moniker for identification: ${MONIKER}"
