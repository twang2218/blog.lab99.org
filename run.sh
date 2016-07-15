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
        deploy) hexo deploy -g ;;
        *)      echo "Usage: $0 {update|pull|server|deploy}" ;;
    esac
}

# Entrypoint
main $@
