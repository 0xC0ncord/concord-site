#!/usr/bin/env bash

set -Eeuo pipefail

POSTS_PATH="content/posts/"
POSTS=( $(find "${POSTS_PATH}" -type f -name '*.md') )

find_drafts() {
    for p in ${POSTS[@]}; do
        [[ -n "$(sed -n '/^---/{n;:s;/^draft:[[:space:]]\+true/{p;q};n;bs}' "${p}")" ]] && echo "${p#${POSTS_PATH}}"
    done
    return 0
}

DRAFTS=( $(find_drafts) )
[[ ${#DRAFTS[@]} -eq 0 ]] && echo "There are no posts marked as drafts." && exit 1

PS3="Publish which post? (Ctrl-C cancels) "
select opt in "${DRAFTS[@]}"
do
    if [[ -f "${POSTS_PATH}"/"${opt}" ]]; then
        sed "/^---/{n;:s;s/^\(draft:[[:space:]]\)true/publishDate: $(date +%Y-%m-%dT%I:%M:%S%:z)\n\1false/;n;Ts;q}" "${POSTS_PATH}"/"${opt}"
        break
    else
        echo "Invalid choice ${REPLY}"
    fi
done
