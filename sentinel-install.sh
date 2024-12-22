#!/bin/bash

# Colors for output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
RESET="\033[0m"

# Sentinel repository
REPO="https://github.com/sentinel-official/sentinel"

# Display menu
show_menu() {
  echo -e "${CYAN}Sentinel dVPN Node Manager${RESET}"
  echo "1) Install Sentinel dVPN Node"
  echo "2) Restart Node"
  echo "3) Stop Node"
  echo "4) View Logs"
  echo "5) Remove Node"
  echo "6) Wallet Management"
  echo "7) Update Configuration"
  echo "8) Exit"
}

# Install Sentinel dVPN Node
install_node() {
  echo -e "${GREEN}Installing Sentinel dVPN Node...${RESET}"

  # Update and install dependencies
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y git make gcc jq docker.io docker-compose

  # Clone repository and set up node
  if [ ! -d "sentinel" ]; then
    git clone $REPO
  fi
  cd sentinel
  make install

  # Set up Docker Compose
  if [ ! -f "docker-compose.yml" ]; then
    curl -O https://raw.githubusercontent.com/sentinel-official/sentinel/master/docker-compose.yml
  fi

  # Open necessary ports
  echo -e "${YELLOW}Configuring firewall...${RESET}"
  sudo ufw allow 80/tcp comment "http"
  sudo ufw allow 443/tcp comment "http"
  sudo ufw reload

  # Start node
  echo -e "${GREEN}Starting Sentinel node...${RESET}"
  docker-compose up -d

  echo -e "${GREEN}Installation complete!${RESET}"
}

# Restart the Sentinel node
restart_node() {
  echo -e "${YELLOW}Restarting Sentinel node...${RESET}"
  docker-compose down
  docker-compose up -d
  echo -e "${GREEN}Node restarted successfully.${RESET}"
}

# Stop the Sentinel node
stop_node() {
  echo -e "${YELLOW}Stopping Sentinel node...${RESET}"
  docker-compose down
  echo -e "${GREEN}Node stopped.${RESET}"
}

# View logs
view_logs() {
  echo -e "${YELLOW}Displaying Sentinel node logs...${RESET}"
  docker-compose logs -f
}

# Remove Sentinel node
remove_node() {
  echo -e "${RED}Removing Sentinel node...${RESET}"
  docker-compose down
  cd ..
  rm -rf sentinel
  echo -e "${GREEN}Node removed successfully.${RESET}"
}

# Wallet management
wallet_management() {
  echo -e "${CYAN}Wallet Management${RESET}"
  echo "1) Create New Wallet"
  echo "2) Recover Wallet"
  echo "3) View Wallet Address"
  echo "4) Exit"

  read -p "Select an option: " wallet_choice
  case $wallet_choice in
    1)
      echo -e "${YELLOW}Creating new wallet...${RESET}"
      sentinelcli keys add dvpn_wallet
      ;;
    2)
      echo -e "${YELLOW}Recovering wallet...${RESET}"
      read -p "Enter your seed phrase: " seed_phrase
      sentinelcli keys add dvpn_wallet --recover <<< "$seed_phrase"
      ;;
    3)
      echo -e "${YELLOW}Fetching wallet address...${RESET}"
      sentinelcli keys show dvpn_wallet -a
      ;;
    4)
      return
      ;;
    *)
      echo -e "${RED}Invalid choice.${RESET}"
      ;;
  esac
}

# Update configuration
update_config() {
  echo -e "${CYAN}Updating Configuration${RESET}"

  CONFIG_FILE="~/.sentinel/config/config.toml"

  if [ -f "$CONFIG_FILE" ]; then
    read -p "Enter Moniker: " moniker
    sed -i "s/^moniker = .*/moniker = \"$moniker\"/" $CONFIG_FILE

    read -p "Enter RPC address: " rpc_address
    sed -i "s/^laddr = .*/laddr = \"$rpc_address\"/" $CONFIG_FILE

    echo -e "${GREEN}Configuration updated.${RESET}"
  else
    echo -e "${RED}Configuration file not found.${RESET}"
  fi
}

# Main loop
while true; do
  show_menu
  read -p "Enter your choice: " choice

  case $choice in
    1)
      install_node
      ;;
    2)
      restart_node
      ;;
    3)
      stop_node
      ;;
    4)
      view_logs
      ;;
    5)
      remove_node
      ;;
    6)
      wallet_management
      ;;
    7)
      update_config
      ;;
    8)
      echo -e "${CYAN}Exiting...${RESET}"
      break
      ;;
    *)
      echo -e "${RED}Invalid choice. Please try again.${RESET}"
      ;;
  esac

  echo
done
