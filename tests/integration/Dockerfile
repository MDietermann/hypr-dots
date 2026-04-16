FROM archlinux:latest
RUN pacman -Sy --noconfirm bash stow bats git coreutils awk gawk rsync && \
    useradd -m marvin
USER marvin
WORKDIR /home/marvin
