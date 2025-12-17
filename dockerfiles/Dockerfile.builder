FROM linuxdeepin/deepin:beige-25-loong64-v1.5.0

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
        ninja-build \
        build-essential \
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
        mesa-common-dev \

        # LLVM
        libxml2 \
        libedit2 \
        libffi8

# LLVM
ARG LLVM_NAME=llvm-21
COPY --from=llvm-21 /root/llvm.tar.gz .
RUN mkdir llvm && \
    tar -xzvf llvm.tar.gz -C llvm && \
    cp -aPv llvm/usr/* /usr/ && \
    (cd /usr/bin; ln -sv ../lib/${LLVM_NAME}/bin/* .; cd -) && \
    (cd /usr/lib; ln -sv ./${LLVM_NAME}/lib/clang .; cd -) && \
    (cd /usr/lib/loongarch64-linux-gnu; ln -sv ../${LLVM_NAME}/lib/*.so.* .; cd -) && \
    rm -rf llvm llvm.tar.gz && \
    update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 && \
    update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang++ 100

# GN
COPY --from=gn-2285 /root/gn.tar.gz .
RUN tar -xzvf gn.tar.gz && \
    chmod +x gn && \
    mv gn /usr/bin/ && \
    rm -rf gn.tar.gz

# Node.js
COPY nodejs.tar.gz .
RUN tar -xzf nodejs.tar.gz -C / && \
    rm nodejs.tar.gz && \
    npm i -g yarn @esbuild/linux-loong64@0.25.1

# Libraries
COPY libgcc.tar.gz libffi.tar.gz .
RUN mkdir libgcc libffi && \
    # Replacing the crtbeginS.o is hacky, we might need to build the whole gcc instead
    tar -xzvf libgcc.tar.gz -C libgcc && \
    cp libgcc/gcc/loongarch64-unknown-linux-gnu/*/crtbeginS.o /usr/lib/gcc/loongarch64-linux-gnu/12/ && \
    # Replacing libffi: Also hacky here
    tar -xzvf libffi.tar.gz -C libffi && \
    cp libffi/libffi_convenience.a /usr/lib/loongarch64-linux-gnu/libffi_pic.a && \
    # Clean up
    rm -rf *.tar.gz libgcc libffi

# Rust
ARG RUST_VERSION="1.92.0-beta.3" BINDGEN_VERSION="0.70.1"
ENV CARGO_HOME=/usr/local RUSTUP_HOME=/usr/local
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain ${RUST_VERSION} && \
    # Chromium seems to require that bindgen binary lives together with llvm
    cargo install bindgen-cli@${BINDGEN_VERSION} --root /usr/lib/${LLVM_NAME}

RUN echo 'builduser ALL=NOPASSWD: ALL' >> /etc/sudoers.d/50-builduser && \
    echo 'Defaults    env_keep += "DEBIAN_FRONTEND"' >> /etc/sudoers.d/env_keep

USER builduser
WORKDIR /home/builduser
