FROM bash:5.0

WORKDIR /app

RUN apk add --no-cache \
    curl \
    jq \
    sed \
    perl \
    perl-uri

COPY . .

RUN bash install.sh
