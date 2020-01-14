#!/bin/bash
function addlog(){
    dtime="$(date +'%d/%m/%y %H:%M:%S' 2>/dev/null)"
    echo "'Timestamp: $dtime','$1'"
    
    [[ "$2" == 'err' ]] && exit 1
}

((EUID)) && addlog 'run-node.sh requires root permissions - quitting' 'err'

nodepath='/home/user/node.sh'
passfile='/home/user/passfile.txt'
nlogfile='/var/log/node.sh.log'
nodecmd="$nodepath -p $passfile"

[[ -f "$nlogfile" ]] || touch "$nlogfile" >&/dev/null || addlog "$nlogfile does not exist and cannot be created - quitting" 'err'
[[ -x "$nodepath" ]] || addlog "$nodepath is non-executable - quitting" 'err'
[[ -r "$passfile" ]] || addlog "$passfile is non-readable - quitting" 'err'
[[ -w "$nlogfile" ]] || addlog "$nlogfile is non-writable - quitting" 'err'

curtime="$(date +%s || addlog "Unable to get current epoch" 'err')"
logage="$(stat -c%Y "$nlogfile" || addlog "Unable to get age of $nlogfile" 'err')"
if ((curtime - logage >= 86400)); then
    if tar czf "nodelog-$curtime".tar.gz "$nlogfile" >&/dev/null; then
        addlog "Created archive nodelog-$curtime.tar.gz"
        if cp /dev/null "$nlogfile" >&/dev/null; then
            addlog "Emptied $nlogfile"
        else
            addlog "Unable to empty $nlogfile"
        fi
    else
        addlog "Unable to create archive nodelog-$curtime.tar.gz"
    fi
fi

if pgrep harmony >&/dev/null; then
    if pkill harmony >&/dev/null || pkill -SIGKILL harmony >&/dev/null; then
        addlog 'Terminated harmony process'
    else
        addlog 'Problem ending harmony process - quitting' 'err'
    fi
fi

pcount=0
while pgrep node.sh >&/dev/null; do
    sleep 1
    ((++pcount >= 120)) || continue
    addlog 'node.sh still running after 2 minutes - forcefully ending'
    if pkill -SIGKILL node.sh >&/dev/null; then
        addlog 'Killed node.sh process'
    else
        addlog 'Could not kill node.sh process - quitting' 'err'
    fi
done

setsid -f "$nodecmd" >&"$nlogfile"

if pgrep node.sh >&/dev/null; then
    addlog 'Started new node.sh process'
else
    addlog 'Problem starting new node.sh process - quitting' 'err'
fi
