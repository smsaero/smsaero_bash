# SmsAero Bash Library

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Library for sending SMS messages using the SmsAero API. Written in Bash.

## Installation:

1. Clone the repository:
```bash
git clone https://github.com/smsaero/smsaero_bash.git
```

2. Go to the repository directory:
```bash
cd smsaero_bash
```

3. Run the installation script:
```bash
./install.sh
```

4. Restart your shell or reload your shell configuration:
```bash
source ~/.bashrc
```

## Usage example:

Get credentials from account settings page: https://smsaero.ru/cabinet/settings/apikey/

```bash
#!/usr/bin/env bash

source /usr/local/bin/smsaero.sh

smsaero_init 'your email' 'your api key'
smsaero_enable_test_mode

# send sms
smsaero_send_sms 70000000000 'Hello, World!' | jq .data
```

## Requirements:

- curl
- sed
- jq
- perl or python3


## Run on Docker:

```bash
docker pull 'smsaero/smsaero_bash:latest'
docker run -it --rm 'smsaero/smsaero_bash:latest' smsaero_send --email "your email" --api_key "your api key" --phone 70000000000 --message 'Hello, World!'
```

## License:

```
MIT License
```
