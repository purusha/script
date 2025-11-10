#!/bin/bash

# ============================================
# Script di Setup Raspberry Pi 4
# ============================================
# Esegui come root o con sudo
# Usage: sudo bash setup-rpi4.sh

set -e  # Exit on error

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica se eseguito come root
if [ "$EUID" -ne 0 ]; then 
    log_error "Esegui lo script come root o con sudo"
    exit 1
fi

log_info "Inizio setup Raspberry Pi 4..."

# ============================================
# 1. AGGIORNAMENTO SISTEMA
# ============================================
log_info "Aggiornamento sistema in corso..."
apt update && apt upgrade -y
apt dist-upgrade -y
apt autoremove -y
apt autoclean

# ============================================
# 2. CONFIGURAZIONE TIMEZONE E LOCALE
# ============================================
log_info "Configurazione timezone e locale..."
timedatectl set-timezone Europe/Rome
locale-gen it_IT.UTF-8
update-locale LANG=it_IT.UTF-8

# ============================================
# 3. INSTALLAZIONE PACCHETTI BASE
# ============================================
log_info "Installazione pacchetti essenziali..."
apt install -y \
    vim \
    nano \
    git \
    curl \
    wget \
    htop \
    tree \
    net-tools \
    ufw \
    fail2ban \
    unzip \
    zip \
    ca-certificates \
    gnupg \
    lsb-release \
    build-essential \
    python3-pip \
    python3-venv \
    python3-dev \
    python3-setuptools

# ============================================
# 4. CONFIGURAZIONE PYTHON
# ============================================
log_info "Configurazione avanzata Python..."

# Aggiorna pip
python3 -m pip install --upgrade pip

# Installa pacchetti Python comuni
pip3 install --upgrade \
    virtualenv \
    pipenv \
    poetry \
    requests \
    python-dotenv

# Crea alias per python
update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# Crea directory per virtual environments
mkdir -p /home/pi/.venvs
chown -R pi:pi /home/pi/.venvs

# Configurazione pip per utente pi
mkdir -p /home/pi/.config/pip
cat > /home/pi/.config/pip/pip.conf << 'EOF'
[global]
break-system-packages = true
EOF
chown -R pi:pi /home/pi/.config

log_info "Python configurato. Versione: $(python3 --version)"

# ============================================
# 5. INSTALLAZIONE SDKMAN
# ============================================
log_info "Installazione SDKMAN..."

# Installa zip/unzip se non già presente (necessari per SDKMAN)
apt install -y zip unzip

# Installa SDKMAN come utente pi
su - pi -c 'curl -s "https://get.sdkman.io" | bash'

# Inizializza SDKMAN nel profilo
su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh"'

# Aggiungi SDKMAN al .bashrc se non già presente
if ! grep -q "sdkman-init.sh" /home/pi/.bashrc; then
    echo '' >> /home/pi/.bashrc
    echo '# SDKMAN Configuration' >> /home/pi/.bashrc
    echo 'export SDKMAN_DIR="$HOME/.sdkman"' >> /home/pi/.bashrc
    echo '[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"' >> /home/pi/.bashrc
fi

log_info "SDKMAN installato! Installazione JDK 21..."

# Installa Java 21 usando SDKMAN (come utente pi)
su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk install java 21.0.5-tem && sdk default java 21.0.5-tem'

