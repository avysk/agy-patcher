#!/bin/sh

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
echo "Message '$MESSAGE' found at 0x$ADDR."

echo "Searching $AGY for assembly using it..."
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

if ! echo "$ASM" | LC_ALL=C /usr/bin/awk '
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
PREFIX="$bytes_leaq$bytes_movl"
FROM="$PREFIX$bytes_callq"
TO="$PREFIX 90 90 90 90 90"

echo
echo "Will replace"
echo "$FROM"
echo "with"
echo "$TO"
echo
echo "Searching for sequence$FROM in $AGY..."

OFFSET=$(/usr/bin/hexdump -v -e '1/1 "%02x "' "$AGY" | LC_ALL=C /usr/bin/awk -v pat="${FROM## }" -f finder.awk) || exit 1
echo "Offset in $AGY is $OFFSET."

echo "$TO" | LC_ALL=C /usr/bin/awk '
BEGIN {
        for (i=0; i<10; i++) hex[i] = i
        hex["a"]=10; hex["b"]=11; hex["c"]=12; hex["d"]=13; hex["e"]=14; hex["f"]=15
        hex["A"]=10; hex["B"]=11; hex["C"]=12; hex["D"]=13; hex["E"]=14; hex["F"]=15
}
{
        for (i=1; i<=NF; i++) {
                val = hex[substr($i, 1, 1)] * 16 + hex[substr($i, 2, 1)]
                printf "%c", val
        }
}' | /bin/dd of="$AGY" bs=1 seek="$OFFSET" conv=notrunc

echo
echo "Done."
