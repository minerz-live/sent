#!/bin/bash

######## OS ENVIRONMENT ######
USER="root"
HOME_STAGE="/"
HOME_NODE="${HOME_STAGE}/${USER}"

######## NODE ENVIRONMENT ####
MONIKER=""
WALLET_IMPORT_ENABLE="true"

# Default pricing configuration
CLOUD_GB_PRICES="52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn"
CLOUD_HOURLY_PRICES="18480ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,770ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1871892ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,18897ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,7600000udvpn"

RESIDENTIAL_GB_PRICES="52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn"
RESIDENTIAL_HOURLY_PRICES="18480ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,770ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1871892ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,18897ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15000000udvpn"

# Log file
LOG_FILE="/var/log/sentinel_dvpn_install.log"

function log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

function format:color() {
    NOCOLOR='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    ORANGE='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
}

function check_connectivity() {
    if ! ping -c 1 google.com &> /dev/null; then
        echo "No internet connectivity. Please check your connection and try again."
        log "Installation failed: No internet connectivity"
        exit 1
    fi
}

function setup:firewall() {
    log "Setting up firewall"
   
    # Allow TCP-api port
    ufw allow 15363/tcp comment "sentinel-dvpn"
    # Allow UDP-WireGuard port
    ufw allow 51647/udp comment "sentinel-dvpn"
    
   
    log "Firewall setup completed"
}

function tools:dependency() {
    log "Starting dependency installation"
    apt-get update -y
    # Install ACL first
    apt-get install acl -y
    
    apt-get install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release -y
    mkdir -p /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    apt-get update -y
    apt-get install telegraf htop wget tcpdump jq python3-pip lsof qrencode wireguard-tools bind9-dnsutils telnet unzip docker-compose zsh docker-ce docker-ce-cli containerd.io docker-compose-plugin git ufw -y
    log "Dependency installation completed"
}

function create:user() {
    log "Creating user"
    mkdir -p ${HOME_NODE}
    groupadd admin
    useradd -m -d ${HOME_NODE} -G admin,docker -U -s /bin/bash ${USER}
}

function setup:dvpn() {
    log "Setting up DVPN"
    sudo -u ${USER} bash -c 'docker pull ghcr.io/sentinel-official/dvpn-node:latest'
    sudo -u ${USER} bash -c 'docker tag ghcr.io/sentinel-official/dvpn-node:latest sentinel-dvpn-node'
    sudo -u ${USER} bash -c 'docker run --rm \
                                     --volume '${HOME_NODE}'/.sentinelnode:/root/.sentinelnode \
                                     sentinel-dvpn-node process config init'
    sudo -u ${USER} bash -c 'docker run --rm \
                                    --volume '${HOME_NODE}'/.sentinelnode:/root/.sentinelnode \
                                    sentinel-dvpn-node process wireguard config init'
}