# Verifica installazione Java
JAVA_VERSION=$(su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && java -version 2>&1 | head -n 1')
log_info "Java installato: $JAVA_VERSION"

# Aggiungi JAVA_HOME al .bashrc se non già presente
if ! grep -q "JAVA_HOME" /home/pi/.bashrc; then
    echo '' >> /home/pi/.bashrc
    echo '# Java Environment' >> /home/pi/.bashrc
    echo 'export JAVA_HOME="$HOME/.sdkman/candidates/java/current"' >> /home/pi/.bashrc
    echo 'export PATH="$JAVA_HOME/bin:$PATH"' >> /home/pi/.bashrc
fi

log_info "JDK 21 configurato con successo!"

# Installa Maven usando SDKMAN
log_info "Installazione Maven..."
su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk install maven'

# Verifica installazione Maven
MAVEN_VERSION=$(su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && mvn -version 2>&1 | head -n 1')
log_info "Maven installato: $MAVEN_VERSION"

# Aggiungi M2_HOME al .bashrc se non già presente
if ! grep -q "M2_HOME" /home/pi/.bashrc; then
    echo 'export M2_HOME="$HOME/.sdkman/candidates/maven/current"' >> /home/pi/.bashrc
    echo 'export PATH="$M2_HOME/bin:$PATH"' >> /home/pi/.bashrc
fi

log_info "Maven configurato con successo!"

# ============================================
# 6. INSTALLAZIONE RUST
# ============================================
log_info "Installazione Rust..."

# Installa Rust usando rustup (come utente pi)
su - pi -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y'

# Configura PATH per Rust nel .bashrc se non già presente
if ! grep -q "cargo/env" /home/pi/.bashrc; then
    echo '' >> /home/pi/.bashrc
    echo '# Rust Environment' >> /home/pi/.bashrc
    echo 'source "$HOME/.cargo/env"' >> /home/pi/.bashrc
fi

# Carica l'ambiente Rust
su - pi -c 'source "$HOME/.cargo/env"'

# Verifica installazione Rust
RUST_VERSION=$(su - pi -c 'source "$HOME/.cargo/env" && rustc --version 2>&1')
log_info "Rust installato: $RUST_VERSION"

CARGO_VERSION=$(su - pi -c 'source "$HOME/.cargo/env" && cargo --version 2>&1')
log_info "Cargo installato: $CARGO_VERSION"

# Installa componenti aggiuntivi utili
log_info "Installazione componenti Rust aggiuntivi..."
su - pi -c 'source "$HOME/.cargo/env" && rustup component add rustfmt clippy'

log_info "Rust configurato con successo!"

# ============================================
# 7. CONFIGURAZIONE SICUREZZA
# ============================================
log_info "Configurazione firewall (UFW)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  # SSH
ufw --force enable

log_info "Configurazione fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# ============================================
# 8. CONFIGURAZIONE SSH
# ============================================
log_info "Configurazione SSH..."
# Backup configurazione originale
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Configurazioni SSH sicure
sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

systemctl restart ssh

# ============================================
# 9. INSTALLAZIONE DOCKER (OPZIONALE)
# ============================================
read -p "Vuoi installare Docker? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    log_info "Installazione Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Aggiungi utente pi al gruppo docker
    usermod -aG docker pi 2>/dev/null || true
    
    # Installazione Docker Compose
    apt install -y docker-compose
    
    systemctl enable docker
    systemctl start docker
    
    rm get-docker.sh
    log_info "Docker installato con successo!"
fi

# ============================================
# 10. CONFIGURAZIONE SWAP (raccomandato)
# ============================================
log_info "Configurazione SWAP..."
# Disabilita swap esistente
dphys-swapfile swapoff 2>/dev/null || true

# Configura 2GB di swap
sed -i 's/CONF_SWAPSIZE=.*/CONF_SWAPSIZE=2048/' /etc/dphys-swapfile

# Riattiva swap
dphys-swapfile setup
dphys-swapfile swapon

# ============================================
# 11. OTTIMIZZAZIONI PERFORMANCE
# ============================================
log_info "Applicazione ottimizzazioni..."

# Aumenta file descriptor limit
echo "* soft nofile 65535" >> /etc/security/limits.conf
echo "* hard nofile 65535" >> /etc/security/limits.conf

# Ottimizzazioni GPU memory (se non usi desktop)
if ! pgrep -x "X" > /dev/null; then
    log_info "Sistema headless rilevato, riduco GPU memory..."
    echo "gpu_mem=16" >> /boot/config.txt
fi

# ============================================
# 12. CREAZIONE STRUTTURA DIRECTORY
# ============================================
log_info "Creazione struttura directory..."
mkdir -p /home/pi/{projects,scripts,docker,backups}
chown -R pi:pi /home/pi/{projects,scripts,docker,backups}

# ============================================
# 13. SCRIPT UTILI
# ============================================
log_info "Creazione script di manutenzione..."

# Script backup
cat > /home/pi/scripts/backup.sh << 'EOF'
#!/bin/bash
# Script backup base
BACKUP_DIR="/home/pi/backups"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR
# Aggiungi qui le tue directory da backuppare
# tar -czf $BACKUP_DIR/backup_$DATE.tar.gz /percorso/da/backuppare
EOF
chmod +x /home/pi/scripts/backup.sh

# Script update sistema
cat > /home/pi/scripts/update-system.sh << 'EOF'
#!/bin/bash
echo "Aggiornamento sistema..."
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean
echo "Sistema aggiornato!"
EOF
chmod +x /home/pi/scripts/update-system.sh

chown -R pi:pi /home/pi/scripts

# ============================================
# 14. CONFIGURAZIONE .bashrc
# ============================================
log_info "Configurazione .bashrc..."
cat >> /home/pi/.bashrc << 'EOF'

# Alias personalizzati
alias ll='ls -lah'
alias update='sudo apt update && sudo apt upgrade -y'
alias ports='netstat -tulanp'
alias temp='vcgencmd measure_temp'

# Python aliases
alias py='python3'
alias pip='pip3'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate'

# Rust aliases
alias cb='cargo build'
alias cr='cargo run'
alias ct='cargo test'
alias cc='cargo check'
alias cf='cargo fmt'

# Mostra temperatura all'avvio
vcgencmd measure_temp
EOF

# ============================================
# 15. INFORMAZIONI SISTEMA
# ============================================
log_info "Installazione strumento info sistema..."
cat > /usr/local/bin/rpi-info << 'EOF'
#!/bin/bash
echo "=========================================="
echo "Raspberry Pi 4 - System Info"
echo "=========================================="
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I)"
echo "CPU Temperature: $(vcgencmd measure_temp)"
echo "Python Version: $(python3 --version)"
echo "Pip Version: $(pip3 --version | cut -d' ' -f2)"
if [ -d "/home/pi/.sdkman" ]; then
    echo "SDKMAN: Installato"
    JAVA_VER=$(su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && java -version 2>&1 | head -n 1' 2>/dev/null || echo "N/A")
    echo "Java: $JAVA_VER"
    MAVEN_VER=$(su - pi -c 'source "$HOME/.sdkman/bin/sdkman-init.sh" && mvn -version 2>&1 | head -n 1' 2>/dev/null || echo "N/A")
    echo "Maven: $MAVEN_VER"
else
    echo "SDKMAN: Non installato"
fi
if [ -d "/home/pi/.cargo" ]; then
    RUST_VER=$(su - pi -c 'source "$HOME/.cargo/env" && rustc --version 2>&1' 2>/dev/null || echo "N/A")
    echo "Rust: $RUST_VER"
    CARGO_VER=$(su - pi -c 'source "$HOME/.cargo/env" && cargo --version 2>&1' 2>/dev/null || echo "N/A")
    echo "Cargo: $CARGO_VER"
fi
echo ""
echo "Memory Usage:"
free -h
echo ""
echo "Disk Usage:"
df -h /
echo "=========================================="
EOF
chmod +x /usr/local/bin/rpi-info

# ============================================
# 16. CONFIGURAZIONE HOSTNAME (OPZIONALE)
# ============================================
read -p "Vuoi cambiare hostname? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    read -p "Inserisci nuovo hostname: " NEW_HOSTNAME
    hostnamectl set-hostname "$NEW_HOSTNAME"
    log_info "Hostname cambiato in: $NEW_HOSTNAME"
fi

# ============================================
# FINE SETUP
# ============================================
log_info "=========================================="
log_info "Setup completato con successo!"
log_info "=========================================="
echo ""
log_warn "IMPORTANTE:"
log_warn "1. Riavvia il sistema: sudo reboot"
log_warn "2. Cambia la password predefinita: passwd"
log_warn "3. Configura chiavi SSH per maggiore sicurezza"
log_warn "4. Verifica firewall: sudo ufw status"
echo ""
log_info "Script utili creati in /home/pi/scripts/"
log_info "Per info sistema: rpi-info"
echo ""

read -p "Vuoi riavviare ora? (s/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    log_info "Riavvio in corso..."
    reboot
fi
