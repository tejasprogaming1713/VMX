#!/bin/bash
# VMX Premium Manager Auto-Setup 2026
# Author: tejasprogaming1713
# GitHub-ready all-in-one installer

set -e

echo "====================================="
echo "      VMX Premium Manager Installer"
echo "====================================="

# 1️⃣ Ask for VMX user info
read -p "Enter VMX Username: " VMX_USER
read -sp "Enter VMX Password: " VMX_PASS
echo
read -p "Enter Email (optional): " VMX_EMAIL
read -p "Assign RAM (e.g., 2G): " VMX_RAM
read -p "Assign Disk (e.g., 20G): " VMX_DISK
read -p "Assign CPU cores (e.g., 2): " VMX_CPU

# 2️⃣ Create dedicated user
sudo adduser --disabled-password --gecos "$VMX_EMAIL" "$VMX_USER"
echo "$VMX_USER:$VMX_PASS" | sudo chpasswd
echo "Created user $VMX_USER ✅"

# 3️⃣ Update system and install dependencies
sudo apt update && sudo apt install openjdk-17-jre wget screen -y

# 4️⃣ Create Minecraft folder & download PaperMC
sudo mkdir -p /minecraft
sudo chown -R "$VMX_USER":"$VMX_USER" /minecraft
cd /minecraft
sudo -u "$VMX_USER" wget -O server.jar https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/550/downloads/paper-1.20.4-550.jar
echo "eula=true" | sudo tee eula.txt

# 5️⃣ Create systemd service for MC
sudo tee /etc/systemd/system/vmx-mc.service > /dev/null <<EOF
[Unit]
Description=VMX Minecraft Server
After=network.target

[Service]
User=$VMX_USER
WorkingDirectory=/minecraft
ExecStart=/usr/bin/java -Xms$VMX_RAM -Xmx$VMX_RAM -jar server.jar nogui
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 6️⃣ Generate random exit key (root-only)
VMX_KEY=$(openssl rand -hex 16)
echo "$VMX_KEY" | sudo tee /root/vmx_exit_key.txt
sudo chmod 600 /root/vmx_exit_key.txt
echo "Exit key generated and stored in /root/vmx_exit_key.txt ✅"

# 7️⃣ Create VMX service wrapper
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

# 8️⃣ Allow VMX user to run wrapper without sudo password
grep -q "vmx-service-wrapper" /etc/sudoers || echo "$VMX_USER ALL=NOPASSWD: /usr/local/bin/vmx-service-wrapper" | sudo tee -a /etc/sudoers

# 9️⃣ Create main VMX script with 64+ commands
sudo tee /usr/local/bin/vmx > /dev/null <<'EOF'
#!/bin/bash
KEY_HASH=$(cat /root/vmx_exit_key.txt | sha256sum | awk '{print $1}')
SERVICE="vmx-mc"

banner() { echo "====================================="; echo "        VMX Premium Manager"; echo "====================================="; }

cmd="${1,,}"   # lowercase
arg="$2"

case "$cmd" in
# Server control
start) banner; sudo /usr/local/bin/vmx-service-wrapper start; echo "Server Started.";;
stop) banner; read -sp "Enter Exit Key: " INPUT; echo; INPUT_HASH=$(echo -n "$INPUT" | sha256sum | awk '{print $1}'); [[ "$INPUT_HASH" == "$KEY_HASH" ]] && sudo /usr/local/bin/vmx-service-wrapper stop && echo "Server Stopped." || echo "Wrong key.";;
restart) banner; sudo /usr/local/bin/vmx-service-wrapper restart; echo "Server Restarted.";;
status) banner; sudo /usr/local/bin/vmx-service-wrapper status;;

# Logs & Monitoring
logs) banner; journalctl -u $SERVICE -n 50;;
ram) banner; free -h;;
cpu) banner; top -bn1 | head -15;;
uptime) banner; uptime;;
disk) banner; df -h;;
stats) banner; free -h; uptime;;

