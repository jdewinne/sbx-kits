# goose kit (schema v3)

[goose](https://github.com/aaif-goose/goose) as a Docker Sandboxes agent. This is a
`schemaVersion: "3"` **workload** kit: goose is not one of the built-in `sbx` agents,
so the kit ships the whole environment (the `shell-docker` template plus the goose CLI).

```
goose/
  goose.yaml          descriptor (first line: # syntax=docker/sandbox-kit:3)
  goose.dockerfile    content recipe, found by filename stem
```

## Run it

```sh
sbx secret set anthropic          # or openai, google, openrouter
sbx run ./kits/goose .            # from the repo root
```

Pick a different provider or model with `--kit-arg`, bind that provider's secret, and
set a model that provider serves (goose refuses to start without one):

```sh
sbx secret set openai
sbx run ./kits/goose . --kit-arg provider=openai --kit-arg model=<model>
```

| Arg | Default | Sets |
|---|---|---|
| `version` | `1.54.0` | goose release, a build arg |
| `provider` | `anthropic` | `GOOSE_PROVIDER` |
| `model` | `claude-sonnet-5-5` | `GOOSE_MODEL` |
| `mode` | `auto` | `GOOSE_MODE` (`auto`, `approve`, `smart_approve`, `chat`) |

`auto` is goose's own default and is deliberate here: the microVM is the permission
boundary, the same posture the other agent kits take. Use `mode=approve` or
`smart_approve` if you want goose to ask first as well.

## What the kit declares

- **Network (runtime)**: Anthropic, OpenAI, Google Gemini and OpenRouter API hosts, GitHub,
  npm and PyPI (for `npx`/`uvx` MCP extensions), and the template's apt sources.
- **Credentials**: four optional, proxy-managed API keys. goose reads each from the
  provider's own env var, which holds a sentinel, and the proxy swaps in the real key.
  Auth shapes follow goose's provider code: Anthropic `x-api-key`, Google `x-goog-api-key`,
  OpenAI and OpenRouter `Bearer`. No GitHub credential is declared.
- **Lifecycle**: the install hook seeds `~/.config/goose/config.yaml` from the args. The
  startup hook registers the sandbox MCP gateway as a `streamable_http` goose extension,
  once, only when `MCP_GATEWAY_URL` is set.
- **Sessions**: `goose run --text=…` for headless prompts, `goose session --resume` for
  continue and resume, and a `list` built from `goose session list --format json`.
- **Skills and context**: skills at `~/.agents/skills`. Guidance is a lifecycle file at
  `~/.config/goose/.goosehints`, not `agent-context@1`: that capability's `directory` field
  is rejected by the v3 reader in `sbx` 0.47 ("unknown field `directory`").

## Updating goose

The release publishes no checksum file, so `goose.dockerfile` pins the SHA-256 of both
Linux GNU tarballs for the default version. Bumping `version` without updating them fails
the build on purpose. For a new release:

```sh
V=1.55.0
for a in x86_64 aarch64; do
  curl -fsSL -o /tmp/goose-$a.tgz \
    https://github.com/aaif-goose/goose/releases/download/v$V/goose-$a-unknown-linux-gnu.tar.gz
  sha256sum /tmp/goose-$a.tgz
done
```

Put the `x86_64` hash in `GOOSE_SHA256_AMD64` and the `aarch64` hash in `GOOSE_SHA256_ARM64`,
and set the `version` default in `goose.yaml`. The release assets carry GitHub build
attestations, which this recipe does not verify.

## Build and verify

`sbx kit validate` and `sbx kit pack` target v2 kits. On a v3 source kit, `validate` fails with
"this load path has no kit builder configured". Source-form v3 builds run in the
`sbx-kit-builder` sandbox, which `sbx kit inspect ./kits/goose` and `sbx run ./kits/goose .`
create on first use (`sbx kit builder status` shows it). To validate without `sbx`:

```sh
cd kits/goose
docker buildx build . -f goose.yaml --output type=cacheonly        # validates the descriptor
docker buildx build . -f goose.yaml -t goose:1.54.0 \
  --output type=oci,dest=/tmp/goose-layout,tar=false
kit-tck validate --layout /tmp/goose-layout 1.54.0
```

Publish with `--platform linux/amd64,linux/arm64 --push` in one invocation, per the
[v3 authoring guide](https://github.com/docker/sandbox-kit-spec/blob/main/skills/create-kit-v3/SKILL.md).

## Limits

- Local stdio MCP servers that goose launches run inside the sandbox. Local stdio servers
  registered with the host `sbx` MCP gateway still run on the host, as for any agent.
- Only the default `anthropic` provider has been exercised here, and only up to goose
  starting and reaching for the API host. Credential injection for the other three
  providers follows goose's source but has not been run end to end.
- There is no `goose-mixin`. The binary is about 300 MB, so adding goose to another
  workload would be a large overlay.
