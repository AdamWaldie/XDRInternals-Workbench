# Using XDRInternals from Claude Chat and Cowork

Claude can't sign in to Defender itself. You sign in with PowerShell 7 and save the session, and Claude uses that saved session. There are two ways to connect Claude to it. Both go through `tools/agent/Invoke-XdrAgent.ps1`, which keeps investigations read-only unless you approve an action, checks the tenant on every call, and returns JSON.

| Route | Where the queries run | Use it when |
| --- | --- | --- |
| **MCP server** | On your machine, started by Claude Desktop | Chat or Cowork, any time. Most reliable. |
| **Folder access** | Inside Cowork's sandbox, using this repo folder | You give Cowork the repo folder and let it set itself up. |

## Requirements (both routes)

You need PowerShell 7.3 or later (`pwsh`) on the machine where you sign in. The module doesn't load in Windows PowerShell 5.1:

- `Export-XdrAzureDataExplorer` uses a `clean {}` block, which needs PowerShell 7.3. On older versions the whole module fails to parse.
- The device, user and Cloud Apps timeline cmdlets use `ForEach-Object -Parallel`, which needs PowerShell 7.0.

```powershell
winget install Microsoft.PowerShell
```

## Sign in and save the session

In `pwsh`, from the repo root:

```powershell
Import-Module ./XDRInternals/XDRInternals.psd1
Connect-XdrByBrowser -Username 'you@customer.com'   # or Connect-XdrByBrowserExtension, Connect-XdrBySSO, ...
./tools/agent/Save-XdrAgentSession.ps1              # MCP route
./tools/agent/Save-XdrAgentSession.ps1 -InRepo      # folder route: saves to .xdr-agent/ in this folder
```

The script prints the tenant it saved. Check that it's the customer you mean.

- **Expiry:** the saved session expires for Claude after 12 hours.
- **Switching customer:** sign in again and save again.
- **Clearing:** when you're done, run `./tools/agent/Save-XdrAgentSession.ps1 -Clear`, plus `-InRepo` if you used the folder route.
- **Privacy:** `.xdr-agent/` and `investigations/` are git-ignored and docker-ignored.

## Route 1: MCP server

1. Add the server to Claude Desktop's config. Open the file from **Settings → Developer → Edit Config**; the Microsoft Store install keeps it at `%LOCALAPPDATA%\Packages\Claude_<id>\LocalCache\Roaming\Claude\claude_desktop_config.json`. Add this entry:

   ```json
   {
     "mcpServers": {
       "xdrinternals": {
         "command": "node",
         "args": ["C:\\path\\to\\XDRInternals-Workbench\\tools\\mcp\\xdr-mcp-server.mjs"]
       }
     }
   }
   ```

   Optional `env` settings:
   - `XDR_PWSH`: full path to `pwsh.exe`.
   - `XDR_SESSION_PATH`: where the session file is.
   - `XDR_INVESTIGATIONS_DIR`: where evidence goes.
   - `XDR_TIMEOUT_SECONDS`: per-call time limit (default 600).
2. Quit Claude Desktop fully (system tray → Quit) and reopen it.
3. In a chat, the tools menu should list **xdrinternals** with these tools: `xdr_session_status`, `xdr_run`, `xdr_hunt`, `xdr_read_evidence` and `xdr_response_action`.
4. Recommended: set `xdr_response_action` to **ask every time** in the tool permissions. It's the only tool that changes tenant state.

Node.js is the only dependency; the server has no npm packages.

## Route 2: Cowork with folder access

1. Save the session with `-InRepo` (above).
2. Start a Cowork task, give it this repo folder, and ask something like: *"Set up XDRInternals from this folder and triage incident 12345."*
3. Cowork runs `bash tools/agent/setup.sh`. The script:
   - installs PowerShell 7 for its sandbox user if missing
   - loads the module
   - finds the in-repo session
   - checks whether `security.microsoft.com` is reachable

   If the sandbox can't reach `security.microsoft.com`, this route can't work there. Use the MCP route instead.

## The skill

Upload `dist/xdrinternals-skill.zip` in Claude under **Settings → Capabilities → Skills**. Build the zip with `./claude-desktop/build-skill.ps1`. The skill tells Claude:

- which route to use
- to confirm the tenant first
- to stay read-only unless you approve an action
- where to keep evidence
- how to report

Claude Code uses its own copy in `.claude/skills/xdrinternals`, plus the `xdr-investigator` agent.
