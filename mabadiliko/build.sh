#!/bin/bash
# Build the Eneo images of this fork branch with podman and push them to
# ghcr.io/mabadiliko. See README.md next to this file.
#
# Usage: mabadiliko/build.sh [--no-push] [ref]
#   ref        commit to build (default: v2.3.2-mcp-oauth). Only committed
#              content is built, taken with `git archive`.
#   --no-push  build only; leave the images on the build host.
#
# By default it builds from this clone on this machine. To build on another
# machine (the frontend build wants an 8 GB Node heap), set BUILD_HOST to an
# ssh host and REPO_DIR to the path of a clone of this fork there. To push,
# the local gh token is handed to a podman login on the build machine that
# lives only as long as the build directory; the token needs the
# write:packages scope (`gh auth refresh -s write:packages`).
#
# Eneo's Dockerfiles use short image names (python:…, node:…, oven/bun), which
# podman refuses without a TTY; a registries.conf that resolves them to
# docker.io is passed to the build instead of patching Eneo's files.
set -euo pipefail

PUSH=1
if [[ ${1:-} == --no-push ]]; then PUSH=0; shift; fi
REF=${1:-v2.3.2-mcp-oauth}

VERSION=2.3.2           # the app version Eneo reports; the base release
PR_HEAD=ed61d39         # head of eneo-ai/eneo#1119 that this branch carries
TAG="v${VERSION}-pr1119-${PR_HEAD}"
REG=ghcr.io/mabadiliko
SOURCE_URL=https://github.com/mabadiliko/eneo
BUILD_HOST=${BUILD_HOST:-}

if [[ -z $BUILD_HOST ]]; then
    REPO_DIR=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
    run() { bash -s; }
else
    : "${REPO_DIR:?set REPO_DIR to the path of the clone on $BUILD_HOST}"
    run() { ssh "$BUILD_HOST" bash -s; }
fi

if (( PUSH )); then
    token=$(gh auth token)
    gh_user=$(gh api user -q .login)
fi

dir=$(run <<<'mktemp -d')
trap 'run <<<"rm -rf $dir"' EXIT

run <<EOF
set -euo pipefail
cd $dir
git -C "$REPO_DIR" archive --prefix=src/ "$REF" | tar -x
rev=\$(git -C "$REPO_DIR" rev-parse "$REF^{commit}")
cat > registries.conf <<'CONF'
unqualified-search-registries = ["docker.io"]
short-name-mode = "permissive"
CONF
export CONTAINERS_REGISTRIES_CONF=\$PWD/registries.conf

# What upstream's release workflow does before building (application_image.yml):
# the backend reads its version from this manifest, the web app from package.json.
(cd src && ./scripts/inject-backend-version.sh $VERSION >/dev/null)
jq --arg v $VERSION '.version = \$v' src/frontend/apps/web/package.json > p.json
mv p.json src/frontend/apps/web/package.json

labels=(--label org.opencontainers.image.source=$SOURCE_URL
        --label org.opencontainers.image.version=$VERSION
        --label org.opencontainers.image.revision=\$rev)
app_args=(--build-arg APP_VERSION=$VERSION --build-arg APP_REVISION=\$rev
          --build-arg OTEL_SERVICE_VERSION=$VERSION)

podman build -q "\${labels[@]}" "\${app_args[@]}" -t $REG/eneo-backend:$TAG src/backend
podman build -q "\${labels[@]}" "\${app_args[@]}" -t $REG/eneo-frontend:$TAG src/frontend
podman build -q "\${labels[@]}" --build-arg VERSION=$VERSION --build-arg GIT_SHA=\$rev \
    --build-arg SOURCE_URL=$SOURCE_URL -t $REG/eneo-tool-runtime:$TAG src/tool-runtime
echo "built $TAG from \$rev"
EOF

if (( PUSH )); then
    run <<EOF
set -euo pipefail
printf '%s' '$token' | podman login -q --authfile $dir/auth.json -u $gh_user --password-stdin ghcr.io
for img in eneo-backend eneo-frontend eneo-tool-runtime; do
    podman push -q --authfile $dir/auth.json --digestfile $dir/digest $REG/\$img:$TAG
    echo "$REG/\$img:$TAG@\$(cat $dir/digest)"
done
EOF
fi
