# Tailscale-MCP-Remote-Ops-Agent
> Secure AI-powered infrastructure management over zero-trust networks

This is a proof-of-concept agent that lets you chat with Claude to execute commands on a remote server via SSH and Tailscale, using MCP. It isn’t production-ready more of a personal POC I hacked together over a few days to explore the AgentOps space.

---
> **Note:** This is an independent proof-of-concept and **not** an official Tailscale product.
---

# The Problem
Managing servers today forces a bad tradeoff: either give AI full shell access which is insane, copy-paste commands manually which is tedious, or build fragile custom integrations. This POC demonstrates a middle path where an AI agent can execute only whitelisted commands over Tailscale’s zero-trust network, letting you manage infrastructure through natural conversation without sacrificing safety.

This POC combines:
* AI agent (Claude with MCP tools)
* Zero-trust overlay (Tailscale)
* Controlled SSH command execution (whitelist + sanitization)

---
## 🧠 How It Works (Claude + MCP + SSH + Tailscale)

1. You talk to Claude via a local **Gradio** chat UI.
2. Claude calls **MCP tools** (e.g., `server_status`, `list_commands`, `execute_command`) exposed by a local MCP server.
3. The MCP server uses an async **SSH client** to run **whitelisted** commands on a Tailscale-reachable host.
4. Results are returned through MCP back to Claude, which explains them in natural language.

Claude never has raw shell access. It can only invoke predefined tools that map to whitelisted commands.


**Example conversation:**

<img width="2546" height="1538" alt="image" src="https://github.com/user-attachments/assets/f1fd9173-5446-4967-bbcf-5680be5cf2a2" />

**Demo Video:**

https://github.com/user-attachments/assets/91cb238b-8e1a-4157-8f60-814d6143c8f0


---

## 🗺️ Architecture

### Local Deployment

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                                 Tailnet                                     │
│                                                                             │
│  ┌──────────────┐         ┌─────────────────────┐         ┌──────────────┐  │
│  │    Local     │ ◄──────►│       Agent         │ ◄──────►│Remote Server │  │
│  │   Browser    │   HTTP  │   (self-hosted)     │   SSH   │              │  │
│  └──────────────┘         │                     │         │ Executes:    │  │
│                           │  - Gradio UI        │         │  df -h       │  │
│                           │  - MCP tools        │         │  free -m     │  │
│                           │  - SSH client       │         │  systemctl   │  │
│                           └──────────┬──────────┘         └──────────────┘  │
│                                      │                                      │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │
                                       │ HTTPS (API call)
                                       ▼
                               ┌──────────────────┐
                               │  Anthropic API   │
                               └──────────────────┘
