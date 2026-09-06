#!/bin/sh

if ! [ -x /usr/local/bin/perl ]
then
        echo "This script requires perl."
        exit 1
fi
echo "/usr/local/bin/perl found."

AGY=/usr/local/bin/agy
MESSAGE="projects store: fsnotify error"

if ! [ -x "$AGY" ]
then
        echo "No executable $AGY found."
        exit 1
fi

if ! [ -w "$AGY" ]
then
        echo "You cannot write to $AGY. Are you running this script as root?"
        exit 1
fi

echo "To patch: $AGY"
echo

MATCHES=$(grep -bao "$MESSAGE" "$AGY")
if ! [ "$MATCHES" ]
then
        echo "No matches for message."
        exit 1
fi
COUNT=$(echo "$MATCHES" | wc -l)
if [ "$COUNT" -ne 1 ]
then
        echo "Wrong number of message matches: $COUNT"
        exit 1
fi

DADDR=$(echo "$MATCHES" | /usr/bin/sed -e s/:.*$//)
ADDR=$(printf "%x" "$DADDR")
echo "Message found at 0x$ADDR."

ASM=$(/usr/bin/objdump -d "$AGY" | grep -A 2 "$ADDR")
if ! [ "$ASM" ]
then
        echo "No assembly block found."
        exit 1
fi
echo
echo "Assembly:"
echo "$ASM"
echo
COUNT=$(echo "$ASM" | wc -l)
if [ "$COUNT" -ne 3 ]
then
        echo "Wrong number of assembly lines: $COUNT"
        exit 1
fi

if ! echo "$ASM" | /usr/bin/awk '
        BEGIN { found = 0; }
        NR==1 && /leaq/ { print "leaq found"; found++ }
        NR==2 && /movl/ { print "movl found"; found++ }
        NR==3 && /callq/ { print "callq found"; found++ }
        END { exit (found == 3) ? 0 : 1 }
        '
then
        echo "Unexpected assembly."
        exit 1
fi

bytes_leaq=$(echo "$ASM" | grep leaq | /usr/bin/sed -e 's/.*:\(.*[^[:blank:]]\)[[:blank:]]*leaq.*/\1/')
bytes_movl=$(echo "$ASM" | grep movl | /usr/bin/sed -e 's/.*:\(.*[^[:blank:]]\)[[:blank:]]*movl.*/\1/')
bytes_callq=$(echo "$ASM" | grep callq | /usr/bin/sed -e 's/.*:\(.*[^[:blank:]]\)[[:blank:]]*callq.*/\1/')
PREFIX=$(echo "$bytes_leaq" | /usr/bin/sed -e 's/ /\\x/g')$(echo "$bytes_movl" | /usr/bin/sed -e 's/ /\\x/g')
FROM=$PREFIX$(echo "$bytes_callq" | /usr/bin/sed -e 's/ /\\x/g')
TO=$PREFIX'\x90\x90\x90\x90\x90'

echo
echo "Will substitute"
echo "$FROM"
echo "to"
echo "$TO"

/usr/local/bin/perl -0777 -pi -e "s/$FROM/$TO/g" "$AGY"
