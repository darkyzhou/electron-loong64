FROM linuxdeepin/deepin:beige-loong64-v1.4.0

ARG NODE_VERSION=20.16.0

RUN groupadd --gid 1000 builduser && \
    useradd --uid 1000 --gid builduser --shell /bin/bash --create-home builduser

ENV TEMP=/tmp
RUN chmod a+rwx /tmp

# Omitted lighttpd, rpm, xcompmgr and xcb as deepin doesn't offer them. Fortunately we could compile without them somehow.
ENV DEBIAN_FRONTEND=noninteractive
RUN echo 'deb https://mirrors.ustc.edu.cn/deepin/beige beige main commercial community' > /etc/apt/sources.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        file \
        gdb \
        gnupg \
        locales \
        lsb-release \
        nano \
        python3-pip \
        sudo \
        vim-nox \
        wget \
        lsof \
        software-properties-common \
        desktop-file-utils \
        xvfb \
        gperf \
        bison \
        python3-dbusmock \
        openjdk-8-jre \
        generate-ninja \
        ninja-build \
        build-essential \
        clang-18 \
        llvm-18 \
        lld-18 \
        llvm-18-dev \
        libclang-18-dev \
        libclang-rt-18-dev \
        libnotify-bin \
        libfuse2 \
        libdbus-1-dev \
        libgtk-3-dev \
        libnotify-dev \
        libasound2-dev \
        libcap-dev \
        libcups2-dev \
        libxtst-dev \
        libxss1 \
        libnss3-dev \

        # Tools needed by our scripts
        jq \
        rsync \

        # From https://chromium.googlesource.com/chromium/src/+/HEAD/build/install-build-deps.py
        binutils \
        bison \
        bzip2 \
        cdbs \
        curl \
        dbus-x11 \
        devscripts \
        dpkg-dev \
        elfutils \
        fakeroot \
        flex \
        git-core \
        gperf \
        libasound2-dev \
        libatspi2.0-dev \
        libbrlapi-dev \
        libbz2-dev \
        libc6-dev \
        libcairo2-dev \
        libcap-dev \
        libcups2-dev \
        libcurl4-gnutls-dev \
        libdrm-dev \
        libelf-dev \
        libevdev-dev \
        libffi-dev \
        libfuse2 \
        libgbm-dev \
        libglib2.0-dev \
        libglu1-mesa-dev \
        libgtk-3-dev \
        libkrb5-dev \
        libnspr4-dev \
        libnss3-dev \
        libpam0g-dev \
        libpci-dev \
        libpulse-dev \
        libsctp-dev \
        libspeechd-dev \
        libsqlite3-dev \
        libssl-dev \
        libsystemd-dev \
        libudev-dev \
        libudev1 \
        libva-dev \
        libwww-perl \
        libxshmfence-dev \
        libxslt1-dev \
        libxss-dev \
        libxt-dev \
        libxtst-dev \
        locales \
        openbox \
        p7zip \
        patch \
        perl \
        pkgconf \
        ruby \
        uuid-dev \
        wdiff \
        x11-utils \
        xz-utils \
        zip \
        libatk1.0-0 \
        libatspi2.0-0 \
        libc6 \
        libcairo2 \
        libcap2 \
        libcgi-session-perl \
        libcups2 \
        libdrm2 \
        libegl1 \
        libevdev2 \
        libexpat1 \
        libfontconfig1 \
        libfreetype6 \
        libgbm1 \
        libglib2.0-0 \
        libgl1 \
        libgtk-3-0 \
        libpam0g \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libpci3 \
        libpcre3 \
        libpixman-1-0 \
        libspeechd2 \
        libstdc++6 \
        libsqlite3-0 \
        libuuid1 \
        libwayland-egl1 \
        libwayland-egl1-mesa \
        libx11-6 \
        libx11-xcb1 \
        libxau6 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxdmcp6 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxinerama1 \
        libxrender1 \
        libxtst6 \
        x11-utils \
        x11-xserver-utils \
        xserver-xorg-core \
        xserver-xorg-video-dummy \
        xvfb \
        zlib1g \

        # From compilation errors
        libx11-xcb-dev \
        libxcb-xkb-dev \
        libxkbcommon-x11-dev \
        libdav1d-dev \
        libyuv-dev \
        mesa-common-dev

RUN update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100 && \
    update-alternatives --install /usr/bin/clang-cpp clang-cpp /usr/bin/clang-cpp-18 100 && \
    update-alternatives --install /usr/bin/lld lld /usr/bin/lld-18 100 && \
    update-alternatives --install /usr/bin/lld-link lld-link /usr/bin/lld-link-18 100 && \
    update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/ld.lld-18 100

RUN curl -L -O https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-loong64.tar.gz && \
    tar -xzf node-v${NODE_VERSION}-linux-loong64.tar.gz && \
    cp -R node-v${NODE_VERSION}-linux-loong64/* /usr/local/ && \
    rm -rf node-v${NODE_VERSION}-linux-loong64* && \
    npm i -g yarn @esbuild/linux-loong64@0.24.0

ADD config.toml /root/.cargo/

COPY libgcc.tar.gz libffi.tar.gz .
ADD --checksum=sha256:3b4be9da1b9184af1b6301352294ec7fe21d90bb3bc273a2351f2e41c6a8a76e \
    https://github.com/darkyzhou/rust/releases/download/1.85.0-loongarch/rust-1.85.0-loongarch64-unknown-linux-gnu.tar.xz .
ADD --checksum=sha256:66d88c86dde9f9ecd2bb62b17b849df13e1fe4b7fb294eac41aede768d70c5ec \
    https://github.com/rui314/mold/releases/download/v2.36.0/mold-2.36.0-loongarch64-linux.tar.gz .
ENV CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse

RUN mkdir libgcc libffi && \
    # Replacing the crtbeginS.o is hacky, we might need to build the whole gcc instead
    tar -xzvf libgcc.tar.gz -C libgcc && \
    cp libgcc/gcc/loongarch64-unknown-linux-gnu/*/crtbeginS.o /usr/lib/gcc/loongarch64-linux-gnu/12/ && \
    # Replacing libffi: Also hacky here
    tar -xzvf libffi.tar.gz -C libffi && \
    cp libffi/libffi_convenience.a /usr/lib/loongarch64-linux-gnu/libffi_pic.a && \
    # Install rust components
    tar -xvf rust-*.tar.xz && \
    bash rust-*/install.sh && \
    # Install mold
    tar -xzvf mold-*.tar.gz && \
    cp -r mold-*/* /usr && \
    # Clean up
    rm -rf *.tar.gz *.tar.xz libgcc libffi rust-* mold-*

# Chromium seems to require that bindgen binary lives together with llvm
RUN cargo install bindgen-cli@0.69.1 --root /usr/lib/llvm-18

RUN echo 'builduser ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-builduser && \
    echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

USER builduser
WORKDIR /home/builduser
