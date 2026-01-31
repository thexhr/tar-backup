#!/bin/sh

# Copyright (c) 2026 Matthias Schmidt <xhr@giessen.ccc.de>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# FQDN and user name for your target backup host
THOST=backup@target.invalid
# SSH port of the target
TPORT=22
# Path for backups on the target host
TPATH="/home/backup"
# Directory where the script is located
LSCRIPTPATH="/root/tar-backup"
# Local path to the private SSH key
TKEY="${LSCRIPTPATH}/dump-backup"

##############################################################################
BNAME="root-$(hostname -s)"
XCF=${LSCRIPTPATH}/exclude-file
ALST=${LSCRIPTPATH}/all-files
PLST=${LSCRIPTPATH}/pruned-list
f=${LSCRIPTPATH}/lnum
_max=2

[ ! -f ${TKEY} ] && echo "[-] Cannot find SSH key file. Abort" && exit 1
[ ! -f ${XCF} ] && echo "[-] Cannot find exclude list. Abort" && exit 1

[ ! -f ${f} ] && echo "[-] Cannot find number file.  Create one" && echo "1" > ${f}
num=$(cat ${f})

echo "[+] Start backup process, Level ${num} ..."
echo "    $(date)"

# Create a list of all files to backup
find / \! -type d > ${ALST} && echo "[+] Created list of files to backup"

# Prune the list
egrep -f ${XCF} -v ${ALST} > ${PLST} && echo "[+] List successfully pruned"

# Create _max dumps and then overwrite the first one again
tar -C / -cNzpf - -I ${PLST} | \
	age -R ${TKEY}.pub | \
        ssh -i ${TKEY} ${THOST} -p ${TPORT} "cat > ${TPATH}/${BNAME}-${num}.tar.gz.age" && \
        echo "[+] Backup successfully done"

# Restrict file permissions on remote side
ssh -i ${TKEY} ${THOST} -p ${TPORT} "cd ${TPATH} && chmod 600 *.tar.gz*" && \
        echo "[+] Restrict file permissions"

# Show files on the remote side
echo "[+] Show files on remote side"
ssh -i ${TKEY} ${THOST} -p ${TPORT} "ls -lh ${TPATH}"

if [ ${num} -ge ${_max} ]; then
        num=0
        echo "[+] Rollover backup cycle"
else
        echo "[+] Increase backup cycle number"
fi

newnum=$((${num} + 1))
echo ${newnum} > ${f}

echo "[+] Backup done"
echo "    $(date)"

exit $?
