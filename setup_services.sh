#!/bin/bash
# Stop existing screen sessions
screen -S minecraft -X quit 2>/dev/null
screen -S playit -X quit 2>/dev/null

# Create playit systemd service
echo 'mr-god' | sudo -S tee /etc/systemd/system/playit.service > /dev/null << 'EOF'
[Unit]
Description=Playit.gg Tunnel
After=network.target

[Service]
User=mr-god
ExecStart=/home/mr-god/minecraft-server/playit
WorkingDirectory=/home/mr-god/minecraft-server
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Create minecraft systemd service
echo 'mr-god' | sudo -S tee /etc/systemd/system/minecraft.service > /dev/null << 'EOF'
[Unit]
Description=Minecraft Server
After=network.target

[Service]
User=mr-god
ExecStart=/usr/bin/java -Xms1G -Xmx2G -jar server.jar nogui
WorkingDirectory=/home/mr-god/minecraft-server
Restart=on-failure
RestartSec=10
StandardInput=null

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable services
echo 'mr-god' | sudo -S systemctl daemon-reload
echo 'mr-god' | sudo -S systemctl enable playit minecraft
echo 'mr-god' | sudo -S systemctl stop playit 2>/dev/null
echo 'mr-god' | sudo -S systemctl stop minecraft 2>/dev/null
echo 'mr-god' | sudo -S systemctl start minecraft
echo 'mr-god' | sudo -S systemctl start playit

sleep 3
echo "=== SERVICE STATUS ==="
echo 'mr-god' | sudo -S systemctl status minecraft --no-pager -l 2>&1 | head -15
echo ""
echo 'mr-god' | sudo -S systemctl status playit --no-pager -l 2>&1 | head -15
echo ""
echo "SETUP COMPLETE"
