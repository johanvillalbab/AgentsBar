import AgentsBarCore
import Foundation

extension AgentsBarCLI {
    static func cardsHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar cards [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                        [--provider \(ProviderHelp.list)]
                        [--account <label>] [--account-index <index>] [--all-accounts]
                        [--no-credits] [--no-color] [--status] [--source <auto|web|cli|oauth|api>]
                        [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]
                        [--brief]

        Description:
          Print a one-shot usage snapshot as a responsive card grid in the terminal.
          Honors enabled providers from config and reuses the same fetch flags as agentsbar usage.
          Failed providers are summarized in a footer instead of error cards.
          Enabled claude-swap lists with 2+ accounts—or one account when `claudeSwapShowSingleAccount`
          is enabled—replace Claude cards unless an account or explicit non-auto `--source` CLI flag is selected.
          Sentinel accounts remain visible without metrics; claude-swap adapter failures use a separate footer entry.
          Use --brief for a compact table layout (Provider / Usage / Reset).
          Stdout is always the rendered card/table text; --json-output only affects stderr logs.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          agentsbar cards
          agentsbar cards --provider codex
          agentsbar cards --provider all --status
          agentsbar cards --brief
          agentsbar cards --no-color
        """
    }

    static func usageHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar usage [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--account <label>] [--account-index <index>] [--all-accounts]
                       [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                       [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]

        Description:
          Print usage from enabled providers as text (default) or JSON. Honors your in-app toggles.
          Output format: use --json (or --format json) for JSON on stdout; use --json-output for JSON logs on stderr.
          Source behavior is provider-specific:
          - Codex: OpenAI web dashboard (usage limits, credits remaining, code review remaining, usage breakdown).
            Auto falls back to Codex CLI only when cookies are missing.
          - Claude: claude.ai API.
            Auto falls back to Claude CLI only when cookies are missing.
          - Kilo: app.kilo.ai API.
            Auto falls back to Kilo CLI when API credentials are missing or unauthorized.
          Token accounts are loaded from the resolved AgentsBar config file.
          Use --account or --account-index to select a specific token account.
          Use --all-accounts to fetch every token account, or every visible Codex account for Codex.
          Account selection requires a single provider.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          agentsbar usage
          agentsbar usage --provider claude
          agentsbar usage --provider gemini
          agentsbar usage --format json --provider all --pretty
          agentsbar usage --provider all --json
          agentsbar usage --status
          agentsbar usage --provider codex --source web --format json --pretty
        """
    }

