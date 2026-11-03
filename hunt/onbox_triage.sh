#!/bin/sh
# Read-only triage for the NetScaler username-injection / WHIPSHOT campaign.
# Run as nsroot in the BSD shell on EACH node (pdeunctxns00, pdeuwctxns00):  shell  ->  sh onbox_triage.sh > /var/tmp/triage_$(hostname).txt 2>&1
# Changes nothing on the box. Send the output file back for analysis.

IOC='213\.209\.159\.55|45\.137\.99\.92|v5v\.in|M88npieBFw|c896411e0cbc1ae9|LogonPoint/a|NSPPE;'
hdr() { echo; echo "===== $* ====="; }

hdr "host / time / uptime"; hostname; date -u; uptime; ls /var/nsinstall 2>/dev/null | tail -3

hdr "1. tar payload output: does /var/netscaler/logon/LogonPoint/a exist?"
ls -la /var/netscaler/logon/LogonPoint/ /var/netscaler/logon/LogonPoint/custom/ 2>&1
for f in /var/netscaler/logon/LogonPoint/a /var/netscaler/logon/LogonPoint/custom/a; do [ -e "$f" ] && { echo "FOUND $f"; stat -x "$f"; file "$f"; tar tzf "$f" 2>/dev/null | head -20; }; done

hdr "2. fetch payload output: /v and other dropped files"
ls -la /v /var/v /tmp/v 2>&1; [ -e /v ] && { stat -x /v; file /v; head -c 600 /v | strings; }

hdr "3. SLAPSHOT runtime artefacts"
ls -la /tmp/.uxdport /tmp/.uxdlock 2>&1; ls -la /tmp /var/tmp | head -60

hdr "4. Recently modified files in web/VPN paths (last 10 days)"
find /var/netscaler/gui /netscaler/ns_gui /var/vpn /var/netscaler/logon /flash/nsconfig -type f -mtime -10 -exec ls -la {} \; 2>/dev/null | head -200

hdr "5. PHP content hidden in non-.php files (WHIPSHOT)"
for d in /var/netscaler/gui/vpn/scripts /var/netscaler/gui/vpns/scripts /netscaler/ns_gui/vpn /var/vpn/theme /var/netscaler/logon/LogonPoint/custom; do
  grep -rIl --exclude='*.php' -e '<?php' -e 'fsockopen' -e 'HTTP_X_UX' -e 'uxdport' "$d" 2>/dev/null; done

hdr "6. httpd.conf handler / alias tampering"
grep -nE 'AddHandler|SetHandler|php_flag|php_admin|AliasMatch|\.deb|\.sig' /etc/httpd.conf /nsconfig/httpd.conf /flash/nsconfig/httpd.conf 2>&1
ls -la /etc/httpd.conf /nsconfig/httpd.conf /flash/nsconfig/httpd.conf 2>&1

hdr "7. SUID on /bin/sh"
ls -la /bin/sh /bin/csh /usr/bin/su 2>&1

hdr "8. Processes and listeners (python, fetch/curl/wget, loopback listeners)"
ps auxww | grep -Ei 'python|fetch|curl|wget|/v |sh -c|nc |perl' | grep -v grep
sockstat -4 -l 2>/dev/null | head -80
sockstat -4 -c 2>/dev/null | grep -vE ':(22|80|443|3008|3009|3010|3011|8080) ' | head -80

hdr "9. Web access logs: was the staged archive or anything IOC-related requested?"
for f in /var/log/httpaccess.log*; do case $f in *.gz) z=zgrep;; *) z=grep;; esac; $z -E "$IOC|GET /logon/LogonPoint/a" "$f" 2>/dev/null | sed "s|^|$f: |"; done | head -200

hdr "10. ns.log / messages around the attack (injection, nsaaad crash, shells)"
for f in /var/log/ns.log* /var/log/messages* /var/log/notice.log*; do case $f in *.gz) z=zgrep;; *) z=grep;; esac; $z -E "$IOC|nsaaad|core dump" "$f" 2>/dev/null | sed "s|^|$f: |"; done | tail -300

hdr "11. Shell command history (bash.log, sh history)"
ls -la /var/log/bash.log* 2>/dev/null
for f in /var/log/bash.log*; do case $f in *.gz) z=zcat;; *) z=cat;; esac; $z "$f" 2>/dev/null | grep -Ei 'fetch|curl|wget|tar |LogonPoint|/v|chmod|python|base64|rm ' | sed "s|^|$f: |"; done | tail -200
cat /root/.sh_history /root/.bash_history /var/nstmp/.sh_history 2>/dev/null | tail -100

hdr "12. Core dumps (nsaaad crashes 2026-10-03)"
ls -la /var/core /var/crash 2>&1 | head -60

hdr "13. Integrity of files replaced on 2026-10-06 09:36"
ls -la /var/netscaler/gui/vpns/scripts/vista/ /var/netscaler/gui/vpn/pluginlist.xml /netscaler/ns_gui/vpn/pluginlist.xml 2>&1
sha256 /var/netscaler/gui/vpns/scripts/vista/AGEE_setup.exe 2>/dev/null

hdr "done"
