#!/usr/bin/env bash
#
# Copyright (C) 2023 Hasan ÇALIŞIR <hasan.calisir@psauxit.com>
# Distributed under the GNU General Public License, version 2.0.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# ---------------------------------------------------------------------
# Written by  : (hsntgm) Hasan ÇALIŞIR - hasan.calisir@psauxit.com
#                                        https://www.psauxit.com/
# --------------------------------------------------------------------
#
# The aim of this script is spying OpenVPN client's HTTP traffic.
# - Visit https://www.psauxit.com/secured-openvpn-clients-dnscrypt/
# - blog post for detailed instructions.

# ADJUST USER DEFINED SETTINGS
####################################################
# set your ccd path that holds each client static IP
ccd="/etc/openvpn/server/ccd"

# set your bind queries log path
queries="/var/log/named/queries.log"

# set your openvpn clients IP Pool
# max 255.255.0.0
pool="10.8.0.0"
####################################################

# pool prefix
pool_prefix="${pool%.*}"

# set color
red=$(tput setaf 1)
cyan=$(tput setaf 6)
magenta=$(tput setaf 5)
TPUT_BOLD=$(tput bold)
TPUT_BGRED=$(tput setab 1)
TPUT_WHITE=$(tput setaf 7)
reset=$(tput sgr 0)
printf -v m_tab '%*s' 2 ''

# fatal
fatal () {
  printf >&2 "\n${m_tab}%s ABORTED %s %s \n\n" "${TPUT_BGRED}${TPUT_WHITE}${TPUT_BOLD}" "${reset}" "${@}"
  exit 1
}

# discover script path
this_script_full_path="${BASH_SOURCE[0]}"
if command -v dirname >/dev/null 2>&1 && command -v readlink >/dev/null 2>&1 && command -v basename >/dev/null 2>&1; then
  # Symlinks
  while [[ -h "${this_script_full_path}" ]]; do
    this_script_path="$( cd -P "$( dirname "${this_script_full_path}" )" >/dev/null 2>&1 && pwd )"
    this_script_full_path="$(readlink "${this_script_full_path}")"
    # Resolve
    if [[ "${this_script_full_path}" != /* ]] ; then
      this_script_full_path="${this_script_path}/${this_script_full_path}"
    fi
  done
  this_script_path="$( cd -P "$( dirname "${this_script_full_path}" )" >/dev/null 2>&1 && pwd )"
  this_script_name="$(basename "${this_script_full_path}")"
else
  fatal "Cannot find script path! Check you have dirname,readlink,basename tools"
fi

# declare associative array
declare -A clients

# populate array
# key-value --> client name-static ip
while read -r each
do
  clients[${each}]=$(< "${ccd}/${each}" grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | grep "${pool_prefix}")
done < <(find "${ccd}" -type f -exec basename {} \;)

# list OpenVPN clients
list_clients () {
  printf '\n%s%s# OpenVPN Clients\n' "$m_tab" "$cyan"
  printf '%s --------------------------------%s\n' "$m_tab" "$reset"
  while read -r line
  do
    printf '%s%s%s\n' "$m_tab" "$magenta" "$(printf '  %s' "$line")$reset"
  done < <(find "$ccd" -type f -exec basename {} \; | paste - - -)
  printf '%s%s --------------------------------%s\n\n' "$cyan" "$m_tab" "$reset"
}

# check openvpn client existence
check_client () {
  if [[ -z "${clients["$1"]}" ]]; then
    fatal "Cannot find OpenVPN client --> $1! Use --list to show OpenVPN Clients."
  fi
}

# parse http traffic for all openvpn clients, this will be run in parallel
# this can cause high cpu usage if you have many clients and heavy internet traffic
all_clients () {
  list_clients
  num_cores=$(nproc)

  # create a function to parse HTTP traffic for a single client
  parse_traffic () {
    local client output ip
    client="${1}"
    ip="${clients[$client]}"
    # search openvpn client static IP (logrotated ones included), parse DNS queries, sort
    output="$(find "${queries%/*}/" -name "*${queries##*/}*" -type f -exec zgrep -i -h "${ip}" {} + |
      awk 'match($0, /query:[[:space:]]*([^[:space:]]+)/, a) {print $1" "$2" "a[1]}' |
      sort -s -k1.8n -k1.4M -k1.1n)"
    # save per openvpn client http traffic to file
    printf "%s\n" "${output}" > "${this_script_path}/http_traffic_${client}"
    printf "%s\n" "${cyan}${m_tab}Openvpn Client --> ${magenta}${client}${reset} ${cyan}--> HTTP traffic saved in --> ${magenta}${this_script_path}/http_traffic_${client}${reset}"
  }

  # Loop through the clients and parse their HTTP traffic in parallel
  # Limit the number of parallel processes to the number of CPU core
  for client in "${!clients[@]}"; do
    parse_traffic "${client}" &
    if (( $(jobs -r -p | wc -l) >= num_cores )); then
      wait -n
    fi
  done
  wait
  printf "\n"
}

