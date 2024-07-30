# SmsAero Bash Library
#
# This library provides a set of functions for interacting with the SmsAero API using Bash scripting.
# It allows for sending SMS messages, checking the status of sent messages, managing contacts and groups,
# managing the blacklist, and more, directly from the command line or within Bash scripts.
#
# Example Usage:
# source /usr/local/bin/smsaero.sh
#
# smsaero_init 'your email' 'your api key'
# smsaero_send_sms '70000000000' 'Hello, World!'
#
# This library also includes functions for error handling and logging,
# making it easier to debug issues that may occur when interacting with the SmsAero API.
#
# Functions:
# - `smsaero_init`: Initializes the library with your SmsAero credentials.
# - `smsaero_send_sms`: Sends an SMS message.
# - `smsaero_sms_status`: Checks the status of a sent SMS message.
# - `smsaero_contact_add`, `smsaero_contact_delete`: Manage your contacts.
# - `smsaero_group_add`, `smsaero_group_delete`: Manage your groups.
# - `smsaero_blacklist_add`, `smsaero_blacklist_delete`: Manage your blacklist.
# - And many more for comprehensive interaction with the SmsAero API.
#
# Error Handling:
# The library functions return error messages directly to standard error (stderr) and may exit with a non-zero status
# code for critical failures, allowing for simple error handling in scripts.
#
# Dependencies:
# - `jq`: For parsing JSON responses.
# - `curl`: For making HTTP requests.
# - `sed`: For text manipulation.
# - `perl` or `python3`: For URL encoding.
#
# Ensure these dependencies are installed on your system to use the library.

SMSAERO_EMAIL=""
SMSAERO_API_KEY=""
SMSAERO_SIGNATURE="Sms Aero"
SMSAERO_TIMEOUT=15
SMSAERO_GATE=""
SMSAERO_TEST_MODE=0
SMSAERO_ENABLE_LOGGER=0

SMSAERO_GATE_URLS=(
    "@gate.smsaero.ru/v2/"
    "@gate.smsaero.org/v2/"
    "@gate.smsaero.net/v2/"
)

# smsaero_init: Initializes the library with your SmsAero credentials.
# Arguments:
#   $1 - email (required): Your SmsAero account email.
#   $2 - api_key (required): Your SmsAero API key.
#   $3 - signature (optional): The signature to use (default: SmsAero signature).
#   $4 - timeout (optional): Request timeout in seconds (default: 15).
#   $5 - gate (optional): Gate URL to use.
#   $6 - test_mode (optional): Enable test mode (default: 0).
# Returns:
#   0 on success, non-zero on error.
smsaero_init() {
    smsaero_check_dependencies || return 1

    SMSAERO_EMAIL=$(smsaero_urlencode "$1")
    [[ $? -ne 0 ]] && return 1

    local sign="${3:-$SMSAERO_SIGNATURE}"
    sign=$(smsaero_clean_string "$sign")

    SMSAERO_API_KEY="$2"
    SMSAERO_SIGNATURE="$sign"
    SMSAERO_TIMEOUT="${4:-$SMSAERO_TIMEOUT}"
    SMSAERO_GATE="$5"
    SMSAERO_TEST_MODE="${6:-$SMSAERO_TEST_MODE}"

    smsaero_log_info "SmsAero initialized with email: $SMSAERO_EMAIL"
}

