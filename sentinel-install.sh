#!/bin/bash

######## OS ENVIRONMENT ######
USER="root"
HOME_STAGE="/"
HOME_NODE="${HOME_STAGE}/${USER}"

# Default pricing configuration
CLOUD_GB_PRICES="52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn"
CLOUD_HOURLY_PRICES="18480ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,770ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1871892ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,18897ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,7600000udvpn"

RESIDENTIAL_GB_PRICES="52573ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,9204ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1180852ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,122740ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15342624udvpn"
RESIDENTIAL_HOURLY_PRICES="18480ibc/31FEE1A2A9F9C01113F90BD0BBCCE8FD6BBB8585FAF109A2101827DD1D5B95B8,770ibc/A8C2D23A1E6F95DA4E48BA349667E322BD7A6C996D8A4AAE8BA72E190F3D1477,1871892ibc/B1C0DDB14F25279A2026BC8794E12B259F8BDA546A3C5132CCAEE4431CE36783,18897ibc/ED07A3391A112B175915CD8FAF43A2DA8E4790EDE12566649D0C2F97716B8518,15000000udvpn"

# Color definitions
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

function tools:depedency() {
    apt-get update -y
    apt-get install \
        ca-certificates \
        curl \
        gnupg \
        lsb-release -y
    mkdir -p /etc/apt/keyrings
    if [ -f /etc/apt/keyrings/docker.gpg ]; then
        echo "GPG Available"
    else
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    fi
    if [ -f /etc/apt/sources.list.d/docker.list ]; then
        echo "Directory Already Created"
    else
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    apt-get update -y
    apt-get install telegraf acl htop wget tcpdump jq python3-pip lsof qrencode wireguard-tools bind9-dnsutils telnet unzip docker-compose zsh docker-ce docker-ce-cli containerd.io docker-compose-plugin git ufw -y
}

function create:user() {
    mkdir -p ${HOME_NODE}
    groupadd admin
    useradd -m -d ${HOME_NODE} -G admin,docker -U -s /bin/bash ${USER}
}

function setup:dvpn() {
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

function wallet:creation() {
    if [ "${WALLET_IMPORT_ENABLE}" == "true" ]; then
        sudo -u ${USER} bash -c 'docker run --rm \
                                    --interactive \
                                    --tty \
                                    --volume '${HOME_NODE}'/.sentinelnode:/root/.sentinelnode \
                                    sentinel-dvpn-node process keys add  --recover'
    else
        sudo -u ${USER} bash -c 'docker run --rm \
                                    --interactive \
                                    --tty \
                                    --volume '${HOME_NODE}'/.sentinelnode:/root/.sentinelnode \
                                    sentinel-dvpn-node process keys add' > /tmp/wallet.txt
    fi
}

function run:wireguard() {
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

function get:informations() {
    if [ "${WALLET_IMPORT_ENABLE}" == "false" ]; then
        clear
        echo ""
        echo -e "\e[106m   \e[49m\e[105m   \e[103m   \e[102m   \e[101m   \e[46m    \e[43m    \e[97m\e[44m\e[1m   SENTINEL NODE INFORMATIONS  \e[0m"
        echo "Save your Seeds and Dont Lose, Your seed is your asset"
        echo -e "${GREEN}SEED:${NOCOLOR}"
        SEED_KEY=$(cat /tmp/wallet.txt | grep -v "^*" | head -n1)
        echo -e "${RED}${SEED_KEY}${NOCOLOR}"
        echo ""
        NODE_ADDRESS=$(cat /tmp/wallet.txt | grep operator | awk '{print $2}')
        WALLET_ADDRESS=$(cat /tmp/wallet.txt | grep operator | awk '{print $3}')
        WALLET_NAME=$(cat /tmp/wallet.txt | grep operator | awk '{print $1}')
        echo -e "${GREEN}Your Node Address :${NOCOLOR} ${RED}${NODE_ADDRESS}${NOCOLOR}"
        echo -e "${GREEN}Your Wallet Address :${NOCOLOR} ${RED}${NODE_ADDRESS}${NOCOLOR}"
        echo -e "${GREEN}Your Wallet Name :${NOCOLOR} ${RED}${WALLET_NAME}${NOCOLOR}"
        echo ""
        echo "Please send 50 dVPN for activation to your wallet ${WALLET_ADDRESS}"
        echo -e "restart service after sent balance with command ${GREEN}docker restart sentinel-dvpn-node${NOCOLOR}"
    fi
}

function print_banner() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════╗${NOCOLOR}"
    echo -e "${BLUE}║      Sentinel dVPN Node Installer      ║${NOCOLOR}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NOCOLOR}"
    echo
}

function main_menu() {
    while true; do
        print_banner
        echo -e "${GREEN}Select an option:${NOCOLOR}"
        echo "1) Install Sentinel dVPN Node"
        echo "2) Restart Node"
        echo "3) Stop Node"
        echo "4) View Logs"
        echo "5) Remove Node"
        echo "8) Exit"
        echo
        read -p "Enter your choice: " choice

        case $choice in
            1) installation_menu ;;
            2) restart_node ;;
            3) stop_node ;;
            4) view_logs ;;
            5) remove_node ;;
            8) exit 0 ;;
            *) echo -e "${RED}Invalid option${NOCOLOR}" ;;
        esac
    done
}