# parse http traffic for specific openvpn client
single_client () {
  local single ip
  check_client "${1}"
  ip="${clients[${1}]}"
  # search openvpn client static IP (logrotated ones included) and parse DNS queries
  single="$(find "${queries%/*}/" -name "*${queries##*/}*" -type f -exec zgrep -i -h "${ip}" {} + |
    awk 'match($0, /query:[[:space:]]*([^[:space:]]+)/, a) {print $1" "$2" "a[1]}' |
    sort -s -k1.8n -k1.4M -k1.1n)"
  # save client http traffic to file
  printf "%s\n" "${single}" > "${this_script_path}/http_traffic_${1}"
  printf "\n"
  printf "%s\n" "${cyan}${m_tab}Openvpn Client --> ${magenta}${1}${reset} ${cyan}--> HTTP traffic saved in --> ${magenta}${this_script_path}/http_traffic_${1}${reset}"
  printf "\n"
}

# live watch http traffic for specific OpenVPN client
watch_client () {
  check_client "${1}"
  tail -f "${queries}" | grep --line-buffered "${clients[${1}]}" | awk '{for(i=1; i<=NF; i++) if($i~/query:/) printf "\033[35m%s\033[39m \033[36m%s\033[39m\n", $1, $(i+1)}'
}

# help
help () {
  printf "\n"
  printf "%s\n" "${m_tab}${cyan}# Script Help"
  printf "%s\n" "${m_tab}# --------------------------------------------------------------------------------------------------------------------"
  printf "%s\n" "${m_tab}#${m_tab}  -a | --all-clients   get all OpenVPN clients http traffic to separate file e.g ./spy_vpn.sh --all-clients"
  printf "%s\n" "${m_tab}#${m_tab}  -c | --client        get specific OpenVPN client http traffic to file e.g ./spy_vpn.sh --client JohnDoe"
  printf "%s\n" "${m_tab}#${m_tab}  -l | --list          list OpenVPN clients e.g ./spy_vpn.sh --list"
  printf "%s\n" "${m_tab}#${m_tab}  -w | --watch         live watch specific OpenVPN client http traffic ./spy_vpn.sh --watch JohnDoe"
  printf "%s\n" "${m_tab}#${m_tab}  -h | --help          help screen"
  printf "%s\n" "${m_tab}# ----------------------------------------------------------------------------------------------------------------------${reset}"
  printf "\n"
}

# invalid script option
inv_opt () {
  printf "\n"
  printf "%s\\n" "${red}${m_tab}Invalid option${reset}"
  printf "%s\\n" "${cyan}${m_tab}Try './${this_script_name} --help' for more information.${reset}"
  printf "\n"
  exit 1
}

# script management
main () {
  if [[ "$#" -eq 0 || "$#" -gt 2 ]]; then
    printf "\n"
    printf "%s\\n" "${red}${m_tab}Argument required or too many argument${reset}"
    printf "%s\\n" "${cyan}${m_tab}Try './${this_script_name} --help' for more information.${reset}"
    printf "\n"
    exit 1
  fi

  # set script arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -a  | --all-clients ) all_clients        ;;
      -c  | --client      ) single_client "$2" ;;
      -w  | --watch       ) watch_client  "$2" ;;
      -l  | --list        ) list_clients       ;;
      -h  | --help        ) help               ;;
      *                   ) inv_opt            ;;
    esac
    break
  done
}

# Call main
main "${@}"