# smsaero_is_authorized: Checks if the provided credentials are authorized to access the SmsAero API.
# This function sends a request to the SmsAero API to verify if the current credentials (email and API key) are valid.
# No arguments are required as it uses the credentials initialized with `smsaero_init`.
# Returns:
#   0 if authorized, non-zero if not authorized or if an error occurs.
smsaero_is_authorized() {
    local response
    response=$(smsaero_send_request "auth" "")
    if [[ $? -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# smsaero_send_sms: Sends an SMS message
# Arguments:
#   $1 - phone (required): The phone number to send the SMS to
#   $2 - text (required): The message text
#   $3 - sign (optional): The signature (default: SmsAero signature)
#   $4 - date_to_send (optional): Date to send the message (default: immediately)
#   $5 - callback_url (optional): URL for callback on delivery
# Returns:
#   0 on success, non-zero on error
smsaero_send_sms() {
    smsaero_validate_required_numeric_field "$1" "phone"
    [[ $? -ne 0 ]] && return 1

    smsaero_validate_required_field "$2" "text"
    [[ $? -ne 0 ]] && return 1

    local sign="${3:-$SMSAERO_SIGNATURE}"
    sign=$(smsaero_clean_string "$sign")

    local phone="$1"
    local text="$2"
    local sign="${3:-$SMSAERO_SIGNATURE}"
    local date_to_send="$4"
    local callback_url="$5"
    local data
    data="{\"text\": \"$(echo "$text" | sed 's/"/\\"/g')\", \"sign\": \"$sign\""

    [[ -n "$callback_url" ]] && data="$data, \"callbackUrl\": \"$callback_url\""
    [[ -n "$date_to_send" ]] && data="$data, \"dateSend\": $(date -d "$date_to_send" +%s)"
    data="$data, \"number\": \"$phone\"}"

    local endpoint="sms/send"
    [[ "$SMSAERO_TEST_MODE" -eq 1 ]] && endpoint="sms/testsend"

    smsaero_send_request "$endpoint" "$data"
}

# smsaero_sms_status: Checks the status of a sent SMS message.
# Arguments:
#   $1 - sms_id (required): The ID of the SMS message whose status is to be checked.
# Returns:
#   0 on success, non-zero on error. Outputs the status of the SMS message.
smsaero_sms_status() {
    smsaero_validate_required_numeric_field "$1" "sms_id"
    if [[ $? -ne 0 ]]; then return 1; fi

    local sms_id="$1"
    local data="{\"id\": $sms_id}"

    local endpoint="sms/status"
    [[ "$SMSAERO_TEST_MODE" -eq 1 ]] && endpoint="sms/teststatus"

    smsaero_send_request "$endpoint" "$data"
}

# smsaero_sms_list: Retrieves a list of sent SMS messages.
# Arguments:
#   $1 - page (optional): The page number for pagination.
#   $2 - phone (optional): Filter messages by the recipient's phone number.
#   $3 - text (optional): Filter messages by text content.
# Returns:
#   0 on success, non-zero on error. Outputs the list of SMS messages.
smsaero_sms_list() {
    local page="$1"
    local phone="$2"
    local text="$3"
    local data="{}"

    if [[ -n "$phone" ]]; then
        smsaero_validate_required_numeric_field "$phone" "phone"
        if [[ $? -ne 0 ]]; then return 1; fi
        data="{\"number\": \"$phone\"}"
    fi
    if [[ -n "$text" ]]; then
        data="{\"text\": \"$text\"}"
    fi

    local endpoint="sms/list"
    [[ "$SMSAERO_TEST_MODE" -eq 1 ]] && endpoint="sms/testlist"

    smsaero_send_request "$endpoint" "$data" "$page"
}

# smsaero_hlr_check: Performs an HLR lookup for a given phone number.
# Arguments:
#   $1 - number (required): The phone number to perform the HLR lookup on.
# Returns:
#   0 on success, non-zero on error. Outputs the HLR lookup result.
smsaero_hlr_check() {
    smsaero_validate_required_numeric_field "$1" "number"
    if [[ $? -ne 0 ]]; then return 1; fi

    local number="$1"
    local data="{\"number\": \"$number\"}"
    smsaero_send_request "hlr/check" "$data"
}

# smsaero_hlr_status: Checks the status of HLR lookup.
# Arguments:
#   $1 - hlr_id (required): The ID of the HLR lookup whose status is to be checked.
# Returns:
#   0 on success, non-zero on error. Outputs the status of the HLR lookup.
smsaero_hlr_status() {
    smsaero_validate_required_numeric_field "$1" "hlr_id"
    if [[ $? -ne 0 ]]; then return 1; fi

    local hlr_id="$1"
    local data="{\"id\": $hlr_id}"
    smsaero_send_request "hlr/status" "$data"
}

# smsaero_number_operator: Determines the mobile operator for a given phone number.
# Arguments:
#   $1 - phone (required): The phone number whose operator is to be determined.
# Returns:
#   0 on success, non-zero on error. Outputs the mobile operator of the phone number.
smsaero_number_operator() {
    smsaero_validate_required_numeric_field "$1" "phone"
    if [[ $? -ne 0 ]]; then return 1; fi

    local phone="$1"
    local data="{\"number\": \"$phone\"}"
    smsaero_send_request "number/operator" "$data"
}

# smsaero_balance: Retrieves the current balance of the SmsAero account.
# No arguments are required.
# Returns:
#   0 on success, non-zero on error. Outputs the account balance.
smsaero_balance() {
    smsaero_send_request "balance" ""
}

# smsaero_cards: Retrieves a list of payment cards associated with the SmsAero account.
# No arguments are required.
# Returns:
#   0 on success, non-zero on error. Outputs the list of payment cards.
smsaero_cards() {
    smsaero_send_request "cards" ""
}

# smsaero_tariffs: Retrieves the current tariffs and pricing information for the SmsAero account.
# No arguments are required.
# Returns:
#   0 on success, non-zero on error. Outputs the tariffs and pricing information.
smsaero_tariffs() {
    smsaero_send_request "tariffs" ""
}

# smsaero_sign_list: Retrieves a list of signatures associated with the SmsAero account.
# Arguments:
#   $1 - page (optional): The page number for pagination.
# Returns:
#   0 on success, non-zero on error. Outputs the list of signatures.
smsaero_sign_list() {
    local page="$1"
    smsaero_send_request "sign/list" "" "$page"
}

# smsaero_group_add: Adds a new group to the SmsAero account.
# Arguments:
#   $1 - name (required): The name of the group to be added.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the group addition.
smsaero_group_add() {
    smsaero_validate_required_field "$1" "name"
    if [[ $? -ne 0 ]]; then return 1; fi

    local name_escaped=$(echo "$1" | sed 's/"/\\"/g')
    local data="{\"name\": \"$name_escaped\"}"
    smsaero_send_request "group/add" "$data"
}

# smsaero_group_delete: Deletes a group from the SmsAero account.
# Arguments:
#   $1 - group_id (required): The ID of the group to be deleted.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the group deletion.
smsaero_group_delete() {
    smsaero_validate_required_numeric_field "$1" "group_id"
    if [[ $? -ne 0 ]]; then return 1; fi

    local group_id="$1"
    local data="{\"id\": $group_id}"
    smsaero_send_request "group/delete" "$data"
}

# smsaero_group_delete_all: Deletes all groups from the SmsAero account.
# No arguments are required.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the group deletion operation.
smsaero_group_delete_all() {
    smsaero_send_request "group/delete-all" ""
}

# smsaero_group_list: Retrieves a list of groups associated with the SmsAero account.
# Arguments:
#   $1 - page (optional): The page number for pagination.
# Returns:
#   0 on success, non-zero on error. Outputs the list of groups.
smsaero_group_list() {
    local page="$1"
    smsaero_send_request "group/list" "" "$page"
}

# smsaero_contact_add: Adds a contact to the SmsAero contact list.
# Arguments:
#   $1 - number (required): The phone number of the contact.
#   $2 - group_id (optional): The ID of the group to add the contact to.
#   $3 - birthday (optional): The birthday of the contact in YYYY-MM-DD format.
#   $4 - sex (optional): The gender of the contact (e.g., male, female).
#   $5 - lname (optional): The last name of the contact.
#   $6 - fname (optional): The first name of the contact.
#   $7 - sname (optional): The middle name of the contact.
#   $8 - param1 (optional): Additional parameter 1 for the contact.
#   $9 - param2 (optional): Additional parameter 2 for the contact.
#   $10 - param3 (optional): Additional parameter 3 for the contact.
# Returns:
#   0 on success, non-zero on error.
smsaero_contact_add() {
    smsaero_validate_required_numeric_field "$1" "number"
    if [[ $? -ne 0 ]]; then return 1; fi

    local number="$1"
    local group_id="$2"
    local birthday="$3"
    local sex="$4"
    local lname="$5"
    local fname="$6"
    local sname="$7"
    local param1="$8"
    local param2="$9"
    local param3="${10}"

    local data="{\"number\": \"$number\""
    [[ -n "$group_id" ]] && data="$data, \"groupId\": \"$group_id\""
    [[ -n "$birthday" ]] && data="$data, \"birthday\": \"$birthday\""
    [[ -n "$sex" ]] && data="$data, \"sex\": \"$sex\""
    [[ -n "$lname" ]] && data="$data, \"lname\": \"$lname\""
    [[ -n "$fname" ]] && data="$data, \"fname\": \"$fname\""
    [[ -n "$sname" ]] && data="$data, \"sname\": \"$sname\""
    [[ -n "$param1" ]] && data="$data, \"param1\": \"$param1\""
    [[ -n "$param2" ]] && data="$data, \"param2\": \"$param2\""
    [[ -n "$param3" ]] && data="$data, \"param3\": \"$param3\""
    data="$data}"

    smsaero_send_request "contact/add" "$data"
}

# smsaero_contact_delete: Deletes a contact from the SmsAero account.
# Arguments:
#   $1 - contact_id (required): The ID of the contact to be deleted.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the contact deletion.
smsaero_contact_delete() {
    smsaero_validate_required_numeric_field "$1" "contact_id"
    if [[ $? -ne 0 ]]; then return 1; fi

    local contact_id="$1"
    local data="{\"id\": $contact_id}"
    smsaero_send_request "contact/delete" "$data"
}

# smsaero_contact_delete_all: Deletes all contacts from the SmsAero account.
# No arguments are required.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the contact deletion operation.
smsaero_contact_delete_all() {
    smsaero_send_request "contact/delete-all" ""
}

# smsaero_contact_list: Retrieves a list of contacts associated with the SmsAero account.
# Arguments:
#   $1 - number (optional): Filter contacts by phone number.
#   $2 - group_id (optional): Filter contacts by group ID.
#   $3 - birthday (optional): Filter contacts by birthday.
#   $4 - sex (optional): Filter contacts by gender.
#   $5 - operator (optional): Filter contacts by mobile operator.
#   $6 - lname (optional): Filter contacts by last name.
#   $7 - fname (optional): Filter contacts by first name.
#   $8 - sname (optional): Filter contacts by second name.
#   $9 - page (optional): The page number for pagination.
# Returns:
#   0 on success, non-zero on error. Outputs the list of contacts.
smsaero_contact_list() {
    local number="$1"
    local group_id="$2"
    local birthday="$3"
    local sex="$4"
    local operator="$5"
    local lname="$6"
    local fname="$7"
    local sname="$8"
    local page="$9"

    local data="{"
    [[ -n "$number" ]] && data="$data\"number\": \"$number\", "
    [[ -n "$group_id" ]] && data="$data\"groupId\": \"$group_id\", "
    [[ -n "$birthday" ]] && data="$data\"birthday\": \"$birthday\", "
    [[ -n "$sex" ]] && data="$data\"sex\": \"$sex\", "
    [[ -n "$operator" ]] && data="$data\"operator\": \"$operator\", "
    [[ -n "$lname" ]] && data="$data\"lname\": \"$lname\", "
    [[ -n "$fname" ]] && data="$data\"fname\": \"$fname\", "
    [[ -n "$sname" ]] && data="$data\"sname\": \"$sname\""
    data="${data%, }"

    data="$data}"
    smsaero_send_request "contact/list" "$data" "$page"
}

# smsaero_blacklist_add: Adds a phone number to the SmsAero blacklist.
# Arguments:
#   $1 - number (required): The phone number to be added to the blacklist.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the blacklist addition operation.
smsaero_blacklist_add() {
    smsaero_validate_required_numeric_field "$1" "number"
    if [[ $? -ne 0 ]]; then return 1; fi

    local number="$1"
    local data="{\"number\": \"$number\"}"
    smsaero_send_request "blacklist/add" "$data"
}

# smsaero_blacklist_list: Retrieves a list of phone numbers from the SmsAero blacklist.
# Arguments:
#   $1 - number (optional): The phone number to filter the blacklist by.
#   $2 - page (optional): The page number for pagination.
# Returns:
#   0 on success, non-zero on error. Outputs the list of blacklisted phone numbers.
smsaero_blacklist_list() {
    local number="$1"
    local page="$2"
    local data="{}"
    [[ -n "$number" ]] && data="{\"number\": \"$number\"}"
    smsaero_send_request "blacklist/list" "$data" "$page"
}

# smsaero_blacklist_delete: Removes a phone number from the SmsAero blacklist.
# Arguments:
#   $1 - blacklist_id (required): The ID of the blacklist entry to be removed.
# Returns:
#   0 on success, non-zero on error. Outputs the result of the blacklist removal operation.
smsaero_blacklist_delete() {
    smsaero_validate_required_numeric_field "$1" "blacklist_id"
    if [[ $? -ne 0 ]]; then return 1; fi

    local blacklist_id="$1"
    local data="{\"id\": $blacklist_id}"
    smsaero_send_request "blacklist/delete" "$data"
}

########################################################################################################################

smsaero_log() {
    local level="$1"
    shift
    local message="$*"

    if [[ "$SMSAERO_ENABLE_LOGGER" -eq 1 ]]; then
        echo "$(date +"%Y-%m-%d %H:%M:%S") [$level] $message" >&2
        logger -t smsaero -p "user.$level" "$message"
    fi
}

smsaero_log_info() {
    smsaero_log info "$*"
}

smsaero_log_err() {
    smsaero_log err "$*"
}

smsaero_check_dependencies() {
    local missing_deps=()
    local dependencies=(jq curl sed)
    for cmd in "${dependencies[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if ((${#missing_deps[@]} > 0)); then
        echo "Error: The following dependencies are missing: ${missing_deps[*]}" >&2
        return 1
    fi

    return 0
}

smsaero_urlencode() {
    local input="$1"
    if command -v perl &>/dev/null; then
        echo $(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$input")
    elif command -v python3 &>/dev/null; then
        echo $(python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]))" "$input")
    else
        echo "Error: Neither perl nor python3 is available for URL encoding." >&2
        return 1
    fi
}

smsaero_clean_string() {
    local value="$1"
    value=$(echo "$value" | sed 's/[^a-zA-Z0-9_ -]//g')
    echo "$value"
}

smsaero_get_gate_urls() {
    if [[ -n "$SMSAERO_GATE" ]]; then
        echo "$SMSAERO_GATE"
    else
        printf "%s\n" "${SMSAERO_GATE_URLS[@]}"
    fi
}

smsaero_process_response() {
    local result="$1"
    local success="$2"
    local message="$3"
    local content="$4"

    if [[ "$result" == "no credits" ]]; then
        echo "Error: No money on the account" >&2
        return 1
    fi

    if [[ "$result" == "reject" ]]; then
        local reason
        reason=$(echo "$content" | jq -r '.reason')
        echo "Error: $reason" >&2
        return 1
    fi

    if [[ "$success" != "true" ]]; then
        echo "Error: ${message:-Unknown error}" >&2
        return 1
    fi

    return 0
}

smsaero_check_response() {
    local content_file="$1"
    local content

    content=$(cat "$content_file")

    if ! echo "$content" | jq . >/dev/null 2>&1; then
        echo "Error: Unexpected format received" >&2
        smsaero_log_err "Error: Unexpected format received: $content"
        return 1
    fi

    local result success message
    result=$(echo "$content" | jq -r '.result')
    success=$(echo "$content" | jq -r '.success')
    message=$(echo "$content" | jq -r '.message')

    smsaero_process_response "$result" "$success" "$message" "$content"
}

smsaero_send_request() {
    local selector="$1"
    local data="$2"
    local page="$3"
    local gate url response http_code temp_response

    temp_response=$(mktemp /tmp/smsaero_response.XXXXXX)

    for gate in $(smsaero_get_gate_urls); do
        url="https://${SMSAERO_EMAIL}:${SMSAERO_API_KEY}${gate}${selector}"
        [[ -n "$page" ]] && [[ "$page" =~ ^[0-9]+$ ]] && url="${url}?page=${page}"

        smsaero_log_info "Sending request to URL: $url with data: $data"
        response=$(curl -s -w "%{http_code}" -o "$temp_response" -X POST "$url" -d "$data" -H "Content-Type: application/json" -H "User-Agent: SABashClient/1.0" --max-time "$SMSAERO_TIMEOUT")
        http_code="${response: -3}"
        smsaero_log_info "Received HTTP code: $http_code"
        smsaero_log_info "Received response: $(cat "$temp_response")"

        if [[ "$http_code" =~ ^(200|400|401|402|403|404|500)$ ]]; then
            if ! smsaero_check_response "$temp_response"; then
                rm -f "$temp_response"
                return 1
            fi
            cat "$temp_response"
            rm -f "$temp_response"
            return 0
        else
            smsaero_log_err "Connection error with HTTP code $http_code"
        fi
    done

    echo "Connection error"
    rm -f "$temp_response"
    return 1
}

smsaero_enable_test_mode() {
    SMSAERO_TEST_MODE=1
    smsaero_log_info "Test mode enabled"
}

smsaero_disable_test_mode() {
    SMSAERO_TEST_MODE=0
    smsaero_log_info "Test mode disabled"
}

smsaero_is_test_mode_active() {
    if [[ "$SMSAERO_TEST_MODE" -eq 1 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

smsaero_enable_logging() {
    SMSAERO_ENABLE_LOGGER=1
}

smsaero_disable_logging() {
    SMSAERO_ENABLE_LOGGER=0
}

smsaero_logging_is_active() {
    if [[ "$SMSAERO_ENABLE_LOGGER" -eq 1 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

smsaero_validate_field() {
    local value="$1"
    local field_name="$2"
    local is_numeric="$3"

    if [[ -z "$value" ]]; then
        echo "Error: '$field_name' is a required parameter."
        return 1
    fi

    if [[ "$is_numeric" == "true" ]] && ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: '$field_name' must be a number."
        return 1
    fi

    return 0
}

smsaero_validate_required_numeric_field() {
    smsaero_validate_field "$1" "$2" "true"
}

smsaero_validate_required_field() {
    smsaero_validate_field "$1" "$2" "false"
}
