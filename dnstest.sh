#!/usr/bin/env bash


command -v bc > /dev/null || { echo "error: bc was not found. Please install bc."; exit 1; }
{ command -v drill > /dev/null && dig=drill; } || { command -v dig > /dev/null && dig=dig; } || { echo "error: dig was not found. Please install dnsutils."; exit 1; }


NAMESERVERS=$(grep ^nameserver /etc/resolv.conf | cut -d " " -f 2 | sed 's/\(.*\)/&#&/')

PROVIDERSV4="
1.1.1.1#cloudflare
4.2.2.1#level3
8.8.8.8#google
9.9.9.9#quad9
80.80.80.80#freenom
208.67.222.123#opendns 
199.85.126.20#norton
185.228.168.168#cleanbrowsing
77.88.8.7#yandex
156.154.70.3#neustar
8.26.56.26#comodo
45.90.28.202#nextdns
84.200.69.80#dns.watch
64.6.65.6#verisign
195.46.39.39#safedns
103.247.36.101#dnsfilter
94.140.14.14#adguard
94.140.14.140#adguard-nofilter
94.140.14.15#adguard-family
"

PROVIDERSV6="
2606:4700:4700::1111#cloudflare-v6
2001:4860:4860::8888#google-v6
2620:fe::fe#quad9-v6
2620:119:35::35#opendns-v6
2a0d:2a00:1::1#cleanbrowsing-v6
2a02:6b8::feed:0ff#yandex-v6
2a10:50c0::ad1:ff#adguard-v6
2a10:50c0::1:ff#adguard-v6-nofilter
2a10:50c0::bad1:ff#adguard-v6-family
2610:a1:1018::3#neustar-v6
"

# Testing for IPv6
$dig +short +tries=1 +time=2 +stats @2a0d:2a00:1::1 www.google.com |grep 216.239.38.120 >/dev/null 2>&1
if [ $? = 0 ]; then
    hasipv6="true"
fi

providerstotest=$PROVIDERSV4

if [ "x$1" = "xipv6" ]; then
    if [ "x$hasipv6" = "x" ]; then
        echo "error: IPv6 support not found. Unable to do the ipv6 test."; exit 1;
    fi
    providerstotest=$PROVIDERSV6

elif [ "x$1" = "xipv4" ]; then
    providerstotest=$PROVIDERSV4

elif [ "x$1" = "xall" ]; then
    if [ "x$hasipv6" = "x" ]; then
        providerstotest=$PROVIDERSV4
    else
        providerstotest="$PROVIDERSV4 $PROVIDERSV6"
    fi
else
    providerstotest=$PROVIDERSV4
fi

    

# Domains to test. Add or change them in the included top-domains.txt
DOMAINS2TEST=$(head top-domains.txt)

totaldomains=0
printf "%-21s" "DNS Name / Tests >"
for d in $DOMAINS2TEST; do
    totaldomains=$((totaldomains + 1))
    printf "%-8s" "$totaldomains"
done
printf "%-8s" "Average    IP Address"
echo ""


for p in $NAMESERVERS $providerstotest; do
    pip=${p%%#*}
    pname=${p##*#}
    ftime=0

    printf "%-21s" "$pname"
    for d in $DOMAINS2TEST; do
        ttime=$($dig +tries=1 +time=2 +stats "@$pip" "$d" |grep "Query time:" | cut -d : -f 2- | cut -d " " -f 2)
        if [ -z "$ttime" ]; then
	        #let's have time out be 1s = 1000ms
	        ttime=1000
        elif [ "x$ttime" = "x0" ]; then
	        ttime=1
	    fi

        printf "%-8s" "$ttime ms"
        ftime=$((ftime + ttime))
    done
    avg=$(bc -lq <<< "scale=2; $ftime/$totaldomains")

    printf "%-8s" "$avg ms"
    printf "%-18s" "   $pip"
    echo ""
    
done


exit 0;
