# Eneo 2.3.2 with per-user MCP OAuth (PR #1119)

Branch `v2.3.2-mcp-oauth` of this fork is upstream Eneo
[v2.3.2](https://github.com/eneo-ai/eneo/releases/tag/v2.3.2) with draft PR
[eneo-ai/eneo#1119](https://github.com/eneo-ai/eneo/pull/1119)
("Eneo as an OAuth 2.1 client toward MCP servers") added on top. It exists so
the PR can run on a stable release until upstream ships it. It is not an
upstream release and has no support from the Eneo project.

## What is on the branch

1. Upstream tag `v2.3.2` (d6ef812).
2. The PR's 20 commits, `15ae72b..ed61d39`, cherry-picked unchanged. The PR is
   based on `develop`; a merge would also have brought in four `develop` commits
   that v2.3.2 already has as backports, so the commits are cherry-picked
   instead. Git merged the shared files (translations, three chat components)
   without conflicts.
3. One fix: `backend/alembic/versions/202610191100_mcp_oauth_client.py` now
   follows v2.3.2's last migration (`202610261200`) instead of `202610191000`.
   Without it, the migrations have two heads.
4. This folder.

`frontend/apps/web-next` gets only regenerated API types from the PR, so its
image isn't built here; use upstream's v2.3.2 one if you need it.

## Images

`mabadiliko/build.sh` builds them with podman, and by default pushes:

| Image | Tag |
|---|---|
| `ghcr.io/mabadiliko/eneo-backend` | `v2.3.2-pr1119-ed61d39` |
| `ghcr.io/mabadiliko/eneo-frontend` | `v2.3.2-pr1119-ed61d39` |
| `ghcr.io/mabadiliko/eneo-tool-runtime` | `v2.3.2-pr1119-ed61d39` |

The app reports version `2.3.2`; the revision label and `APP_REVISION` hold
the branch commit. The tool runtime has no changes, but it is built from the
same commit because the backend warns when the runtime's version or revision
differs from its own. Other images (e.g. seaweedfs) are upstream's v2.3.2.

In upstream's `docs/deployment/docker-compose.yml`, set `ENEO_BACKEND_IMAGE`,
`ENEO_FRONTEND_IMAGE` and `ENEO_TOOL_RUNTIME_IMAGE` to these.

## Database

The PR adds two migrations (`202610191100`, `202610191200`). A database
migrated by this build is ahead of plain v2.3.2: going back means
`alembic downgrade 202610261200` first. A database migrated by a build of the
PR branch itself (based on `develop`) may hold revisions that v2.3.2 doesn't
know; start such a test from a fresh database.

## Updating

When the PR gets new commits, cherry-pick them onto this branch, change
`PR_HEAD` in `build.sh`, and build again. When upstream ships the feature in a
release, use that release and retire this branch.
