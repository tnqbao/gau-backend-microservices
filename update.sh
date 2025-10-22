#!/bin/bash

set -e

today=$(date +"%Y-%m-%d")
update_logs=""

git config --file .gitmodules --get-regexp path | while read -r key path; do
  echo "Updating submodule: $path"

  cd "$path"

  # Checkout về master nếu có
  if git show-ref --verify --quiet refs/heads/master; then
    git checkout master
  else
    echo "Skipping $path — no local 'master' branch."
    cd - > /dev/null
    continue
  fi

  git pull origin master

  latest_msg=$(git log -1 --pretty=format:"%s")
  update_logs+="$path (master): $latest_msg"$'\n'

  cd - > /dev/null
done

if [[ -n "$update_logs" ]]; then
  echo "Committing submodule updates to main repository..."

  git add .

  git commit -m "Update submodules on $today"$'\n\n'"$update_logs"
  git push origin master
else
  echo "No updates found in submodules."
fi
