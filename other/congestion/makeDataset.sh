#!/bin/bash
name="`basename -s '.txt' "$1"`_time_remove.txt"
cat "$1" | tr -s ' ' | cut -c-16 > "$name"
row=""
while read line; do
      row="$row '$line'"
done < "$name"
echo $row > "`basename -s '.txt' "$1"`_time.txt"
rm "$name"

cat "$1" | tr -s ' ' | cut -d ' ' -f3 | tr '\n' ' ' > "`basename -s '.txt' "$1"`_congestion.txt"