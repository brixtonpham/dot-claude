# dot-claude

My `~/.claude` profile — agents, skills, hooks, plugins, and full setup script.

## Setup (One Command)

```bash
curl -sL https://raw.githubusercontent.com/brixtonpham/dot-claude/main/setup.sh | bash
```

Or with git clone:

```bash
git clone https://github.com/brixtonpham/dot-claude ~/.claude && bash ~/.claude/setup.sh
```

Re-sync / update:

```bash
bash ~/.claude/setup.sh
```

The script handles everything:

| Step | What it does |
|------|-------------|
| 1/5 | Clone or sync `~/.claude` from this repo |
| 2/5 | Install [mise](https://mise.jdx.dev) + tools (node, python, go, rust, claude, cli-proxy-api...) |
| 3/5 | Download & install [ProxyPal](https://github.com/heyhuynhgiabuu/proxypal) + proxy config |
| 4/5 | Create `~/.claude.json` (MCP servers) + shell integration |
| 5/5 | Start proxy on port 8317 + open Antigravity login |

## What's Included

### 29 Agents

Specialized sub-agents for the `Task` tool:

`ai-staff` · `brainstormer` · `code-reviewer` · `copywriter` · `cto` · `database-admin` · `debugger` · `devops-architect` · `docs-manager` · `gemini-orchestrator` · `journal-writer` · `learning-guide` · `mcp-manager` · `nodejs-expert` · `planner` · `project-manager` · `python-expert` · `quality-engineer` · `react-next-architect` · `refactoring-expert` · `requirements-analyst` · `researcher` · `scout` · `security-engineer` · `svelte-kit-architect` · `system-architect` · `tester` · `ui-ux-designer` · `apple-platform-architect`

### 30 Skills

Context-aware skills triggered via `/skill-name` or automatically:

`planning` · `research` · `sequential-thinking` · `prompt-architect` · `claude` · `ui-ux-pro-max` · `frontend-development` · `backend-development` · `databases` · `infra-engineer` · `nextjs-turborepo` · `git-workflow` · `code-quality` · `design-principles` · `3d-graphics` · `ai-tools` · `canvas-design` · `chrome-devtools` · `media-processing` · `mobile-development` · `payment-integration` · `shopify` · `playwriter` · `repomix` · `mise-expert` · `docs-discovery` · `github-search` · `browser-history` · `problem-solving`

### 5 Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `session-start` | Session init | Load context & rules |
| `force-agent-skills-eval` | User prompt submit | Enforce delegation protocol |
| `index` | Pre tool use | Route to correct hook handler |
| `npm/pnpm/yarn/bun/cargo/docker` | Pre tool use | Confirm before heavy commands |
| `npm run dev / pnpm run dev` | Pre tool use | Warn about dev server in agent |

### 28 Plugins (Official Marketplace)

Code review · PR review toolkit · Plugin dev · Hookify · Feature dev · Commit commands · Claude Code setup · Claude MD management · Code simplifier · Frontend design · Playground · Ralph loop · Security guidance · Explanatory output · Learning output · LSP integrations (TypeScript, Rust, Go, Python, Swift, Kotlin, Java, C#, C++, Lua, PHP)

### Setup Files

| File | Purpose |
|------|---------|
| `setup/mise-config.toml` | Tool versions (node 22, python 3.11, go, rust, claude, cli-proxy-api...) |
| `setup/proxy-config.yaml` | CLIProxyAPI config (Antigravity, model routing, payload injection) |
| `setup/shell-integration.sh` | PATH fixes, mise shims, claude alias |

## Proxy Configuration

Routes through CLIProxyAPI on `localhost:8317`:

| Setting | Value |
|---------|-------|
| `ANTHROPIC_BASE_URL` | `http://127.0.0.1:8317` |
| `ANTHROPIC_AUTH_TOKEN` | `proxypal-local` |
| Default model | `gemini-claude-opus-4-6-thinking` |

## After Setup

```bash
# Restart terminal, then:
claude
```

## Updating

```bash
bash ~/.claude/setup.sh
```

Or manual pull:

```bash
cd ~/.claude && git pull
```
