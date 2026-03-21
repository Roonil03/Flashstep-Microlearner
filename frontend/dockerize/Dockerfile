FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    FLUTTER_HOME=/opt/flutter \
    ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk \
    PATH=/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:$PATH

ARG FLUTTER_CHANNEL=stable
ARG ANDROID_API_LEVEL=35
ARG ANDROID_BUILD_TOOLS=35.0.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl git unzip xz-utils zip ca-certificates \
    libglu1-mesa libstdc++6 libc6 lib32stdc++6 \
    openjdk-17-jdk clang cmake ninja-build pkg-config \
 && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git -b ${FLUTTER_CHANNEL} /opt/flutter \
 && flutter --version

RUN mkdir -p /opt/android-sdk/cmdline-tools \
 && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o /tmp/cmdline-tools.zip \
 && unzip -q /tmp/cmdline-tools.zip -d /opt/android-sdk/cmdline-tools \
 && mv /opt/android-sdk/cmdline-tools/cmdline-tools /opt/android-sdk/cmdline-tools/latest \
 && rm /tmp/cmdline-tools.zip \
 && yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses \
 && sdkmanager --sdk_root="$ANDROID_SDK_ROOT" \
      "platform-tools" \
      "platforms;android-${ANDROID_API_LEVEL}" \
      "build-tools;${ANDROID_BUILD_TOOLS}"

WORKDIR /workspace
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
CMD ["flutter", "doctor", "-v"]