    static func costHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--no-color] [--pretty] [--refresh] [--days <days>] [--group-by project]

        Description:
          Print local token cost usage from Claude/Codex native logs plus supported pi and OMP sessions.
          This does not require web or CLI access and uses cached scan results unless --refresh is provided.

        Examples:
          agentsbar cost
          agentsbar cost --provider codex --group-by project
          agentsbar cost --provider claude --format json --pretty
        """
    }

    static func sessionsHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar sessions [--json] [--pretty]
          agentsbar sessions focus <id>

        Description:
          List live local Codex and Claude Code agent sessions.
          JSON uses stable AgentSession field names and ISO-8601 dates.
          Focus activates the owning terminal or desktop app on macOS.

        Examples:
          agentsbar sessions
          agentsbar sessions --json
          agentsbar sessions focus 019f3497-73bf-7df3-a173-4f67d968914a
        """
    }

    static func serveHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar serve [--host <host>] [--port <port>] [--refresh-interval <seconds>]
                         [--request-timeout <seconds>]
                         [--dashboard-token <token>] [--allow-plain-http]
                         [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                         [-v|--verbose]

        Description:
          Start a foreground HTTP server that exposes existing CLI JSON payloads and a
          token-gated dashboard snapshot. The server binds to 127.0.0.1 by default;
          `localhost` is normalized to 127.0.0.1.
          GET /dashboard/v1/snapshot requires "Authorization: Bearer YOUR_TOKEN" and fails
          closed (401) when no token is configured. Set the token with --dashboard-token or,
          preferably, the AGENTSBAR_DASHBOARD_TOKEN environment variable (argv leaks via ps).
          Transport is plain HTTP: the token crosses the network in cleartext on every
          request. A non-loopback --host therefore requires both a dashboard token and
          --allow-plain-http, which records that you accept that trade-off. On a
          non-loopback host the token also gates /usage and /cost (account data);
          /health is always open. Use a TLS-terminating reverse proxy for anything
          beyond a trusted network segment.

        Endpoints:
          GET /health
          GET /usage
          GET /usage?provider=claude
          GET /usage?provider=all
          GET /cost
          GET /cost?provider=codex
          GET /dashboard/v1/snapshot

        Examples:
          agentsbar serve
          agentsbar serve --port 8080 --refresh-interval 60 --request-timeout 30
          AGENTSBAR_DASHBOARD_TOKEN=YOUR_TOKEN agentsbar serve
          AGENTSBAR_DASHBOARD_TOKEN=... agentsbar serve --host 0.0.0.0 --allow-plain-http
          curl http://127.0.0.1:8080/usage?provider=all
          curl -H "Authorization: Bearer $AGENTSBAR_DASHBOARD_TOKEN" \\
            http://127.0.0.1:8080/dashboard/v1/snapshot
        """
    }

    static func configHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar config validate [--format text|json]
                                 [--json]
                                 [--json-only]
                                 [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                 [-v|--verbose]
                                 [--pretty]
          agentsbar config dump [--format text|json]
                             [--json]
                             [--json-only]
                             [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                             [-v|--verbose]
                             [--pretty]
          agentsbar config providers [--format text|json] [--json] [--json-only] [--pretty]
          agentsbar config enable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          agentsbar config disable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          agentsbar config set-api-key --provider <name> (--api-key <key>|--stdin)
                                    [--label <label>] [--usage-scope team]
                                    [--organization-id <org>] [--workspace-id <project>]
                                    [--no-enable]
                                    [--format text|json] [--json] [--json-only] [--pretty]

        Description:
          Validate or print the AgentsBar config file (default: validate).
          providers lists persistent provider enablement.
          enable/disable updates the same provider toggle used by Settings.
          set-api-key stores a provider API key in the resolved config file and enables that provider by default.
          For z.ai team usage, add --usage-scope team with BigModel organization and project IDs; this stores
          the key as a token account instead of a provider-level personal key.

        Examples:
          agentsbar config validate --format json --pretty
          agentsbar config dump --pretty
          agentsbar config providers
          agentsbar config enable --provider grok
          agentsbar config disable --provider cursor
          printf '%s' "$ELEVENLABS_API_KEY" | agentsbar config set-api-key --provider elevenlabs --stdin
          printf '%s' "$Z_AI_API_KEY" | agentsbar config set-api-key --provider zai --stdin \\
            --label Team --usage-scope team --organization-id org_... --workspace-id proj_...
        """
    }

    static func cacheHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar cache clear <--cookies|--cost|--all>
                              [--provider <name>]
                              [--format text|json]
                              [--json]
                              [--json-only]
                              [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                              [-v|--verbose]
                              [--pretty]

        Description:
          Clear cached data. Use --cookies to clear browser cookie caches (stored in Keychain),
          --cost to clear cost usage scan caches, or --all for both.
          Optionally specify --provider with --cookies to clear cookies for a single provider only.

        Examples:
          agentsbar cache clear --cookies
          agentsbar cache clear --cookies --provider claude
          agentsbar cache clear --cost
          agentsbar cache clear --all
          agentsbar cache clear --all --format json --pretty
        """
    }

    static func hooksHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar hooks list [--format text|json] [--pretty]
          agentsbar hooks enable
          agentsbar hooks disable
          agentsbar hooks test <event> --provider <name>

        Description:
          Run external commands when quota/provider events occur. Rules are stored in the
          shared config file and are disabled by default. Events:
          quota_low, quota_reached, quota_reset, provider_unavailable, provider_recovered,
          refresh_failed.

          Commands run directly (no shell), receive event metadata via AGENTSBAR_* environment
          variables and a JSON payload on stdin, and are timed out. Only configure commands you trust.

        Examples:
          agentsbar hooks list
          agentsbar hooks enable
          agentsbar hooks test quota_reached --provider codex
          agentsbar hooks test quota_low --provider claude
        """
    }

    static func diagnoseHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar diagnose --provider <name|all> --format json
                           [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                           [-v|--verbose]
                           [--redact] [--output <path>]
                           [--pretty]

        Description:
          Run provider diagnostic fetches and print a safe JSON export for issue reporting.
          The export is redacted and omits raw API tokens, cookies, auth headers, emails,
          account IDs, org IDs, raw responses, and billing-history records.

        Examples:
          agentsbar diagnose --provider minimax --format json --redact --output diagnostic.json
          agentsbar diagnose --provider minimax --format json --pretty
          agentsbar diagnose --provider claude --format json --pretty
          agentsbar diagnose --provider all --format json
        """
    }

    static func cookieHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar cookie refresh <--provider <name>|--all>
                                 [--allow-keychain-prompt]
                                 [--format text|json]
                                 [--json]
                                 [--json-only]
                                 [--pretty]

        Description:
          Re-import browser cookies using each provider's configured browser order.
          Providers that may decrypt Chromium cookies fail before clearing the cache
          unless --allow-keychain-prompt explicitly acknowledges a possible macOS
          Keychain prompt. A prior denial keeps its six-hour cooldown unless that
          explicit interactive retry flag is supplied. Cookie values are never shown.

        Examples:
          agentsbar cookie refresh --provider opencodego --allow-keychain-prompt
          agentsbar cookie refresh --all --allow-keychain-prompt
          agentsbar cookie refresh --provider opencodego --allow-keychain-prompt --format json --pretty
        """
    }

    static func guardHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar guard --provider \(ProviderHelp.list)
                        [--min-remaining <percent>] [--window session|weekly]
                        [--timeout <seconds>] [--json] [--pretty] [--fail-open]
                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]

        Description:
          Exit non-zero when a provider lacks quota headroom, for use in gating scripts.
          Stable guard exit codes: 0 = safe (relevant window has at least --min-remaining% remaining),
                                   1 = insufficient quota, 64 = invalid arguments,
                                   69 = quota unavailable or fetch timed out.
          --min-remaining defaults to 10 (percent). --window defaults to session (the primary window);
          weekly checks the secondary window. --timeout accepts 0...86400 and defaults to 60 seconds;
          0 disables the guard-level deadline, but provider-specific timeouts still apply.
          --fail-open exits 0 instead of 69 when quota is unavailable.
          Human output is a single line to stdout; --json emits a machine-readable decision object.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          agentsbar guard --provider claude
          agentsbar guard --provider codex --min-remaining 20
          agentsbar guard --provider claude --window weekly --min-remaining 5
          agentsbar guard --provider claude --json
          agentsbar guard --provider codex --fail-open
        """
    }

    static func rootHelp(version: String) -> String {
        """
        AgentsBar \(version)

        Usage:
          agentsbar [--format text|json]
                  [--json]
                  [--json-only]
                  [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                  [--provider \(ProviderHelp.list)]
                  [--account <label>] [--account-index <index>] [--all-accounts]
                  [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                  [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]
          agentsbar cards [--provider \(ProviderHelp.list)] [--brief] [--no-color] [--status]
          agentsbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)] [--no-color] [--pretty] [--refresh]
                       [--days <days>] [--group-by project]
          agentsbar sessions [--json] [--pretty]
          agentsbar sessions focus <id>
          agentsbar serve [--host <host>] [--port <port>] [--refresh-interval <seconds>]
                       [--request-timeout <seconds>]
                       [--dashboard-token <token>] [--allow-plain-http]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
          agentsbar config <validate|dump|providers> [--format text|json]
                                        [--json]
                                        [--json-only]
                                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                        [-v|--verbose]
                                        [--pretty]
          agentsbar config enable --provider <name>
          agentsbar config disable --provider <name>
          agentsbar config set-api-key --provider <name> (--api-key <key>|--stdin)
          agentsbar config set-api-key --provider zai --stdin --usage-scope team
                                   --organization-id <org> --workspace-id <project>
          agentsbar hooks <list|enable|disable> [--format text|json] [--pretty]
          agentsbar hooks test <event> --provider <name>
          agentsbar cache clear <--cookies|--cost|--all> [--provider <name>]
          agentsbar cookie refresh <--provider <name>|--all> [--allow-keychain-prompt]
          agentsbar diagnose --provider <name|all> --format json [--redact] [--output <path>] [--pretty]
          agentsbar guard --provider <name> [--min-remaining <percent>] [--window session|weekly] [--json]

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          agentsbar
          agentsbar --format json --provider all --pretty
          agentsbar --provider all --json
          agentsbar --provider gemini
          agentsbar cards --provider all --status
          agentsbar cards --brief
          agentsbar cost --provider claude --format json --pretty
          agentsbar sessions --json
          agentsbar serve --port 8080
          agentsbar config validate --format json --pretty
          agentsbar config enable --provider grok
          agentsbar config set-api-key --provider elevenlabs --stdin
          agentsbar hooks test quota_reached --provider codex
          agentsbar cache clear --cookies
          agentsbar cookie refresh --provider opencodego --allow-keychain-prompt
          agentsbar diagnose --provider minimax --format json --redact --output diagnostic.json
          agentsbar diagnose --provider minimax --format json --pretty
          agentsbar diagnose --provider all --format json
          agentsbar guard --provider claude --min-remaining 20
        """
    }
}
