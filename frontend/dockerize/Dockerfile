FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    openjdk-17-jdk wget

# Install Flutter
WORKDIR /opt
RUN git clone https://github.com/flutter/flutter.git -b stable

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Enable web (optional)
RUN flutter config --enable-web

# Pre-cache Flutter
RUN flutter doctor

WORKDIR /app
COPY . .

RUN flutter pub get

CMD ["flutter", "analyze"]