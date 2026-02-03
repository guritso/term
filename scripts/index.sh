#!/bin/bash
# Update all data (anime + repos) - runs via cron

OUTPUT_DIR="/usr/share/nginx/html"
LOG_FILE="/var/log/index-update.log"
MAL_USER="guritso"
GITHUB_USER="guritso"

echo "[$(date)] Starting data update..." >> "$LOG_FILE"

# ========== UPDATE ANIME DATA ==========
echo "[$(date)] Fetching anime data..." >> "$LOG_FILE"

TEMP_DIR="/tmp/anime-update-$$"
mkdir -p "$TEMP_DIR"

OFFSET=0
ALL_DATA_FILE="$TEMP_DIR/all.json"
echo "[]" > "$ALL_DATA_FILE"

while true; do
    CHUNK_FILE="$TEMP_DIR/chunk_$OFFSET.json"
    
    curl -s "https://myanimelist.net/animelist/$MAL_USER/load.json?offset=$OFFSET&order=5&status=7" \
      -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
      -o "$CHUNK_FILE" 2>/dev/null
    
    if [ ! -s "$CHUNK_FILE" ] || [ $(wc -c < "$CHUNK_FILE") -lt 10 ]; then
        echo "[$(date)] Anime chunk $OFFSET empty, stopping." >> "$LOG_FILE"
        break
    fi
    
    if ! python3 -c "import json; data=json.load(open('$CHUNK_FILE')); exit(0 if isinstance(data, list) else 1)" 2>/dev/null; then
        echo "[$(date)] Anime chunk $OFFSET invalid JSON, stopping." >> "$LOG_FILE"
        break
    fi
    
    COUNT=$(python3 -c "import json; print(len(json.load(open('$CHUNK_FILE'))))" 2>/dev/null || echo "0")
    
    if [ "$COUNT" -eq 0 ]; then
        echo "[$(date)] No more anime items at offset $OFFSET." >> "$LOG_FILE"
        break
    fi
    
    echo "[$(date)] Fetched $COUNT anime items at offset $OFFSET" >> "$LOG_FILE"
    
    python3 << EOF >> "$LOG_FILE" 2>&1
import json
try:
    with open('$ALL_DATA_FILE', 'r') as f:
        all_data = json.load(f)
    with open('$CHUNK_FILE', 'r') as f:
        chunk = json.load(f)
    all_data.extend(chunk)
    with open('$ALL_DATA_FILE', 'w') as f:
        json.dump(all_data, f)
    print(f"Merged {len(chunk)} anime items, total: {len(all_data)}")
except Exception as e:
    print(f"Error: {e}")
EOF
    
    TOTAL=$(python3 -c "import json; print(len(json.load(open('$ALL_DATA_FILE'))))" 2>/dev/null || echo "0")
    if [ "$TOTAL" -gt 10000 ]; then
        echo "[$(date)] Safety limit reached, stopping." >> "$LOG_FILE"
        break
    fi
    
    OFFSET=$((OFFSET + 300))
    sleep 0.5
done

if [ -s "$ALL_DATA_FILE" ]; then
    # Filter only needed fields for anime
    python3 << EOF >> "$LOG_FILE" 2>&1
import json

with open('$ALL_DATA_FILE', 'r') as f:
    all_data = json.load(f)

# Keep only fields used in index.html
filtered = []
for item in all_data:
    filtered.append({
        'anime_title': item.get('anime_title'),
        'anime_url': item.get('anime_url'),
        'score': item.get('score'),
        'status': item.get('status'),
        'num_watched_episodes': item.get('num_watched_episodes'),
        'anime_num_episodes': item.get('anime_num_episodes')
    })

with open('$OUTPUT_DIR/recent_animes/anime-data.json', 'w') as f:
    json.dump(filtered, f)

print(f"✓ Anime filtered: {len(filtered)} items")
EOF
    echo "[$(date)] ✓ Anime updated" >> "$LOG_FILE"
else
    echo "[$(date)] ✗ Failed to update anime" >> "$LOG_FILE"
fi

rm -rf "$TEMP_DIR"

# ========== UPDATE REPO DATA ==========
echo "[$(date)] Fetching repo data..." >> "$LOG_FILE"

PAGE=1
REPO_ALL="$OUTPUT_DIR/repo-data.json.tmp"
echo "[]" > "$REPO_ALL"

while true; do
    REPO_CHUNK="$OUTPUT_DIR/repo_chunk_$PAGE.json"
    
    curl -s "https://api.github.com/users/$GITHUB_USER/repos?sort=updated&per_page=100&page=$PAGE" \
      -H "User-Agent: Mozilla/5.0" \
      -H "Accept: application/vnd.github.v3+json" \
      -o "$REPO_CHUNK" 2>/dev/null
    
    if [ ! -s "$REPO_CHUNK" ] || [ $(wc -c < "$REPO_CHUNK") -lt 10 ]; then
        echo "[$(date)] Repo page $PAGE empty, stopping." >> "$LOG_FILE"
        break
    fi
    
    if ! python3 -c "import json; data=json.load(open('$REPO_CHUNK')); exit(0 if isinstance(data, list) else 1)" 2>/dev/null; then
        echo "[$(date)] Repo page $PAGE invalid JSON, stopping." >> "$LOG_FILE"
        break
    fi
    
    REPO_COUNT=$(python3 -c "import json; print(len(json.load(open('$REPO_CHUNK'))))" 2>/dev/null || echo "0")
    
    if [ "$REPO_COUNT" -eq 0 ]; then
        echo "[$(date)] No more repos at page $PAGE." >> "$LOG_FILE"
        break
    fi
    
    echo "[$(date)] Fetched $REPO_COUNT repos at page $PAGE" >> "$LOG_FILE"
    
    python3 << EOF >> "$LOG_FILE" 2>&1
import json
try:
    with open('$REPO_ALL', 'r') as f:
        all_data = json.load(f)
    with open('$REPO_CHUNK', 'r') as f:
        chunk = json.load(f)
    all_data.extend(chunk)
    with open('$REPO_ALL', 'w') as f:
        json.dump(all_data, f)
    print(f"Merged {len(chunk)} repos, total: {len(all_data)}")
except Exception as e:
    print(f"Error: {e}")
EOF
    
    rm -f "$REPO_CHUNK"
    
    # GitHub returns max 100 per page, if we got 100 there might be more
    if [ "$REPO_COUNT" -lt 100 ]; then
        break
    fi
    
    PAGE=$((PAGE + 1))
    sleep 0.5
done

if [ -s "$REPO_ALL" ]; then
    # Filter only needed fields for repos
    python3 << EOF >> "$LOG_FILE" 2>&1
import json

with open('$REPO_ALL', 'r') as f:
    all_data = json.load(f)

# Keep only fields used in index.html
filtered = []
for item in all_data:
    filtered.append({
        'name': item.get('name'),
        'html_url': item.get('html_url'),
        'description': item.get('description'),
        'stargazers_count': item.get('stargazers_count'),
        'size': item.get('size'),
        'fork': item.get('fork'),
        'archived': item.get('archived')
    })

with open('$OUTPUT_DIR/github_repos/repo-data.json', 'w') as f:
    json.dump(filtered, f)

print(f"✓ Repos filtered: {len(filtered)} items")
EOF
    rm -f "$REPO_ALL"
    echo "[$(date)] ✓ Repos updated" >> "$LOG_FILE"
else
    rm -f "$REPO_ALL"
    echo "[$(date)] ✗ Failed to update repos" >> "$LOG_FILE"
fi

echo "[$(date)] === Update complete ===" >> "$LOG_FILE"

