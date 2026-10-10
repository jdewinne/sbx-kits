This sandbox runs goose, Block's open-source agent (now under the Linux
Foundation's Agentic AI Foundation), inside a Docker Sandboxes microVM.

- The sandbox is the isolation boundary. Outbound network access is limited to
  the model provider you have credentials for, GitHub, and the npm and PyPI
  registries. If a request is blocked, say so rather than working around it.
- Model provider keys are never present in the sandbox. The provider env vars
  hold placeholder values and the host proxy swaps in the real key on outbound
  calls to the provider's API host. Do not try to read, print or "fix" them.
- goose is configured in `~/.config/goose/config.yaml`. The provider is set
  from the kit's `provider` argument. goose does not read API keys from this
  file.
- Local stdio MCP servers (for example `npx`-launched extensions) run inside
  this sandbox, subject to the same network policy.