```

### Docker Deployment

```text
┌────────────────────────────────────────────────────────────────────────────────┐
│                                 Tailnet                                        │
│                                                                                │
│  ┌──────────────┐          ┌───────────────────────────────────────────────┐   │
│  │   Browser    │ ◄───────►│              Docker Host                      │   │
│  └──────────────┘port:7860 │  ┌─────────────┐      ┌─────────────────┐     │   │
│                            │  │  tailscale  │      │    mcp-agent    │     │   │
│                            │  │  (sidecar)  │◄───► │                 │     │   │
│                            │  │             │shared│  - Gradio UI    │     │   │
│                            │  │  - VPN      │ net  │  - Claude API   │     │   │
│                            │  │  - Routes   │      │  - SSH client   │     │   │
│                            │  └─────────────┘      └────────┬────────┘     │   │
│                            └────────────────────────────────┼──────────────┘   │
│                                                             │                  │
│                                                             │ SSH              │
│                                                             ▼                  │
│                                                      ┌──────────────┐          │
│                                                      │Remote Server │          │
│                                                      └──────────────┘          │
└────────────────────────────────────────────────────────────────────────────────┘
```

The Docker setup uses two containers:

* **tailscale**: Sidecar container providing VPN connectivity to your Tailnet.
* **mcp-agent**: Main application container sharing the Tailscale network namespace.

---

## 🚀 Deployment Options

There are **two ways** to run this project:

* Docker Deployment (Recommended)
* Python Virtual Environment


---

<details>
  <summary><h2>Option A: Docker deployment (recommended)</h2></summary>

### 1. Prerequisites

* Docker Engine 20.10+
* Docker Compose v2.0+
* A Tailscale account
* An Anthropic API key
* SSH access to your remote server (over Tailscale, e.g., `100.x.x.x`)

---

### 2. Clone the repo

```bash
git clone git@github.com:e-300/Tailscale-MCP-Remote-Ops-Agent.git
cd Tailscale-MCP-Remote-Ops-Agent
```

---

### 3. Configure environment (.env)

Use the Docker-focused env template:

```bash
mv .env.docker .env
nano .env
```

Set at minimum:

* `ANTHROPIC_API_KEY`
* `REMOTE_HOST` (e.g., `100.x.x.x`)
* `REMOTE_USER`
* `SSH_KEY_PATH` / `SSH_KEY_FILENAME` (for Docker SSH key mounting)
* Either `TS_AUTHKEY` **or** be ready to do manual auth

The `.env` file explains which values are required and which are optional.

---

### 4. Authenticate with Tailscale

You have two options: **automated (auth key)** or **manual interactive**.

#### 4.1 Automated Tailscale authentication (recommended)

1. Generate an auth key at:
   [https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. Add it to `.env`:

   ```env
   TS_AUTHKEY=tskey-auth-xxxxx
   ```

When you run `docker compose up`, the Tailscale container will auto-auth and join your Tailnet.

#### 4.2 Manual Tailscale authentication

```bash
# Start only the Tailscale container
docker compose up -d tailscale

# Trigger interactive auth (one-time)
docker compose exec tailscale tailscale up

# → Follow the URL printed in the terminal, sign in, and approve the node.

# Verify status
docker compose exec tailscale tailscale status
```

Tailscale state is persisted in the container volume until you remove volumes.

---

### 5. Start the agent

```bash
# Start all services (tailscale + mcp-agent)
docker compose up -d

# View agent logs
docker compose logs -f mcp-agent
```

Once started, open: `http://localhost:7860` in your browser.

---

### 6. SSH key setup options (Docker)

#### Option 1: Mount existing keys

Mount your `~/.ssh` directory (default-style setup):

```yaml
volumes:
  - ${SSH_KEY_PATH:-~/.ssh}:/app/ssh-keys:ro
```

In `.env`:

```env
SSH_KEY_PATH=~/.ssh
SSH_KEY_FILENAME=id_ed25519
```

#### Option 2: Use a specific key file

```bash
# Create a dedicated keys directory
mkdir -p ./secrets/ssh

# Copy your key (keep it secure!)
cp ~/.ssh/id_ed25519 ./secrets/ssh/

# Update .env
SSH_KEY_PATH=./secrets/ssh
SSH_KEY_FILENAME=id_ed25519
```

#### Option 3: Docker secrets (Swarm mode)

For production with Docker Swarm:

```yaml
secrets:
  ssh_key:
    file: ./secrets/id_ed25519

services:
  mcp-agent:
    secrets:
      - ssh_key
    environment:
      - REMOTE_SSH_KEY_PATH=/run/secrets/ssh_key
```

---

### 7. Common Docker commands

```bash
# Start all containers
docker compose up -d

# Stop all containers
docker compose down

# View logs
docker compose logs -f
docker compose logs -f mcp-agent

# Rebuild after code changes
docker compose build --no-cache mcp-agent
docker compose up -d mcp-agent

# Check Tailscale status
docker compose exec tailscale tailscale status

# Access agent container shell
docker compose exec mcp-agent bash

# Test SSH connection from inside container
docker compose exec mcp-agent python -c "
import asyncio
from src.config import SSHConfig
from src.ssh_client import test_ssh_connection
config = SSHConfig.from_env()
print(asyncio.run(test_ssh_connection(config)))
"
```