function setup:certificates() {
    log "Setting up certificates"
    COUNTRY=$(curl -s http://ip-api.com/json/${IP_PUBLIC}| jq -r ".countryCode") 
    STATE=$(curl -s http://ip-api.com/json/${IP_PUBLIC}| jq -r ".country") 
    CITY=$(curl -s http://ip-api.com/json/${IP_PUBLIC}| jq -r ".city") 
    ORGANIZATION="Sentinel DVPN"
    ORGANIZATION_UNIT="IT Department"

    openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -x509 -sha256 -days 365 -nodes \
            -keyout ${HOME_NODE}/.sentinelnode/tls.key \
            -out ${HOME_NODE}/.sentinelnode/tls.crt \
            -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORGANIZATION}/OU=${ORGANIZATION_UNIT}/CN=."
    chown root:root ${HOME_NODE}/.sentinelnode
}

function setup:config() {
    log "Setting up configuration"
    # Backup original config
    cp ${HOME_NODE}/.sentinelnode/config.toml ${HOME_NODE}/.sentinelnode/config.toml.bak

    # Change Keyring to test
    sed -i 's/backend = "[^"]*"/backend = "test"/' ${HOME_NODE}/.sentinelnode/config.toml

    # Change RPC
    sed -i -e 's|^rpc_addresses *=.*|rpc_addresses = "https://rpc-sentinel.busurnode.com:443,https://rpc.sentineldao.com:443"|' ${HOME_NODE}/.sentinelnode/config.toml 

    # Change RPC Timeout
    sed -i 's/rpc_query_timeout = [0-9]*/rpc_query_timeout = 15/' ${HOME_NODE}/.sentinelnode/config.toml
    
    # Change IP Public
    sed -i 's/ipv4_address = "[^"]*"/ipv4_address = "'${IP_PUBLIC}'"/' ${HOME_NODE}/.sentinelnode/config.toml

    # Change API
    sed -i 's/listen_on = "[^"]*"/listen_on = "0.0.0.0:15363"/' ${HOME_NODE}/.sentinelnode/config.toml

    # Change Remote URL
    sed -i 's/remote_url = "[^"]*"/remote_url = "https:\/\/'"${IP_PUBLIC}"':15363"/' ${HOME_NODE}/.sentinelnode/config.toml

    # Set Moniker Node
    sed -i 's/moniker = "[^"]*"/moniker = "'"${MONIKER}"'"/' ${HOME_NODE}/.sentinelnode/config.toml


    # Update GAS
    sed -i -e 's|^gigabyte_prices *=.*|gigabyte_prices = "'"${GB_PRICES}"'"|' ${HOME_NODE}/.sentinelnode/config.toml 
    sed -i -e 's|^hourly_prices *=.*|hourly_prices = "'"${HOURLY_PRICES}"'"|' ${HOME_NODE}/.sentinelnode/config.toml
    
        # Change User Permissions
    if ! command -v setfacl &> /dev/null; then
        echo "ACL not available, using chmod instead"
        chmod -R 700 ${HOME_NODE}/.sentinelnode
        chown -R ${USER}:${USER} ${HOME_NODE}/.sentinelnode
    else
        setfacl -m u:${USER}:rwx -R ${HOME_NODE}/.sentinelnode
    fi

    # Change wireguard port
    sed -i -e 's|^listen_port *=.*|listen_port = "51647"|' ${HOME_NODE}/.sentinelnode/wireguard.toml 
}

function run:wireguard() {
    log "Starting WireGuard"
    GET_PORT_WIREGUARD=$(cat ${HOME_NODE}/.sentinelnode/wireguard.toml | grep listen_port | awk -F"=" '{print $2}' | sed "s/ //")
    sudo -u ${USER} bash -c 'docker run -d \
        --name sentinel-dvpn-node \
        --restart unless-stopped \
        --volume '${HOME_NODE}'/.sentinelnode:/root/.sentinelnode \
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
        --publish '${GET_PORT_WIREGUARD}':'${GET_PORT_WIREGUARD}'/udp \
        --publish 15363:15363/tcp \
        sentinel-dvpn-node process start'
}

function wallet:creation() {
    log "Creating wallet"
    if [ "${WALLET_IMPORT_ENABLE}" == "true" ]; then
        echo "Please enter your mnemonic seed phrase:"
        sudo -u ${USER} docker run --rm \
            --interactive \
            --tty \
            --volume ${HOME_NODE}/.sentinelnode:/root/.sentinelnode \
            sentinel-dvpn-node process keys add --recover
    else
        echo "Creating new wallet..."
        sudo -u ${USER} docker run --rm \
            --interactive \
            --tty \
            --volume ${HOME_NODE}/.sentinelnode:/root/.sentinelnode \
            sentinel-dvpn-node process keys add > ${HOME_NODE}/.sentinelnode/wallet.txt
    fi
}

function get:informations() {
    log "Retrieving node information"
    echo -e "\n${GREEN}Node Information:${NOCOLOR}"
    echo -e "${BLUE}API Endpoint:${NOCOLOR} https://${IP_PUBLIC}:15363"
    echo -e "${BLUE}WireGuard Port:${NOCOLOR} ${GET_PORT_WIREGUARD}"
    
    if [ -f "${HOME_NODE}/.sentinelnode/wallet.txt" ]; then
        echo -e "\n${YELLOW}Wallet Information (saved in ${HOME_NODE}/.sentinelnode/wallet.txt):${NOCOLOR}"
        cat ${HOME_NODE}/.sentinelnode/wallet.txt
    fi
    
    echo -e "\n${GREEN}Node is running!${NOCOLOR}"
    log "Installation completed successfully"
}

function install_node() {
    check_connectivity
    tools:dependency
    create:user
    setup:dvpn
    setup:certificates
	
	# Prompt for moniker
    read -p "Enter your node moniker (name): " MONIKER
    while [[ -z "$MONIKER" ]]; do
    echo "Moniker cannot be empty"
    read -p "Enter your node moniker (name): " MONIKER
    done
    
    # Prompt for server type
    echo "Select where you're hosting the server:"
    echo "1) Cloud Server"
    echo "2) Residential Server"
    read -p "Enter your choice (1 or 2): " server_type

    case $server_type in
        1)
            GB_PRICES=$CLOUD_GB_PRICES
            HOURLY_PRICES=$CLOUD_HOURLY_PRICES
            ;;
        2)
            GB_PRICES=$RESIDENTIAL_GB_PRICES
            HOURLY_PRICES=$RESIDENTIAL_HOURLY_PRICES
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    setup:config
    wallet:creation
    run:wireguard
    setup:firewall
    get:informations
}

