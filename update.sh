#!/bin/bash

# Script để cập nhật tất cả các Git submodule,
# lấy commit message mới nhất từ mỗi submodule,
# sau đó commit lại trong repo chính.

set -e  # Dừng script nếu có lỗi xảy ra

# Lấy ngày hôm nay để gắn vào commit message
today=$(date +"%Y-%m-%d")

# Biến chứa tổng hợp thông tin cập nhật từ từng submodule
update_logs=""

# Lặp qua tất cả các submodule được khai báo trong .gitmodules
git config --file .gitmodules --get-regexp path | while read -r key path; do
  echo "Updating submodule: $path"

  # Di chuyển vào thư mục submodule
  cd "$path"

  # Lấy tên nhánh hiện tại (thường là main hoặc master)
  branch=$(git symbolic-ref --short HEAD)

  # Pull commit mới nhất từ remote của submodule
  git pull origin "$branch"

  # Lấy commit message mới nhất trong submodule
  latest_msg=$(git log -1 --pretty=format:"%s")

  # Thêm vào log tổng hợp
  update_logs+="$path ($branch): $latest_msg"$'\n'

  # Quay lại thư mục gốc của repo chính
  cd - > /dev/null
done

# Nếu có bất kỳ cập nhật nào từ submodule, thực hiện commit trong repo chính
if [[ -n "$update_logs" ]]; then
  echo "Committing submodule updates to main repository..."

  git add .

  git commit -m "Update submodules on $today:

$update_logs"
  git push origin master
else
  echo "No updates found in submodules."
fi