function installation_menu() {
    print_banner
    echo -e "${GREEN}Select installation type:${NOCOLOR}"
    echo "1) Install on Cloud Server"
    echo "2) Install on Residential"
    echo "3) Back to main menu"
    echo
    read -p "Enter your choice: " install_type

    case $install_type in
        1) 
            GB_PRICES=$CLOUD_GB_PRICES
            HOURLY_PRICES=$CLOUD_HOURLY_PRICES
            start_installation "Cloud Server"
            ;;
        2)
            GB_PRICES=$RESIDENTIAL_GB_PRICES
            HOURLY_PRICES=$RESIDENTIAL_HOURLY_PRICES
            start_installation "Residential"
            ;;
        3) return ;;
        *) echo -e "${RED}Invalid option${NOCOLOR}" ;;
    esac
}

function start_installation() {
    print_banner
    echo -e "${GREEN}Starting $1 Installation${NOCOLOR}"
    
    # Get moniker
    read -p "Enter moniker name for your node: " MONIKER
    
    # Continue with installation steps
    tools:depedency
    create:user
    setup:dvpn
    setup:certificates
    configure_node
    wallet:creation
    run:wireguard
    get:informations
    
    echo -e "${GREEN}Installation completed!${NOCOLOR}"
    read -p "Press any key to continue..." -n1 -s
}

function configure_node() {
    # Change Keyring to test
    sed -i 's/backend = "[^"]*"/backend = "test"/' ${HOME_NODE}/.sentinelnode/config.toml

    # Set basic configuration
    sed -i -e 's|^rpc_addresses *=.*|rpc_addresses = "https://rpc-sentinel.busurnode.com:443,https://rpc.sentineldao.com:443"|' ${HOME_NODE}/.sentinelnode/config.toml
    sed -i 's/rpc_query_timeout = [0-9]*/rpc_query_timeout = 15/' ${HOME_NODE}/.sentinelnode/config.toml
    sed -i 's/ipv4_address = "[^"]*"/ipv4_address = "'${IP_PUBLIC}'"/' ${HOME_NODE}/.sentinelnode/config.toml
    sed -i 's/listen_on = "[^"]*"/listen_on = "0.0.0.0:15363"/' ${HOME_NODE}/.sentinelnode/config.toml
    sed -i 's/remote_url = "[^"]*"/remote_url = "https:\/\/'"${IP_PUBLIC}"':15363"/' ${HOME_NODE}/.sentinelnode/config.toml
    sed -i 's/moniker = "[^"]*"/moniker = "'"${MONIKER}"'"/' ${HOME_NODE}/.sentinelnode/config.toml

    # Set pricing based on installation type
    sed -i -e 's|^gigabyte_prices *=.*|gigabyte_prices = "'"${GB_PRICES}"'"|' ${HOME_NODE}/.sentinelnode/config.toml
    sed -i -e 's|^hourly_prices *=.*|hourly_prices = "'"${HOURLY_PRICES}"'"|' ${HOME_NODE}/.sentinelnode/config.toml

    # Set permissions and wireguard port
    setfacl -m u:${USER}:rwx -R ${HOME_NODE}/.sentinelnode
    sed -i -e 's|^listen_port *=.*|listen_port = "51647"|' ${HOME_NODE}/.sentinelnode/wireguard.toml
}

function restart_node() {
    echo -e "${GREEN}Restarting Sentinel Node...${NOCOLOR}"
    docker restart sentinel-dvpn-node
    echo -e "${GREEN}Node restarted successfully${NOCOLOR}"
    read -p "Press any key to continue..." -n1 -s
}

function stop_node() {
    echo -e "${GREEN}Stopping Sentinel Node...${NOCOLOR}"
    docker stop sentinel-dvpn-node
    echo -e "${GREEN}Node stopped successfully${NOCOLOR}"
    read -p "Press any key to continue..." -n1 -s
}

function view_logs() {
    echo -e "${GREEN}Showing Node Logs (press Ctrl+C to exit):${NOCOLOR}"
    docker logs -f sentinel-dvpn-node
}

function remove_node() {
    echo -e "${RED}Warning: This will remove the Sentinel Node and all its data${NOCOLOR}"
    read -p "Are you sure you want to continue? (y/n): " confirm
    if [[ $confirm == [yY] ]]; then
        docker stop sentinel-dvpn-node
        docker rm sentinel-dvpn-node
        rm -rf ${HOME_NODE}/.sentinelnode
        echo -e "${GREEN}Node removed successfully${NOCOLOR}"
    fi
    read -p "Press any key to continue..." -n1 -s
}

# Check if running as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Aborting: run as root user!"
    exit 1
fi

# Get public IP
IP_PUBLIC=$(ip addr show $(ip route get 8.8.8.8 | grep -oP '(?<=dev )(\S+)') | grep inet | grep -v inet6 | awk '{print $2}' | awk -F"/" '{print $1}')

# Initialize colors
format:color

# Start the menu
main_menu
