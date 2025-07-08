#!/bin/bash
## https://documentation.ubuntu.com/server/how-to/web-services/install-a-squid-server/

VISIBLENAME="jacobsquidsrv"

echo ""
echo "[INFO] install squid server"
sudo apt install squid -y

# certificate
echo ""
echo "[INFO] Generating cert for squid server"
openssl req -new -newkey rsa:2048 -sha256 -days 365 -nodes -x509 -extensions v3_ca -keyout squid-ca-key.pem -out squid-ca-cert.pem
cat squid-ca-cert.pem squid-ca-key.pem >> squid-ca-cert-key.pem
sudo mkdir /etc/squid/certs
sudo mv squid-ca-cert-key.pem /etc/squid/certs/.

cat << EOF > /etc/squid/squid.conf
acl SSL_ports port 443
#http_access deny !Safe_ports
#http_access deny CONNECT !SSL_ports
#http_access allow localhost manager
#http_access deny manager
#http_access allow localhost
#http_access deny to_localhost
#http_access deny to_linklocal
#http_access deny all
http_access allow all
debug_options ALL,1 33,2 28,9
include /etc/squid/conf.d/*.conf
http_port 8888
https_port 8899 tls-cert=/etc/squid/certs/squid-ca-cert-key.pem
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
refresh_pattern .               0       20%     4320
visible_hostname ${VISIBLENAME}
EOF

sudo systemctl restart squid.service

## 
echo ""
echo "[INFO] Generating proxy.json file"

TRUSTEDCA=$(cat /etc/squid/certs/squid-ca-cert-key.pem | base64 -w 0)

CAT << EOF > proxy.json
{
  "httpProxy": "http://<IP>:8888/",
  "httpsProxy": "https://<IP>:8899/",
  "noProxy": [
    "localhost",
    "127.0.0.1"
  ],
   "trustedCA": "${TRUSTEDCA}"
}
EOF
