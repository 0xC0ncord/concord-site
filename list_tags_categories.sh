#!/bin/sh

pushd $(dirname $0) >/dev/null

echo "All tags:"
echo "---------"
find content/posts/ -type f -name '*.md' -exec sed -n '/tags/{:s;n;/^-[[:space:]]/{s/^-[[:space:]]\+\(.*\)/\1/p;bs}}' {} \; | sort | uniq
echo
echo "All categories:"
echo "---------------"
find content/posts/ -type f -name '*.md' -exec sed -n '/categories/{:s;n;/^-[[:space:]]/{s/^-[[:space:]]\+\(.*\)/\1/p;bs}}' {} \; | sort | uniq

popd >/dev/null
