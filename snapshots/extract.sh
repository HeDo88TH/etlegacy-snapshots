#!/usr/bin/env bash

# ------------------------------------------------------
# A mapping from three-letter month abbreviations to 2-digit numeric months
# ------------------------------------------------------
declare -A MONTHS=(
  ["Jan"]="01" ["Feb"]="02" ["Mar"]="03" ["Apr"]="04" ["May"]="05" ["Jun"]="06"
  ["Jul"]="07" ["Aug"]="08" ["Sep"]="09" ["Oct"]="10" ["Nov"]="11" ["Dec"]="12"
)

# ------------------------------------------------------
# Print CSV header (Version;Build Date) with Windows EOL
# ------------------------------------------------------
echo -e "Version;Build Date\r"

# ------------------------------------------------------
# Loop over matching archives
# ------------------------------------------------------
for f in etlegacy-*.tar*; do
  [ -e "$f" ] || continue  # Skip if no files match

  # ----------------------------------------------------
  # 1) Derive version from the filename:
  #    - Strip leading 'etlegacy-'
  #    - Strip trailing '-x86_64(.tar|.tar.gz|...)'
  # ----------------------------------------------------
  baseName="$(basename "$f")"
  version="$(echo "$baseName" \
    | sed -E 's/^etlegacy-//; s/-x86_64(\.tar(\.gz|\.xz)?)?$//')"

  # ----------------------------------------------------
  # 2) Find the path to etl.x86_64 inside the archive
  # ----------------------------------------------------
  etl_path="$(tar -tf "$f" | grep -E 'etl\.x86_64$' || true)"

  # If we can't find "etl.x86_64", skip (or print a placeholder row)
  if [ -z "$etl_path" ]; then
    echo -e "${version};No etl.x86_64 found\r"
    continue
  fi

  # ----------------------------------------------------
  # 3) Extract only etl.x86_64 to a temp directory,
  #    stripping the top folder.
  # ----------------------------------------------------
  rm -rf tmp_etl_extract
  mkdir -p tmp_etl_extract

  # --strip-components=1 removes the first path component
  # (e.g., "etlegacy-v2.82.1-74-g956e441-x86_64/etl.x86_64" -> "etl.x86_64")
  tar --strip-components=1 -xf "$f" -C tmp_etl_extract "$etl_path" 2>/dev/null

  # Verify that we actually got the file
  if [ ! -f tmp_etl_extract/etl.x86_64 ]; then
    echo -e "${version};Extraction failed\r"
    rm -rf tmp_etl_extract
    continue
  fi

  # ----------------------------------------------------
  # 4) Use 'strings' + 'grep' to find a pattern "Mon DD YYYY"
  #    e.g., "Jun  7 2024"
  # ----------------------------------------------------
  rawDate="$(strings tmp_etl_extract/etl.x86_64 \
            | grep -Eo '[A-Z][a-z]{2}[[:space:]]+[0-9]{1,2}[[:space:]]+[0-9]{4}' \
            | head -n 1)"

  if [ -z "$rawDate" ]; then
    echo -e "${version};No date found\r"
    rm -rf tmp_etl_extract
    continue
  fi

  # ----------------------------------------------------
  # 5) Parse "Mon DD YYYY" and convert to "DD/MM/YYYY"
  # ----------------------------------------------------
  # Example rawDate = "Jun  7 2024"
  monthStr=$(echo "$rawDate" | awk '{print $1}')
  day=$(echo "$rawDate"      | awk '{print $2}')
  year=$(echo "$rawDate"     | awk '{print $3}')

  # Convert abbreviations "Jan" -> "01", etc.
  # Then parse them as decimal (with 10#) to avoid octal issues
  monthNum=$((10#${MONTHS[$monthStr]}))
  dayNum=$((10#$day))

  # Format date as DD/MM/YYYY (pad day/month with zero if necessary).
  # We use printf with %02d (two-digit, zero-padded) for day and month.
  buildDate="$(printf "%02d/%02d/%04d" "$dayNum" "$monthNum" "$year")"

  # ----------------------------------------------------
  # 6) Output the CSV line "Version;Build Date" + Windows EOL
  # ----------------------------------------------------
  echo -e "${version};${buildDate}\r"

  # Cleanup for next iteration
  rm -rf tmp_etl_extract
done
