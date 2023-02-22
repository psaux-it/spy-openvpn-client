#!/bin/bash
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

# declare associative array
declare -A clients

# set color
setup_terminal () {
  green="$(tput setaf 2)"; red="$(tput setaf 1)"; reset="$(tput sgr 0)"
  cyan="$(tput setaf 6)"; magenta="$(tput setaf 5)"
  TPUT_BOLD="$(tput bold)"; TPUT_BGRED="$(tput setab 1)"
  TPUT_WHITE="$(tput setaf 7)"; m_tab='  '; TPUT_RESET="$(tput sgr 0)"
}
setup_terminal

# fatal
fatal () {
  printf >&2 "\n${m_tab}%s ABORTED %s %s \n\n" "${TPUT_BGRED}${TPUT_WHITE}${TPUT_BOLD}" "${TPUT_RESET}" "${*}"
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
  echo "cannot find script path!"
  exit 1
fi

# here we create associative array
# key-value --> client name-static ip
for each in $(find "${ccd}" -type f -exec basename {} \;)
do
 clients[${each}]=$(< "${ccd}/${each}" grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | grep "$(echo "${pool}" | awk -v FS='.' '{print $1"."$2}')")
done

# list OpenVPN clients
list_clients () {
  echo -e "\n${m_tab}${cyan}# OpenVPN Clients"
  echo -e "${m_tab} --------------------------------${reset}"
  while read -r line
  do
    echo -e "${m_tab}${magenta}$(echo "${line}" | sed 's/^/  /')${reset}"
  done < <(find "${ccd}" -type f -exec basename {} \; | paste - - -)
  echo -e "${cyan}${m_tab} --------------------------------${reset}"
  echo ""
}

# check openvpn client existence
check_client () {
  if [[ ! " ${!clients[*]} " =~ " ${1} " ]]; then
    fatal "Cannot find OpenVPN client --> ${1}! Use --list to show OpenVPN Clients."
  fi
}

# parse http traffic for all openvpn client
# this can take long time if you have many client
all_clients () {
  list_clients

  # here we create new associative array
  # key-value --> client name-http_traffic
  declare -A http

  for client in ${!clients[@]}
  do
    eval "http[${client}]=\"$(find "${queries%/*}/" -name \*"${queries##*/}"* -print0 2>/dev/null |
                              # search openvpn client static IP in all files (logrotated ones included)
                              xargs -0 zgrep -i ${clients[${client}]} |
                              # parse queries for this client
                              awk '{for(i=1; i<=NF; i++) if($i~/query:/) print $1" "$(i+1)}' |
                              # normalize data
                              awk -F: '{print $2 $3}' |
                              # output to lowercase for better handling duplicates
                              tr '[:upper:]' '[:lower:]' |
                              # remove duplicate queries
                              awk '!a[$0]++' |
                              # sort by date
                              sort -b -t- -k2,2 -k1,1)\""
  done

  # save per openvpn client http traffic to file
  for client in ${!http[@]}
  do
    echo "${http[${client}]}" > "${this_script_path}"/http_traffic_"${client}"
    echo "${cyan}${m_tab}Openvpn Client --> ${magenta}${client}${reset} ${cyan}--> HTTP traffic saved in --> ${magenta}${this_script_path}"/http_traffic_"${client}${reset}"
  done
  echo ""
}

# parse http traffic for specific openvpn client
single_client () {
  check_client "${1}"
  local single="$(find "${queries%/*}/" -name \*"${queries##*/}"* -print0 2>/dev/null |
                  # search openvpn client static IP in all files (logrotated ones included)
                  xargs -0 zgrep -i ${clients[${1}]} |
                  # parse queries for this client
                  awk '{for(i=1; i<=NF; i++) if($i~/query:/) print $1" "$(i+1)}' |
                  # normalize data
                  awk -F: '{print $2 $3}' |
                  # output to lowercase for better handling duplicates
                  tr '[:upper:]' '[:lower:]' |
                  # remove duplicate queries
                  awk '!a[$0]++' |
                  # sort by date
                  sort -b -t- -k2,2 -k1,1)"

  echo "${single}" > "${this_script_path}"/http_traffic_"${1}"
  echo -e "\n${cyan}${m_tab}Openvpn Client --> ${magenta}${1}${reset} ${cyan}--> HTTP traffic saved in --> ${magenta}${this_script_path}"/http_traffic_"${1}${reset}\n"
}

# live watch http traffic for specific OpenVPN client
watch_client () {
  check_client "${1}"
  tail -f "${queries}" | grep --line-buffered "${clients[${1}]}" | awk '{for(i=1; i<=NF; i++) if($i~/query:/) print $1" "$(i+1)}'
}

# help
help () {
  echo -e "\n${m_tab}${cyan}# Script Help"
  echo -e "${m_tab}# --------------------------------------------------------------------------------------------------------------------"
  echo -e "${m_tab}#${m_tab}  -a | --all-clients   get all OpenVPN clients http traffic to separate file e.g ./spy_vpn.sh --all-clients"
  echo -e "${m_tab}#${m_tab}  -c | --client        get specific OpenVPN client http traffic to file e.g ./spy_vpn.sh --client JohnDoe"
  echo -e "${m_tab}#${m_tab}  -l | --list          list OpenVPN clients e.g ./spy_vpn.sh --list"
  echo -e "${m_tab}#${m_tab}  -w | --watch         live watch specific OpenVPN client http traffic ./spy_vpn.sh --watch JohnDoe"
  echo -e "${m_tab}#${m_tab}  -h | --help          help screen"
  echo -e "${m_tab}# ----------------------------------------------------------------------------------------------------------------------${reset}\n"
}

# invalid script option
inv_opt () {
  printf "%s\\n" "${red}${prog_name}: Invalid option '$1'${reset}"
  printf "%s\\n" "${cyan}Try '${script_name} --help' for more information.${reset}"
  exit 1
}

# script management
main () {
  if [[ "$#" -eq 0 || "$#" -gt 2 ]]; then
    printf "%s\\n" "${red}${prog_name}: Argument required or too many argument${reset}"
    printf "%s\\n" "${cyan}Try '${script_name} --help' for more information.${reset}"
    exit 1
  fi

  # set script arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -a  | --all-clients ) all_clients      ;;
      -c  | --client      ) single_client $2 ;;
      -w  | --watch       ) watch_client  $2 ;;
      -l  | --list        ) list_clients     ;;
      -h  | --help        ) help             ;;
      --  | -* | *        ) inv_opt          ;;
    esac
    break
  done
}

# Call main
main "${@}"
