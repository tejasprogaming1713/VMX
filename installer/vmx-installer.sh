#!/bin/bash
# VMX Premium Installer 2026
# Developed by tejasprogaming1713

set -e

echo "====================================="
echo " VMX Premium Manager Installer 2026"
echo "====================================="

# 1️⃣ Update & Install required packages
sudo apt update
sudo apt install -y openjdk-17-jre wget curl tar unzip

# 2️⃣ Create VMX user
if ! id "vmxuser" &>/dev/null; then
    sudo adduser --gecos "" vmxuser
    sudo usermod -aG sudo vmxuser
fi

# 3️⃣ Create Minecraft folder
sudo mkdir -p /minecraft
sudo chown vmxuser:vmxuser /minecraft
cd /minecraft

# 4️⃣ Download Minecraft server jar (PaperMC)
PAPER_URL="https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/550/downloads/paper-1.20.4-550.jar"
sudo -u vmxuser wget -O server.jar $PAPER_URL

# Accept EULA
echo "eula=true" | sudo tee eula.txt

# 5️⃣ Generate root-only random exit key
EXIT_KEY=$(openssl rand -hex 16)
echo $EXIT_KEY | sudo tee /root/vmx_exit_key.txt >/dev/null
sudo chmod 600 /root/vmx_exit_key.txt

# 6️⃣ Create systemd service for Minecraft
sudo tee /etc/systemd/system/vmx-mc.service > /dev/null <<EOF
[Unit]
Description=VMX Minecraft Server
After=network.target

[Service]
User=vmxuser
WorkingDirectory=/minecraft
ExecStart=/usr/bin/java -Xms2G -Xmx2G -jar server.jar nogui
Restart=always
RestartSec=5
StandardInput=null

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable vmx-mc
sudo systemctl start vmx-mc

# 7️⃣ Setup VMX manager scripts
sudo mkdir -p /usr/local/bin

# Service wrapper for passwordless systemctl
sudo tee /usr/local/bin/vmx-service-wrapper > /dev/null <<'EOF'
#!/bin/bash
SERVICE="vmx-mc"
case "$1" in
start|stop|restart|status)
    systemctl "$1" $SERVICE
    ;;
*)
    echo "Only start/stop/restart/status allowed"
    ;;
esac
EOF
sudo chmod +x /usr/local/bin/vmx-service-wrapper
grep -q "vmx-service-wrapper" /etc/sudoers || echo "vmxuser ALL=NOPASSWD: /usr/local/bin/vmx-service-wrapper" | sudo tee -a /etc/sudoers

# VMX main script
sudo tee /usr/local/bin/vmx > /dev/null <<'EOF'
#!/bin/bash
KEY_FILE="/root/vmx_exit_key.txt"
KEY_HASH=$(cat $KEY_FILE | sha256sum | awk '{print $1}')
SERVICE="vmx-mc"

banner() {
    echo "====================================="
    echo "        VMX Premium Manager"
    echo "====================================="
}

cmd="$1"
arg="$2"

case "${cmd,,}" in
start)
    banner
    sudo /usr/local/bin/vmx-service-wrapper start
    echo "Server Started."
    ;;
stop)
    banner
    read -sp "Enter Exit Key: " INPUT; echo
    INPUT_HASH=$(echo -n "$INPUT" | sha256sum | awk '{print $1}')
    if [[ "$INPUT_HASH" == "$KEY_HASH" ]]; then
        sudo /usr/local/bin/vmx-service-wrapper stop
        echo "Server Stopped."
    else
        echo "Wrong key."
    fi
    ;;
restart)
    banner
    sudo /usr/local/bin/vmx-service-wrapper restart
    echo "Server Restarted."
    ;;
status)
    banner
    sudo /usr/local/bin/vmx-service-wrapper status
    ;;
logs)
    banner
    journalctl -u $SERVICE -n 50
    ;;
ram)
    banner
    free -h
    ;;
cpu)
    banner
    top -bn1 | head -15
    ;;
uptime)
    banner
    uptime
    ;;
ip)
    banner
    curl -s ifconfig.me
    echo ":25565"
    ;;
backup)
    banner
    tar -czf /minecraft/backup-$(date +%F).tar.gz /minecraft
    echo "Backup Created."
    ;;
playit-setup)
    banner
    echo "Starting Playit tunnel setup..."
    # User must follow Playit instructions manually
    ;;
players)
    banner
    screen -S mc -X stuff "list^M"
    ;;
whitelist-add)
    banner
    screen -S mc -X stuff "whitelist add $arg^M"
    ;;
whitelist-remove)
    banner
    screen -S mc -X stuff "whitelist remove $arg^M"
    ;;
ops-add)
    banner
    screen -S mc -X stuff "op $arg^M"
    ;;
ops-remove)
    banner
    screen -S mc -X stuff "deop $arg^M"
    ;;
seed)
    banner
    screen -S mc -X stuff "seed^M"
    ;;
version)
    banner
    screen -S mc -X stuff "version^M"
    ;;
plugins)
    banner
    ls /minecraft/plugins || echo "No plugins installed"
    ;;
save-all)
    banner
    screen -S mc -X stuff "save-all^M"
    ;;
gc)
    banner
    echo "Triggering JVM GC..."
    # no-op for now
    ;;
stats)
    banner
    free -h
    uptime
    ;;
help|*)
    banner
    echo "Available Commands (64 planned, partial demo here):"
    echo "start, stop, restart, status, logs, ram, cpu, uptime, ip, backup, playit-setup"
    echo "players, whitelist-add, whitelist-remove, ops-add, ops-remove, seed, version, plugins, save-all, gc, stats"
    ;;
esac
EOF

sudo chmod +x /usr/local/bin/vmx

# Case-insensitive links
for x in VMX Vmx vMx vmX; do sudo ln -sf /usr/local/bin/vmx /usr/local/bin/$x; done

echo "====================================="
echo "VMX Premium Manager Installed ✅"
echo "Exit Key (root-only): $(cat /root/vmx_exit_key.txt)"
echo "Use commands: vmx start, vmx stop, vmx restart, etc."
echo "====================================="
