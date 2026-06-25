docker ps --format '{{.ID}} {{.Image}}' \
| awk '$2 ~ /^greptileai\// {print $1}' \
| xargs -r docker stop
