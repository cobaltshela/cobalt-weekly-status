#!/bin/bash
set -e
PAT=$(cat /tmp/cobaltshela-pat.txt)
REPO="cobalt-weekly-status"
BUILD="/tmp/cobalt-weekly-report-build"
ASSETS="/tmp/cobalt-weekly-report-assets"

cd "$BUILD"
mkdir -p assets
cp "$ASSETS/seo-kpi-dashboard.png" "$ASSETS/traffic-insights.png" assets/

echo "=== Verify PAT identity + scopes ==="
curl -sI -H "Authorization: token $PAT" https://api.github.com/user | grep -iE "^x-oauth-scopes|^x-accepted|^status"

echo ""
echo "=== Check if repo exists ==="
HTTP=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $PAT" https://api.github.com/repos/cobaltshela/$REPO)
echo "Repo exists check HTTP: $HTTP"

if [ "$HTTP" != "200" ]; then
  echo "=== Creating private repo cobaltshela/$REPO ==="
  curl -s -H "Authorization: token $PAT" -H "Accept: application/vnd.github+json" \
    -X POST https://api.github.com/user/repos \
    -d '{"name":"'$REPO'","description":"Weekly status reports for Cobalt Intelligence","private":true,"auto_init":false,"has_issues":false,"has_wiki":false}' \
    | grep -E '"full_name"|"private"|"html_url"|"message"' | head -5
fi

echo ""
echo "=== Init git + commit + push ==="
rm -rf .git
git init -q
git config user.email "shela@cobaltintelligence.com"
git config user.name "Shela Heramis"
git add index.html assets/
git commit -q -m "Weekly status: Apr 25 to May 1, 2026 (ISO week 18)"
git branch -M main
git remote remove origin 2>/dev/null || true
git remote add origin "https://${PAT}@github.com/cobaltshela/$REPO.git"
git push -u origin main 2>&1 | tail -5

echo ""
echo "=== Enable GitHub Pages (main / root) ==="
PAGES_RESP=$(curl -s -H "Authorization: token $PAT" -H "Accept: application/vnd.github+json" \
  -X POST https://api.github.com/repos/cobaltshela/$REPO/pages \
  -d '{"source":{"branch":"main","path":"/"}}')
echo "$PAGES_RESP" | grep -E '"html_url"|"status"|"message"|"source"' | head -8

echo ""
echo "=== Final Pages URL ==="
curl -s -H "Authorization: token $PAT" https://api.github.com/repos/cobaltshela/$REPO/pages | grep -E '"html_url"|"status"|"message"' | head -3
