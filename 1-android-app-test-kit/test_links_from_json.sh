#!/bin/bash
# Stream Tester Script
# Validates live video/audio streams from a JSON input file using ffprobe and yt-dlp
# Generates a detailed log (stream_test_log.txt) and an HTML report (stream_test_report.html)

JSON_FILE="/Users/sawan/Documents/22-ChakroVen/1-chakroventures/linksApps/Malaysia6/dataFileMalaysia6.json"
LOG_FILE="stream_test_log.txt"
> "$LOG_FILE"

HTML_FILE="stream_test_report.html"
> "$HTML_FILE"

cat <<EOF >> "$HTML_FILE"
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>Stream Test Report</title>
  <style>
    body { font-family: Arial, sans-serif; padding: 20px; }
    h2 { margin-top: 40px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 8px 12px; border: 1px solid #ccc; text-align: left; }
    .working { background-color: #e0f7e9; }
    .broken { background-color: #fde0e0; }
    .section { margin-bottom: 40px; }
    button { padding: 4px 10px; }
  </style>
  <script>
  function copyToClipboard(text, button) {
    navigator.clipboard.writeText(text).then(() => {
      const toast = document.createElement("div");
      toast.textContent = "Copied!";
      toast.style.position = "absolute";
      toast.style.backgroundColor = "#333";
      toast.style.color = "#fff";
      toast.style.padding = "4px 8px";
      toast.style.borderRadius = "4px";
      toast.style.fontSize = "12px";
      toast.style.whiteSpace = "nowrap";
      toast.style.zIndex = 1000;
      toast.style.transform = "translateY(-150%)";
      toast.style.opacity = "0.95";
      toast.style.boxShadow = "0 0 5px rgba(0, 0, 0, 0.2)";

      // Position the toast relative to the button
      const rect = button.getBoundingClientRect();
      toast.style.left = rect.left + window.scrollX + "px";
      toast.style.top = rect.top + window.scrollY - 20 + "px";

      document.body.appendChild(toast);

      setTimeout(() => {
        toast.remove();
      }, 1200); // fades after 1.2 seconds
    });
  }
</script>
</head>
<body>
<h1>📺 Stream Test Report</h1>
<p>Generated on $(date)</p>
EOF

total=0
working=0
broken=0

declare -a h1_items
declare -a g2_items

# Ensure dependencies are installed
for cmd in ffprobe yt-dlp jq; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❗ $cmd not found. Please install it (e.g., brew install $cmd)"
    exit 1
  fi
done

TEMP_ITEMS=$(mktemp)
jq -c '.items[] | {itemId: .itemId, title: .title, link: .link}' "$JSON_FILE" > "$TEMP_ITEMS"

while IFS= read -r item; do
  itemId=$(echo "$item" | jq -r '.itemId')
  title=$(echo "$item" | jq -r '.title')
  link=$(echo "$item" | jq -r '.link')

  # Sanitize title to avoid breaking the _sep_ format
  title_cleaned=$(echo "$title" | sed 's/_sep_/-/g')

  total=$((total+1))
  is_working=0

  if [[ "$link" == *"youtube.com"* ]]; then
    yt_info=$(yt-dlp -j "$link" 2>yt_error.log)
    yt_status=$?
    yt_unavailable=$(grep -Ei "private|unavailable|sign in|live stream recording is not available" yt_error.log)

    if [[ $yt_status -eq 0 && -z "$yt_unavailable" ]] && echo "$yt_info" | jq -e '.is_live == true and .availability == "public"' &>/dev/null; then
      result_line="🔄 Testing: [$itemId] - $title - ✅ $title is WORKING $link"
      is_working=1
    else
      result_line="🔄 Testing: [$itemId] - $title - ❌ $title is BROKEN $link"
    fi

    rm -f yt_error.log
  else
    if ffprobe -v error -timeout 5000000 -i "$link" > /dev/null 2>&1; then
      result_line="🔄 Testing: [$itemId] - $title - ✅ $title is WORKING $link"
      is_working=1
    else
      result_line="🔄 Testing: [$itemId] - $title - ❌ $title is BROKEN $link"
    fi
  fi

  echo "$result_line" | tee -a "$LOG_FILE"

  if [[ $is_working -eq 1 ]]; then
    working=$((working+1))
    [[ "$itemId" == H1* ]] && h1_items+=("${itemId}_sep_${title_cleaned}_sep_WORKING_sep_${link}")
    [[ "$itemId" == G2* ]] && g2_items+=("${itemId}_sep_${title_cleaned}_sep_WORKING_sep_${link}")
  else
    broken=$((broken+1))
    [[ "$itemId" == H1* ]] && h1_items+=("${itemId}_sep_${title_cleaned}_sep_BROKEN_sep_${link}")
    [[ "$itemId" == G2* ]] && g2_items+=("${itemId}_sep_${title_cleaned}_sep_BROKEN_sep_${link}")
  fi
done < "$TEMP_ITEMS"

rm "$TEMP_ITEMS"

{
  echo ""
  echo "==============================="
  echo "✅ Total links tested : $total"
  echo "✅ Links working      : $working"
  echo "❌ Links broken       : $broken"
  echo "==============================="
  echo ""
  echo "▶ H1 items:"
  echo "✅ [Working]"
  for entry in "${h1_items[@]}"; do
    [[ "$entry" == *"WORKING"* ]] && echo "${entry//|||/ | }"
  done
  echo ""
  echo "❌ [Broken]"
  for entry in "${h1_items[@]}"; do
    [[ "$entry" == *"BROKEN"* ]] && echo "${entry//|||/ | }"
  done
  echo ""
  echo "▶ G2 items:"
  echo "✅ [Working]"
  for entry in "${g2_items[@]}"; do
    [[ "$entry" == *"WORKING"* ]] && echo "${entry//|||/ | }"
  done
  echo ""
  echo "❌ [Broken]"
  for entry in "${g2_items[@]}"; do
    [[ "$entry" == *"BROKEN"* ]] && echo "${entry//|||/ | }"
  done
} >> "$LOG_FILE"

echo ""
echo "✅ All done. Log file saved to: $LOG_FILE"

# Generate HTML clickable report
{
  echo "<h2>▶ H1 items</h2>"
  echo "<h3>✅ [Working]</h3><table><tr><th>Item ID</th><th>Title</th><th>Link</th><th>Action</th></tr>"
  for entry in "${h1_items[@]}"; do
    if [[ "$entry" == *"WORKING"* ]]; then
      id=$(echo "$entry" | awk -F '_sep_' '{print $1}')
      title=$(echo "$entry" | awk -F '_sep_' '{print $2}')
      link=$(echo "$entry" | awk -F '_sep_' '{print $4}')
      echo "<tr class='working'><td>$id</td><td>$title</td><td>$link</td><td><button onclick=\"copyToClipboard('$link', this)\">Copy</button></td></tr>"
    fi
  done
  echo "</table><br>"

  echo "<h3>❌ [Broken]</h3><table><tr><th>Item ID</th><th>Title</th><th>Link</th><th>Action</th></tr>"
  for entry in "${h1_items[@]}"; do
    if [[ "$entry" == *"BROKEN"* ]]; then
      id=$(echo "$entry" | awk -F '_sep_' '{print $1}')
      title=$(echo "$entry" | awk -F '_sep_' '{print $2}')
      link=$(echo "$entry" | awk -F '_sep_' '{print $4}')
      echo "<tr class='broken'><td>$id</td><td>$title</td><td>$link</td><td><button onclick=\"copyToClipboard('$link', this)\">Copy</button></td></tr>"
    fi
  done
  echo "</table>"

  echo "<h2>▶ G2 items</h2>"
  echo "<h3>✅ [Working]</h3><table><tr><th>Item ID</th><th>Title</th><th>Link</th><th>Action</th></tr>"
  for entry in "${g2_items[@]}"; do
    if [[ "$entry" == *"WORKING"* ]]; then
      id=$(echo "$entry" | awk -F '_sep_' '{print $1}')
      title=$(echo "$entry" | awk -F '_sep_' '{print $2}')
      link=$(echo "$entry" | awk -F '_sep_' '{print $4}')
      echo "<tr class='working'><td>$id</td><td>$title</td><td>$link</td><td><button onclick=\"copyToClipboard('$link', this)\">Copy</button></td></tr>"
    fi
  done
  echo "</table><br>"

  echo "<h3>❌ [Broken]</h3><table><tr><th>Item ID</th><th>Title</th><th>Link</th><th>Action</th></tr>"
  for entry in "${g2_items[@]}"; do
    if [[ "$entry" == *"BROKEN"* ]]; then
      id=$(echo "$entry" | awk -F '_sep_' '{print $1}')
      title=$(echo "$entry" | awk -F '_sep_' '{print $2}')
      link=$(echo "$entry" | awk -F '_sep_' '{print $4}')
      echo "<tr class='broken'><td>$id</td><td>$title</td><td>$link</td><td><button onclick=\"copyToClipboard('$link', this)\">Copy</button></td></tr>"
    fi
  done
  echo "</table>"
  echo "</body></html>"
} >> "$HTML_FILE"