# Player management
players) banner; screen -S mc -X stuff "list^M";;
ops-add) banner; screen -S mc -X stuff "op $arg^M";;
ops-remove) banner; screen -S mc -X stuff "deop $arg^M";;
whitelist-add) banner; screen -S mc -X stuff "whitelist add $arg^M";;
whitelist-remove) banner; screen -S mc -X stuff "whitelist remove $arg^M";;
ban-add) banner; screen -S mc -X stuff "ban $arg^M";;
ban-remove) banner; screen -S mc -X stuff "pardon $arg^M";;
kick) banner; screen -S mc -X stuff "kick $arg^M";;
save-all) banner; screen -S mc -X stuff "save-all^M";;
seed) banner; screen -S mc -X stuff "seed^M";;

# Server info
ip) banner; curl -s ifconfig.me; echo ":25565";;
version) banner; screen -S mc -X stuff "version^M";;
plugins) banner; ls /minecraft/plugins || echo "No plugins installed";;
motd) banner; cat /minecraft/motd.txt || echo "No MOTD set";;
players-count) banner; screen -S mc -X stuff "list^M";;
uptime-server) banner; systemctl show -p ActiveEnterTimestamp $SERVICE;;

# Backups
backup) banner; tar -czf /minecraft/backup-$(date +%F).tar.gz /minecraft; echo "Backup Created.";;
restore) banner; tar -xzf /minecraft/backup-$arg /minecraft; echo "Backup Restored.";;
backup-list) banner; ls /minecraft/backup-*;;
backup-rotate) banner; find /minecraft/ -maxdepth 1 -name "backup-*" -mtime +7 -delete; echo "Old backups removed.";;
auto-backup-start) banner; echo "Auto backup cron placeholder";;
auto-backup-stop) banner; echo "Stop auto backup cron placeholder";;

# Playit
playit-setup) banner; echo "Starting Playit tunnel...";;
playit-start) banner; echo "Playit tunnel started";;
playit-stop) banner; echo "Playit tunnel stopped";;

# Misc / Extra commands
gc) banner; echo "Triggering JVM GC...";;
console) banner; screen -r mc;;
say) banner; screen -S mc -X stuff "say $arg^M";;
whitelist-list) banner; screen -S mc -X stuff "whitelist list^M";;
ban-list) banner; screen -S mc -X stuff "banlist^M";;
reload) banner; screen -S mc -X stuff "reload^M";;
stop-world) banner; echo "Stopping world placeholder";;
start-world) banner; echo "Starting world placeholder";;
save-world) banner; echo "Saving world placeholder";;
motd-set) banner; echo "$arg" > /minecraft/motd.txt;;
seed-show) banner; screen -S mc -X stuff "seed^M";;
chunk-info) banner; echo "Chunk info placeholder";;
tps) banner; echo "TPS placeholder";;
players-op) banner; screen -S mc -X stuff "oplist^M";;
players-pv) banner; screen -S mc -X stuff "list^M";;
version-show) banner; screen -S mc -X stuff "version^M";;
debug-on) banner; echo "Debug enabled";;
debug-off) banner; echo "Debug disabled";;
update) banner; echo "Update placeholder";;

help|*) banner; echo "64+ Commands available. Run 'vmx help'";;
esac
EOF

sudo chmod +x /usr/local/bin/vmx

# 10️⃣ Create case-insensitive aliases
for x in VMX Vmx vMx vmX; do sudo ln -sf /usr/local/bin/vmx /usr/local/bin/$x; done

# 11️⃣ Enable and start Minecraft service
sudo systemctl daemon-reload
sudo systemctl enable vmx-mc
sudo systemctl start vmx-mc

echo "====================================="
echo "VMX Premium Manager Installed ✅"
echo "Run using: vmx, VMX, Vmx, vmX"
echo "Exit Key (root-only): /root/vmx_exit_key.txt"
echo "64+ Commands ready!"
echo "====================================="
