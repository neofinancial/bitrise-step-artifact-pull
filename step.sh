#!/bin/bash

RESTORE='\033[0m'
RED='\033[00;31m'
YELLOW='\033[00;33m'
BLUE='\033[00;36m'
GREEN='\033[00;32m'

error()
{
    echo -e "${RED}[ERROR] ${1}${RESTORE}" >&2
}

warn()
{
    echo -e "${YELLOW}[WARNING] ${1} ${RESTORE}" >&2
}

info()
{
    echo -e "${BLUE}[INFO]${RESTORE} ${1}" >&2
}

output_state()
{
    info "Bash version: ${BASH_VERSION}"
    info "jq version:   $(jq --version)"
    info "Current path: $(pwd)"
    info "artifact_file: $artifact_file"
    info "download_dir: $download_dir"
    info "app_slug: $app_slug"
    info "source_build_slug: $source_build_slug"
}


validate_input()
{
    if [ -z "$artifact_file" ]; then
        error "Please specify the file name of the artifact to download as the argument 'artifact_file'"
        exit 1
    fi

    if [ -z "$download_dir" ]; then
        error "Please specify the download directory as the argument 'download_dir'"
        exit 1
    fi

    if [ -z "$app_slug" ]; then
        error "Please define app_slug"
        exit 1
    fi

    if [ -z "$access_token" ]; then
        error "Please define BITRISE_KEY"
        exit 1
    fi

    if [ -z "$source_build_slug" ]; then
        error "Please define source_build_slug"
        exit 1
    fi
}

fetch_artifact_manifest()
{
    URL="https://api.bitrise.io/v0.1/apps/$app_slug/builds/$source_build_slug/artifacts"
    local JSON=$(curl -s -X GET $URL -H "accept: application/json" -H "Authorization: $access_token")
    echo $JSON > manifest.json
}

get_total_item_count()
{
    echo $(cat manifest.json | jq ".paging .total_item_count")
}

get_artifact_url()
{
    SLUG=${1//\"/}
    URL="https://api.bitrise.io/v0.1/apps/$app_slug/builds/$source_build_slug/artifacts/$SLUG"
    local JSON=$(curl -s -X GET $URL -H "accept: application/json" -H "Authorization: $access_token")
    echo $JSON > file.info.json
    local retval=$(cat file.info.json | jq ".data .expiring_download_url")
    echo $retval
}

download_artifact()
{
    info "Downloading $artifact_file to $DOWNLOAD_PATH/$artifact_file"

    TOTAL_ITEM_COUNT=$(get_total_item_count)
    if [[ "$TOTAL_ITEM_COUNT" == "0" ]]; then
        error "No artifacts to download found"
        exit 1
    fi

    END=$(expr $TOTAL_ITEM_COUNT)
    for ((i=0;i<END;i++));
    do
       slug=$(cat manifest.json | jq ".data[$i] .slug")
       title=$(cat manifest.json | jq ".data[$i] .title")
       title=${title//\"/}

       if [[ $title == *"$artifact_file"* ]]; then
         url=$(get_artifact_url $slug)
         url=${url//\"/}
         curl -s $url -o "$DOWNLOAD_PATH/$title"
       fi
    done
}

clean_up()
{
    rm -f manifest.json
    rm -f file.info.json
}

main() {
    output_state
    validate_input

    DOWNLOAD_PATH="$BITRISE_SOURCE_DIR/$download_dir"
    mkdir -p $DOWNLOAD_PATH

    fetch_artifact_manifest
    download_artifact
    clean_up

    exit 0
}

main