---

### 8. Docker-specific troubleshooting

#### Tailscale won’t connect

```bash
# Check Tailscale logs
docker compose logs tailscale

# Verify TUN device exists
docker compose exec tailscale ls -la /dev/net/tun

# Re-authenticate
docker compose exec tailscale tailscale up --reset
```

#### SSH connection fails

```bash
# Verify key is mounted
docker compose exec mcp-agent ls -la /app/ssh-keys/

# Check permissions
docker compose exec mcp-agent stat /app/ssh-keys/id_ed25519

# Test SSH manually (if openssh-client is installed)
docker compose exec mcp-agent ssh -i /app/ssh-keys/id_ed25519 user@100.x.x.x
```

#### Can’t reach remote server

```bash
# Verify Tailscale is connected
docker compose exec tailscale tailscale status

# Ping remote server
docker compose exec tailscale ping 100.x.x.x

# Check if agent can reach Tailnet
docker compose exec mcp-agent ping 100.x.x.x
```

#### Port 7860 not accessible

```bash
# Check if port is exposed
docker compose ps

# Verify Gradio is running
docker compose logs mcp-agent | grep -i gradio

# Check port binding (container name may differ)
docker port tailscale-mcp 7860
```

---

</details>

<details>
  <summary><h2>Option B: Local Python environment</h2></summary>

### 1. Prerequisites

* Python 3.11+
* `pip` and `venv`
* Tailscale running on:

  * Your local machine
  * The remote server
* Anthropic API key
* SSH access to the remote over Tailscale (e.g., `ssh user@100.x.x.x` works)

---

### 2. Clone and set up environment

```bash
git clone git@github.com:e-300/Tailscale-MCP-Remote-Ops-Agent.git
cd Tailscale-MCP-Remote-Ops-Agent

python3 -m venv venv
source venv/bin/activate       # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

---

### 3. Configure environment (.env)

```bash
cp .env.example .env
nano .env
```

Example values:

```env
ANTHROPIC_API_KEY=sk-ant-your-key
REMOTE_HOST=100.x.x.x
REMOTE_USER=server-username
REMOTE_SSH_KEY_PATH=~/.ssh/id_ed25519
REMOTE_SSH_KEY_PASSPHRASE=optional
REMOTE_SSH_PORT=22
```

Ensure:

* You can SSH into the remote using the key/path you configured.
* Tailscale is connected on both ends (`tailscale status`).

---

### 4. Run the agent

```bash
python3 run.py
```

Then open: `http://localhost:7860` in your browser.

---

### 5. Local Python troubleshooting

**“SSH not configured”**

Ensure these are set in `.env`:

* `REMOTE_HOST`
* `REMOTE_USER`
* `REMOTE_SSH_KEY_PATH`

**“SSH key not found”**

```bash
ls -la ~/.ssh/id_ed25519
```

**“Connection refused”**

1. Verify Tailscale is running: `tailscale status`
2. Check you can ping the remote: `ping 100.x.x.x`
3. Verify SSH is running on remote: `ssh user@100.x.x.x`

**“Command not in whitelist”**

* Add the command to `config/commands.yaml`
* Or use the MCP tool `list_commands` in the UI to see available options.

</details>

---

## 📖 Usage

### Example prompts

Once the agent is running (Docker or local), try:

* **“Check the server status”** – Verifies SSH connectivity
* **“How much disk space is available?”** – Runs `df -h`
* **“Show me the memory usage”** – Runs `free -h`
* **“Give me a system overview”** – Runs multiple commands
* **“What commands can you run?”** – Lists whitelisted commands
* **“Is the docker service running?”** – Checks systemd service
* **“Check the size of /var/log”** – Runs `du -sh /var/log`

### Available MCP tools

