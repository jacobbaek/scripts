#!/bin/bash
# should run root user.

TESTDOMAIN="jacobbaek.com"

apt install -y bind9 bind9utils bind9-doc dnsutils
cat << EOF > /etc/bind/named.conf.options

acl internal-network {
192.168.0.0/24;
};
options {
        directory "/var/cache/bind";
        allow-query { localhost; internal-network; };
        allow-transfer { localhost; };
        forwarders { 8.8.8.8; };
        recursion yes;
        dnssec-validation auto;
        listen-on-v6 { any; };
};
EOF

cat << EOF > /etc/bind/named.conf.local

zone "$TESTDOMAIN" IN {
        type master;
        file "/etc/bind/forward.$TESTDOMAIN";
        allow-update { none; };
};
zone "0.168.192.in-addr.arpa" IN {
        type master;
        file "/etc/bind/reverse.$TESTDOMAIN";
        allow-update { none; };
};
EOF

cat << EOF > /etc/bind/forward.$TESTDOMAIN
\$TTL 604800
@ IN SOA test.$TESTDOMAIN. root.test.$TESTDOMAIN. (
                                   2022072651 ; Serial
                                   3600 ; Refresh
                                   1800 ; Retry
                                   604800 ; Expire
                                   604600 ) ; Negative Cache TTL
;Name Server Information
@       IN  NS    test.$TESTDOMAIN.

;IP address of Your Domain Name Server(DNS)
test    IN  A     192.168.0.40

;Mail Server MX (Mail exchanger) Record
$TESTDOMAIN. IN MX 10   mail.$TESTDOMAIN.

;A Record for Host names
www     IN  A    192.168.0.50
mail    IN  A    192.168.0.60

;CNAME Record
ftp     IN CNAME www.$TESTDOMAIN.
EOF

cat << EOF > /etc/bind/reverse.$TESTDOMAIN
\$TTL 86400
@ IN SOA $TESTOMDINA. root.$TESTDOMAIN. (
                           2022072752 ;Serial
                           3600 ;Refresh
                           1800 ;Retry
                           604800 ;Expire
                           86400 ;Minimum TTL
)
;Your Name Server Info
@ IN NS test.$TESTDOMAIN.
test      IN  A    192.168.0.40
;Reverse Lookup for Your DNS Server
40        IN PTR   test.$TESTDOMAIN.
;PTR Record IP address to HostName
50        IN PTR   www.$TESTDOMAIN.
60        IN PTR   mail.$TESTDOMAIN.
EOF

systemctl restart named
systemctl --no-pager status named
