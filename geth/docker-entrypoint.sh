#!/usr/bin/env bash

if [ "$(id -u)" = '0' ]; then
  chown -R geth:geth /var/lib/goethereum
  exec su-exec geth docker-entrypoint.sh "$@"
fi

if [ -n "${JWT_SECRET}" ]; then
  echo -n "${JWT_SECRET}" > /var/lib/goethereum/ee-secret/jwtsecret
  echo "JWT secret was supplied in .env"
fi

if [[ ! -f /var/lib/goethereum/ee-secret/jwtsecret ]]; then
  echo "Generating JWT secret"
  __secret1=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  __secret2=$(head -c 8 /dev/urandom | od -A n -t u8 | tr -d '[:space:]' | sha256sum | head -c 32)
  echo -n "${__secret1}""${__secret2}" > /var/lib/goethereum/ee-secret/jwtsecret
fi

if [[ -O "/var/lib/goethereum/ee-secret" ]]; then
  # In case someone specificies JWT_SECRET but it's not a distributed setup
  chmod 777 /var/lib/goethereum/ee-secret
fi
if [[ -O "/var/lib/goethereum/ee-secret/jwtsecret" ]]; then
  chmod 666 /var/lib/goethereum/ee-secret/jwtsecret
fi

# Set verbosity
shopt -s nocasematch
case ${LOG_LEVEL} in
  error)
    __verbosity="--verbosity 1"
    ;;
  warn)
    __verbosity="--verbosity 2"
    ;;
  info)
    __verbosity="--verbosity 3"
    ;;
  debug)
    __verbosity="--verbosity 4"
    ;;
  trace)
    __verbosity="--verbosity 5"
    ;;
  *)
    echo "LOG_LEVEL ${LOG_LEVEL} not recognized"
    __verbosity=""
    ;;
esac

if [ "${ARCHIVE_NODE}" = "true" ]; then
  echo "Geth archive node without pruning"
  __prune="--syncmode=full --gcmode=archive"
else
  __prune=""
fi

# Detect existing DB; use PBSS if fresh
#if [ -d "/var/lib/goethereum/geth/chaindata/" ]; then
#  __pbbsme=""
#else
#  echo "Choosing PBSS for fresh sync"
#  __pbbsme="--trie.path-based"
#fi

if [ -f /var/lib/goethereum/prune-marker ]; then
  rm -f /var/lib/goethereum/prune-marker
  if [ "${ARCHIVE_NODE}" = "true" ]; then
    echo "Geth is an archive node. Not attempting to prune: Aborting."
    exit 1
  fi
# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
  exec "$@" ${EL_EXTRAS} snapshot prune-state
else
# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
  exec "$@" ${__prune} ${__verbosity} ${EL_EXTRAS}
fi
