# we expect input in the format xx xx xx... where xx -- hexadecimal values of
# the bytes we are searching for.
#
# The variable `pat` is the pattern we are looking for in the same format.

# Convert awk 1-based offset in a string xx xx xx... to 0-based offset in a
# file, containing bytes xxxxxx...
function to_offset(value) {
        return (value-1)/3
}

{
        str = $0
        shift = 0
        found = 0
        pos = 1

        while (match(str, pat)) {
                if (found == 1) {
                        print "Not unique bytes position, found sequence " pat " at least at the offsets " offset1 " and " to_offset(RSTART)+to_offset(shift) "."
                        exit 1
                }
                found = 1
                offset1 = to_offset(RSTART)
                shift = RSTART+2 # Move forward one byte
                str = substr(str, shift)
        }
        if (found == 0) {
                print "No sequence " pat " found."
                exit 1
        } else {
                printf "%d\n", offset1
                exit 0
        }
}
