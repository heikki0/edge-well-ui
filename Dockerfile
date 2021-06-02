FROM --platform=$TARGETPLATFORM ubuntu:18.04 as builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Install other apt deps
RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get -y install wget unzip fakeroot jq
RUN wget -qO- https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

ENV WORKING_DIRECTORY=/usr/src/edge-well-ui

WORKDIR ${WORKING_DIRECTORY}

# Move package.json to filesystem
COPY package.json .

RUN JOBS=MAX npm install --unsafe-perm
RUN jq .version package.json -r > version.txt

COPY app/ ./app/

ENV TARGET=linux/arm64

RUN export PLATFORM=$(echo $TARGET | sed "s/linux\///") \
    ARCHITECTURE=$(echo $TARGET | sed "s/linux\///" | sed "s/amd/x/"); \
    DEBUG=electron-rebuild npm run rebuild; \
    DEBUG=electron-packager npm run build; \
    DEBUG=electron-installer-debian npm run deb; \
    mv $WORKING_DIRECTORY/dist/installers/edge-well-ui_$(cat version.txt)_arm64.deb $WORKING_DIRECTORY/edge-well-ui.deb

# ---

FROM --platform=$TARGETPLATFORM ubuntu:18.04

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
    && apt-get -y install \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    xvfb \
    libuuid1 \
    libasound2 \
    libglib2.0-bin \
    libcanberra-gtk-module \
    libcanberra-gtk3-module

RUN export uid=1000 gid=1000 && \
    mkdir -p /home/cerulean && \
    echo "cerulean:x:${uid}:${gid}:cerulean,,,:/home/cerulean:/bin/bash" >> /etc/passwd && \
    echo "cerulean:x:${uid}:" >> /etc/group && \
    #echo "cerulean ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/cerulean && \
    #chmod 0440 /etc/sudoers.d/cerulean && \
    chown ${uid}:${gid} -R /home/cerulean

WORKDIR /usr/src/edge-well-ui

COPY --from=builder /usr/src/edge-well-ui/edge-well-ui.deb .

RUN apt-get -f install

RUN apt install libgtk-3-0 \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxtst6 \
    libatspi2.0-0 \
    libxss1 --reinstall

RUN dpkg --add-architecture armv7l

RUN dpkg --configure -a --force-depends

RUN dpkg -i edge-well-ui.deb

USER cerulean
ENV HOME /home/cerulean

CMD ["edge-well-ui"]
