#!/bin/bash

function update {
    git submodule update --recursive $@
}

function pull {
    git pull --recurse-submodules $@
}

function main {
    Command=$1
    shift
    case "${Command}" in
        update) update $@ ;;
        pull)   pull $@ ;;
        server) hexo server ;;
        *)      echo "Usage: $0 {update|pull|server}" ;;
    esac
}

# Entrypoint
main $@
