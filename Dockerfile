FROM ubuntu:jammy
LABEL maintainer="GeoPD <geoemmanuelpd2001@gmail.com>"
ENV DEBIAN_FRONTEND noninteractive

WORKDIR /tmp

RUN apt-get -yqq update \
    && apt-get install --no-install-recommends -yqq adb autoconf automake axel bc bison build-essential clang cmake curl expat expect fastboot flex g++ g++-multilib gawk gcc gcc-multilib git gnupg gperf htop imagemagick locales libncurses5 lib32ncurses5-dev lib32z1-dev libtinfo5 libc6-dev libcap-dev libexpat1-dev libgmp-dev '^liblz4-.*' '^liblzma.*' libmpc-dev libmpfr-dev libncurses5-dev libnl-route-3-dev libprotobuf-dev libsdl1.2-dev libssl-dev libtool libxml-simple-perl libxml2 libxml2-utils lld lsb-core lzip '^lzma.*' lzop maven nano ncftp ncurses-dev openssh-server patch patchelf pkg-config pngcrush pngquant protobuf-compiler python2.7 python3-apt python-all-dev python-is-python3 re2c rsync schedtool screen squashfs-tools subversion sudo tar texinfo tmate tzdata unzip w3m wget xsltproc zip zlib1g-dev zram-config \
    && curl --create-dirs -L -o /usr/local/bin/repo -O -L https://raw.githubusercontent.com/geopd/git-repo/main/repo \
    && chmod a+rx /usr/local/bin/repo \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
    && echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen && /usr/sbin/locale-gen \
    && TZ=Asia/Kolkata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN git clone https://github.com/mirror/make \
    && cd make && ./bootstrap && ./configure && make CFLAGS="-O3 -Wno-error" \
    && sudo install ./make /usr/bin/make

RUN git clone https://github.com/ninja-build/ninja.git \
    && cd ninja && git reset --hard 7905dee && cmake -DCMAKE_BUILD_TYPE=Release -B build \
    && cmake --build build --parallel --config Release && sudo install build/ninja /usr/bin/ninja

RUN git clone https://github.com/google/kati.git \
    && cd kati && git reset --hard 09dfa26 && make ckati \
    && sudo install ./ckati /usr/bin/ckati

RUN git clone https://github.com/google/nsjail.git \
    && cd nsjail && git reset --hard 6483728 && make nsjail \
    && sudo install ./nsjail /usr/bin/nsjail

RUN git clone https://github.com/facebook/zstd.git && cd zstd && git reset --hard f349d18 \
    && mkdir build/cmake/build && cd build/cmake/build \
    && cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release .. \
    && make CFLAGS="-O3" && sudo make install

RUN git clone https://github.com/google/brotli.git \
    && cd brotli && mkdir out && cd out && ../configure-cmake --disable-debug \
    && make CFLAGS="-O3" && sudo make install

RUN curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip \
    && unzip rclone-current-linux-amd64.zip && cd rclone-*-linux-amd64 \
    && sudo cp rclone /usr/bin/ && sudo chown root:root /usr/bin/rclone \
    && sudo chmod 755 /usr/bin/rclone

RUN git clone https://github.com/redis/hiredis.git && cd hiredis && git reset --hard 95a0c12 \
    && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release .. \
    && make CFLAGS="-O3" && sudo make install

RUN git clone https://github.com/ccache/ccache.git && cd ccache && git reset --hard eb57a6b \
    && mkdir build && cd build && cmake -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release .. \
    && make CFLAGS="-O3" && sudo make install

VOLUME ["/tmp/ccache", "/tmp/rom"]
ENTRYPOINT ["/bin/bash"]