function check_status() {
    log "Checking node status"
    if docker ps | grep -q sentinel-dvpn-node; then
        echo -e "${GREEN}Node Status: Running${NOCOLOR}"
        
        # Get container info
        echo -e "\n${BLUE}Container Information:${NOCOLOR}"
        docker ps --filter name=sentinel-dvpn-node --format "ID: {{.ID}}\nStatus: {{.Status}}\nPorts: {{.Ports}}"
        
        # Get node API status
        echo -e "\n${BLUE}Node API Status:${NOCOLOR}"
        if curl -sfk https://localhost:15363/status > /dev/null; then
            curl -sk https://localhost:15363/status | jq '.'
        else
            echo -e "${RED}Error: Unable to fetch node status${NOCOLOR}"
        fi
        
        # Show connected peers
        echo -e "\n${BLUE}Connected Peers:${NOCOLOR}"
        PEER_RESPONSE=$(curl -sfk https://localhost:15363/status/peers)
        if [ $? -eq 0 ] && [ ! -z "$PEER_RESPONSE" ]; then
            echo "$PEER_RESPONSE" | jq '.'
        else
            echo -e "${YELLOW}No peers currently connected${NOCOLOR}"
        fi
    else
        echo -e "${RED}Node Status: Not Running${NOCOLOR}"
    fi
    
    # Press enter to continue
    echo -e "\nPress Enter to continue..."
    read
}

function main() {
    if [[ $(/usr/bin/id -u) -ne 0 ]]; then
        echo "Aborting: run as root user!"
        exit 1
    fi

    IP_PUBLIC=$(ip addr show $(ip route get 8.8.8.8 | grep -oP '(?<=dev )(\S+)') | grep inet | grep -v inet6 | awk '{print $2}' | awk -F"/" '{print $1}')
    format:color

    while true; do
        echo "Sentinel DVPN Node Installer"
        echo "1. Install Sentinel DVPN Node"
        echo "2. Check Node Status"
        echo "3. Start Node"
        echo "4. Stop Node"
        echo "5. View Logs"
        echo "6. Exit"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                install_node
                ;;
            2)
                check_status
                ;;
            3)
                docker start sentinel-dvpn-node
                ;;
            4)
                docker stop sentinel-dvpn-node
                ;;
            5)
                docker logs sentinel-dvpn-node
                ;;
            6)
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

main
