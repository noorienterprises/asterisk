#!/bin/bash

set -e  # Exit script immediately if a command fails

# Function to retry a failed task or skip it or exit
retry_or_skip_or_exit() {
    local task_name=$1
    local task_command=$2

    read -p "$task_name failed. Please retry $task_name, skip, or exit (r/s/e): " retry_choice
    if [ "$retry_choice" = "r" ]; then
        echo "Retrying $task_name..."
        eval "$task_command" || retry_or_skip_or_exit "$task_name" "$task_command"
    elif [ "$retry_choice" = "s" ]; then
        echo "Skipping $task_name..."
    else
        echo "Exiting script."
        exit 1
    fi
}

# Trap errors and call retry or skip or exit function
trap 'retry_or_skip_or_exit "$BASH_COMMAND"' ERR

# Set log file paths
LOG_FILE="/var/log/asterisk_install.log"
ERROR_LOG_FILE="/var/log/asterisk_install_error.log"

# Redirect stdout and stderr to log files
exec > >(tee -a "$LOG_FILE")
exec 2> >(tee -a "$ERROR_LOG_FILE" >&2)

# Update and upgrade packages
apt update && \
apt upgrade -y || retry_or_skip_or_exit "Update and upgrade packages" "apt update && apt upgrade -y"

# Install necessary packages
apt install -y nano libssl-dev openssl libncurses-dev libnewt-dev libreadline6 libreadline-dev zlib1g zlib1g-dev \
libxml2-dev libxslt-dev libc6-dev libcurl4-openssl-dev libgdbm-dev libffi-dev libsqlite3-dev sqlite3 \
libtiff-dev ghostscript usbutils libusb-dev unzip minicom mc vim screen tmux libncurses5-dev libyaml-dev \
libssl-dev uuid-dev libpcap-dev ngrep libpcre++-dev libpcre3-dev wpasupplicant w3m ssl-cert ca-certificates \
ffmpeg espeak libespeak-dev libsndfile1-dev libsamplerate0-dev libsrtp0-dev build-essential \
libncurses5-dev libreadline-dev libreadline6-dev libjansson-dev pkg-config libedit-dev \
libspeex-dev libspeexdsp-dev libogg-dev libvorbis-dev libasound2-dev portaudio19-dev \
libcurl4-openssl-dev libpq-dev unixodbc-dev libneon27-dev libgmime-2.6-dev liblua5.2-dev liburiparser-dev \
libxslt1-dev libvpb-dev libmysqlclient-dev libbluetooth-dev libradcli-dev freetds-dev libosptk-dev \
libjack-jackd2-dev libsnmp-dev libiksemel-dev libcorosync-common-dev libcpg-dev libcfg-dev \
libpopt-dev libical-dev libspandsp-dev libresample1-dev libc-client2007e-dev binutils-dev \
libsrtp2-dev libgsm1-dev zlib1g-dev libldap2-dev libcodec2-dev libfftw3-dev libunbound-dev
|| retry_or_skip_or_exit "Install necessary packages" "apt install -y <package-list>"

# Check if make is installed, if not, install it
if ! which make &> /dev/null; then
    apt install -y make || retry_or_skip_or_exit "Install make" "apt install -y make"
fi

# Download and extract Asterisk source
wget --continue http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18.23.1.tar.gz && \
tar -xvf asterisk-18.23.1.tar.gz &&
rm -f asterisk-18.23.1.tar.gz || retry_or_skip_or_exit "Download and extract Asterisk source" "wget --continue http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-18.23.1.tar.gz && tar -xvf asterisk-18.23.1.tar.gz && rm -f asterisk-18.23.1.tar.gz"

# Navigate to Asterisk source directory
cd /usr/src/asterisk-* &&

# Install Asterisk prerequisites
contrib/scripts/install_prereq install || retry_or_skip_or_exit "Install Asterisk prerequisites" "contrib/scripts/install_prereq install"

# Configure Asterisk with SIP channel support
./configure --with-sip --with-pjsip --with-jansson-bundled --with-pjproject-bundled --with-crypto --with-ssl --with-srtp --with-jack --with-speex --with-curl --with-unixodbc --with-libpri --with-opus --with-popt --with-sqlite3 --with-uuid --with-xml2 --with-speexdsp --with-resample --with-pgsql --with-mysql --with-odbcinst --with-neon --with-lua --with-mp3 --with-xslt --with-gsm --with-freetype2 --with-svg --with-memcached --with-ldap --with-pcre --with-crypto --with-odbc && \ || retry_or_skip_or_exit "Configure Asterisk with SIP channel support" "./configure --with-sip --with-pjsip --with-jansson-bundled --with-pjproject-bundled --with-crypto --with-ssl --with-srtp --with-jack --with-speex --with-curl --with-unixodbc --with-libpri --with-opus --with-popt --with-sqlite3 --with-uuid --with-xml2 --with-speexdsp --with-resample --with-pgsql --with-mysql --with-odbcinst --with-neon --with-lua --with-mp3 --with-xslt --with-gsm --with-freetype2 --with-svg --with-memcached --with-ldap --with-pcre --with-crypto --with-odbc"

# Select Asterisk options
make menuselect.makeopts || retry_or_skip_or_exit "Select Asterisk options" "make menuselect.makeopts"

# Build and install Asterisk
make && make install && make samples && make config \
|| retry_or_skip_or_exit "Build and install Asterisk" "make && make install && make samples && make config &&"


# Asterisk installed successfully and optional GoTrunk installation
read -p "Asterisk installation completed successfully. Do you want to continue with the installation of GoTrunk? (y/n): " continue_gotrunk
if [ "$continue_gotrunk" = "y" ]; then
    echo "Attempting GoTrunk Installation"

    # Check if git is installed, if not, install it
if ! which git &> /dev/null; then
    apt install -y git || retry_or_skip_or_exit "Install git" "apt install -y git"
    git_installed=true
else
    git_installed=true
fi || retry_or_skip_or_exit "Check if git is installed" "which git &> /dev/null"

# Clone and checkout GoTrunk repository
cd /etc \
git clone https://github.com/GoTrunk/asterisk-config.git asterisk &&
cd /etc/asterisk \
git checkout dynamic-ip || retry_or_skip_or_exit "Clone and checkout GoTrunk repository" "git clone https://github.com/GoTrunk/asterisk-config.git asterisk && cd /etc/asterisk && git checkout dynamic-ip"

        # Display installation completion message or report any errors
        if [ "$git_installed" = true ] && [ "$checkout_success" = true ]; then
            echo "Installation completed successfully with GoTrunk."
        else
            echo "GoTrunk installation encountered errors. Please review the installation steps to identify the issue. Errors logged at $ERROR_LOG_FILE"
            echo "Steps with errors:"
            [ "$git_installed" = false ] && echo "- Install git"
            # Add other steps here if needed
        fi
    else
        echo "Skipping GoTrunk installation."
        echo "Asterisk installation completed successfully."
        exit 0
    fi
fi