| Tool              | Description                          |
| ----------------- | ------------------------------------ |
| `ping`            | Test MCP server connectivity         |
| `server_status`   | Check SSH connection status          |
| `list_commands`   | Show all available commands          |
| `execute_command` | Run a whitelisted command            |
| `check_disk`      | Quick disk space check               |
| `check_memory`    | Quick memory check                   |
| `check_service`   | Check a systemd service              |
| `check_path_size` | Check directory size                 |
| `system_overview` | Get comprehensive system information |

### Whitelisted commands

Commands are organized by category:

* **System:** `hostname`, `uptime`, `whoami`, `uname`, `date`
* **Disk:** `disk_usage`, `disk_usage_path`, `largest_files`
* **Memory:** `memory_usage`, `memory_detailed`
* **Process:** `top_processes`, `top_memory_processes`, `process_count`
* **Network:** `network_interfaces`, `listening_ports`, `routing_table`
* **Services:** `service_status`, `failed_services`, `service_logs`
* **Docker:** `docker_ps`, `docker_stats`, `docker_logs`, `docker_images`

See `config/commands.yaml` for the full list and to add custom commands.

---

## 🔒 Security

### Design principles

1. **Command whitelisting** – Only pre-approved commands can run.
2. **Parameter sanitization** – All inputs are sanitized to prevent injection.
3. **Tailscale encryption** – All traffic between machines is encrypted at the network layer.
4. **No shell access** – Commands run in isolation, not interactive shells.

### Adding custom commands

Edit `config/commands.yaml`:

```yaml
- name: my_custom_command
  description: What this command does (be descriptive for Claude)
  command_template: echo "Hello {name}"
  category: custom
  parameters:
    name: The name to greet
```

### Security audit checklist

Before deploying:

* [ ] Review all commands in `config/commands.yaml`
* [ ] Remove any commands you don’t need
* [ ] Verify SSH key has minimal permissions on the remote server
* [ ] Consider running the agent in a container
* [ ] Enable Tailscale ACLs to restrict access
* [ ] Run `check_setup.py` to verify dependencies are installed correctly

---

## 🏗️ Project Structure

```text
Tailscale-MCP-Remote-Ops-Agent/
├── src/
│   ├── __init__.py        # Package init
│   ├── chat_ui.py         # Gradio chat interface + agentic loop
│   ├── mcp_server.py      # MCP server with tool definitions
│   ├── mcp_client.py      # MCP client for agent
│   ├── ssh_client.py      # SSH command execution
│   └── config.py          # Configuration models
├── config/
│   └── commands.yaml      # Whitelisted commands
├── Dockerfile             # Container build
├── docker-compose.yaml    # Multi-container orchestration
├── .env.example           # Environment template (local)
├── .env.docker            # Environment template (Docker)
├── requirements.txt
├── check_setup.py         # Environment / dependency checks
├── run.py                 # Startup script
└── README.md
```

---

## 🛠️ Development Status

* [x] **Phase 1:** Foundation – Basic Gradio chat with Claude
* [x] **Phase 2:** MCP server – Define tools with MCP
* [x] **Phase 3:** SSH connection – Remote command execution
* [x] **Phase 4:** Tool definitions – Whitelisted commands
* [x] **Phase 5:** MCP client – Agent talks MCP
* [x] **Phase 6:** Full integration – End-to-end flow
* [x] **Phase 7:** Configuration – User-friendly setup
* [x] **Phase 8:** Security – Hardening and audit
* [x] **Phase 9:** Docker containerization
* [x] **Phase 10:** Polish – Documentation and UX

---

## 🧹 Cleanup

```bash
# Stop and remove containers
docker compose down

# Also remove volumes (WARNING: loses Tailscale auth state)
docker compose down -v

# Remove built images
docker compose down --rmi local
```

---

## 📄 License

MIT

---

## 🙏 Acknowledgments

* [Anthropic](https://anthropic.com) for Claude
* [Tailscale](https://tailscale.com) for secure networking
* [Model Context Protocol](https://modelcontextprotocol.io) for the tool framework
* [Gradio](https://gradio.app) for the UI
