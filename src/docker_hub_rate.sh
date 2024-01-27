#!/bin/sh
# Copyright (C) 2023 Shizun Ge
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
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

_docker_hub_rate_token() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local USER_AND_PASS="${2}"
  local TOKEN_URL="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE}:pull"
  if curl --version 1>/dev/null 2>&1; then
    if [ -n "${USER_AND_PASS}" ]; then
      curl -s -S --user "${USER_AND_PASS}" "${TOKEN_URL}"
      return $?
    fi
    curl -s -S "${TOKEN_URL}"
    return $?
  fi
  [ -n "${USER_AND_PASS}" ] && log WARN "Cannot read docker hub rate for the given user because curl is not available."
  wget -qO- "${TOKEN_URL}"
}

_docker_hub_rate_read_rate() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local TOKEN="${2}"
  [ -z "${TOKEN}" ] && echo "[EMPTY TOKEN ERROR]" && return 1
  local HEADER="Authorization: Bearer ${TOKEN}"
  local URL="https://registry-1.docker.io/v2/${IMAGE}/manifests/latest"
  if curl --version 1>/dev/null 2>&1; then
    curl -s -S --head -H "${HEADER}" "${URL}" 2>&1
    return $?
  fi
  # Add `--spider`` implies that you want to send a HEAD request (as opposed to GET or POST).
  # The `busybox wget` does not send a HEAD request, thus it will consume a docker hub rate.
  wget -qS --spider --header="${HEADER}" -O /dev/null "${URL}" 2>&1
}

docker_hub_rate() {
  local IMAGE="${1:-ratelimitpreview/test}"
  local USER_AND_PASS="${2}"
  if ! log INFO "" 1>/dev/null 2>/dev/null; then
    # Assume the error is due to log function is not available.
    log() {
      echo "${*}" >&2
    }
  fi
  local RESPONSE=
  if ! RESPONSE=$(_docker_hub_rate_token "${IMAGE}" "${USER_AND_PASS}"); then
    log DEBUG "_docker_hub_rate_token error: RESPONSE=${RESPONSE}"
    echo "[GET TOKEN RESPONSE ERROR]"
    return 1
  fi
  local TOKEN=
  TOKEN=$(echo "${RESPONSE}" | sed 's/.*"token":"\([^"]*\).*/\1/')
  if [ -z "${TOKEN}" ]; then
    log DEBUG "parse token error: RESPONSE=${RESPONSE}"
    echo "[PARSE TOKEN ERROR]"
    return 1
  fi
  if ! RESPONSE=$(_docker_hub_rate_read_rate "${IMAGE}" "${TOKEN}"); then
    if echo "${RESPONSE}" | grep -q "Too Many Requests" ; then
      echo "0"
      return 0
    fi
    log DEBUG "_docker_hub_rate_read_rate error: RESPONSE=${RESPONSE}"
    echo "[GET RATE RESPONSE ERROR]"
    return 1
  fi
  local RATE=
  RATE=$(echo "${RESPONSE}" | sed -n 's/.*ratelimit-remaining: \([0-9]*\).*/\1/p' )
  if [ -z "${RATE}" ]; then
    log DEBUG "parse rate error: RESPONSE=${RESPONSE}"
    echo "[PARSE RATE ERROR]"
    return 1
  fi
  echo "${RATE}"
}
