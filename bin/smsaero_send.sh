#!/usr/bin/env bash

source /usr/local/bin/smsaero.sh

send_sms() {
    local email="$1"
    local api_key="$2"
    local phone="$3"
    local message="$4"

    smsaero_init "$email" "$api_key"
    smsaero_send_sms "$phone" "$message"
}

main() {
    while [[ "$#" -gt 0 ]]; do
        case $1 in
        --email)
            email="$2"
            shift
            ;;
        --api_key)
            api_key="$2"
            shift
            ;;
        --phone)
            phone="$2"
            shift
            ;;
        --message)
            message="$2"
            shift
            ;;
        *)
            echo "Unknown parameter passed: $1"
            exit 1
            ;;
        esac
        shift
    done

    if [[ -z "$email" || -z "$api_key" || -z "$phone" || -z "$message" ]]; then
        echo "Usage: $0 --email <email> --api_key <api_key> --phone <phone> --message <message>"
        exit 1
    fi

    send_sms "$email" "$api_key" "$phone" "$message"
    if [[ $? -eq 0 ]]; then
        echo "SMS sent successfully."
    else
        echo "Failed to send SMS."
        exit 1
    fi
}

main "$@"
