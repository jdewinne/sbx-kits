# syntax=docker/dockerfile:1
# goose as a WORKLOAD: the shell-docker template (platform floor: bash, the
# agent user at uid 1000, git, curl, jq, a CA store) plus the official goose
# CLI release, pinned and checksum-verified at build.
FROM dhi.io/sbx-templates:shell-docker

# Supplied by the frontend from the descriptor's `version` arg (buildArg) --
# no default here, so the descriptor is the single source of the version.
ARG GOOSE_VERSION
ARG TARGETARCH

# SHA-256 of goose-<arch>-unknown-linux-gnu.tar.gz for the default version.
# The release publishes no checksum file, so these were computed from the
# official release assets. Bumping `version` without updating these fails
# the build on purpose: a pin is a claim about content.
ARG GOOSE_SHA256_AMD64=ab396c95aebbd28b4d38c175234be8d4a3ea0c96e7ccb24c307e4618c9be57e1
ARG GOOSE_SHA256_ARM64=0f174b5118a53888cd4e65b7ca9a4b72dd0b887e89142c8ce41e2409205e40d5

USER root
RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) arch=x86_64;  sha="${GOOSE_SHA256_AMD64}" ;; \
      arm64) arch=aarch64; sha="${GOOSE_SHA256_ARM64}" ;; \
      *) echo "unsupported TARGETARCH: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    tarball="goose-${arch}-unknown-linux-gnu.tar.gz"; \
    curl -fsSL -o "/tmp/${tarball}" \
      "https://github.com/aaif-goose/goose/releases/download/v${GOOSE_VERSION}/${tarball}"; \
    echo "${sha}  /tmp/${tarball}" | sha256sum -c -; \
    tar -xzf "/tmp/${tarball}" --no-same-owner -C /usr/local/bin ./goose; \
    rm -f "/tmp/${tarball}"; \
    chown root:root /usr/local/bin/goose; \
    chmod 0755 /usr/local/bin/goose; \
    # The pin is a claim about content: make the build enforce it. This
    # step runs as root with HOME=/home/agent, so point goose's state at a
    # throwaway dir: otherwise it leaves a root-owned ~/.local/state/goose
    # behind and goose panics creating its log file as the agent user.
    state="$(mktemp -d)"; \
    GOOSE_PATH_ROOT="${state}" goose --version | grep -q "${GOOSE_VERSION}"; \
    rm -rf "${state}"

# No keyring daemon in the sandbox. Provider keys arrive as proxy-managed
# sentinels in the provider's own env var (ANTHROPIC_API_KEY, ...), which
# goose reads ahead of any stored secret.
ENV GOOSE_DISABLE_KEYRING=1

USER agent
WORKDIR /home/agent/workspace
# The sandbox is the permission boundary, so goose runs in its default
# `auto` mode (the descriptor's `mode` arg can tighten it).
ENTRYPOINT ["goose"]
