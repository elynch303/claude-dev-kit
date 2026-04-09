#Requires -Version 5.1
# scripts/install.ps1 — Claude Dev Kit Installer (Windows / PowerShell)
#
# Called automatically by bin/claude-dev-kit.js when bash is unavailable on Windows.
# Can also be run directly:
#   pwsh  -ExecutionPolicy Bypass -File scripts\install.ps1 [target-dir] [-McpOnly]
#   powershell -ExecutionPolicy Bypass -File scripts\install.ps1

param(
    [Parameter(Position = 0)]
    [string]$TargetDir = '',
    [switch]$McpOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─── Paths ────────────────────────────────────────────────────────────────────
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitRoot     = Split-Path -Parent $ScriptDir
$MergeScript = Join-Path $KitRoot 'scripts' 'lib' 'merge-settings.js'

if ($TargetDir -eq '') { $TargetDir = (Get-Location).Path }
$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)

$CdkClaude = Join-Path $KitRoot '.claude'
$TgtClaude = Join-Path $TargetDir '.claude'
$LogFile   = Join-Path $TgtClaude 'install.log'

# ─── Helpers ──────────────────────────────────────────────────────────────────
function Write-Info($msg)    { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)      { Write-Host "  v $msg"  -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "  ! $msg"  -ForegroundColor Yellow }
function Write-Err($msg)     { Write-Host "  x $msg"  -ForegroundColor Red }
function Write-Header($msg)  { Write-Host "`n$msg"    -ForegroundColor White }
function Write-Dim($msg)     { Write-Host "    $msg"  -ForegroundColor DarkGray }

function Read-YN($prompt) {
    $r = Read-Host "  $prompt [y/N]"
    return ($r -match '^[Yy]$')
}

function Read-Value($prompt, $default = '') {
    if ($default -ne '') {
        $r = Read-Host "  $prompt [$default]"
        if ($r -eq '') { return $default }
        return $r
    }
    return Read-Host "  $prompt"
}

function Read-Menu($prompt, [string[]]$options) {
    Write-Host "  $prompt" -ForegroundColor White
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host "    $($i + 1)) $($options[$i])"
    }
    $choice = Read-Host "  Choice [1-$($options.Count)]"
    $idx = [int]$choice - 1
    if ($idx -ge 0 -and $idx -lt $options.Count) { return $options[$idx] }
    return $options[0]
}

# Compare file contents normalising line endings so LF == CRLF
function Compare-Content($pathA, $pathB) {
    $a = (Get-Content $pathA -Raw) -replace "`r`n", "`n"
    $b = (Get-Content $pathB -Raw) -replace "`r`n", "`n"
    return $a -eq $b
}

# Run node script with path passed via env var to avoid Git Bash path issues
function Invoke-NodeWithPath($envKey, $filePath, $jsCode) {
    [System.Environment]::SetEnvironmentVariable($envKey, $filePath, 'Process')
    $out = node -e $jsCode
    [System.Environment]::SetEnvironmentVariable($envKey, $null, 'Process')
    return $out
}

function Invoke-McpAdd($name, [string[]]$mcpArgs) {
    $output = & claude mcp add @mcpArgs 2>&1
    if (Test-Path (Split-Path $LogFile)) {
        $output | Out-File -FilePath $LogFile -Append -Encoding utf8
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "$name MCP installed"
    } else {
        Write-Warn "$name MCP install failed — see $LogFile for details"
    }
}

$CiMode = ($env:CI -eq 'true')

# ─── Banner ───────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '╔═══════════════════════════════════════╗' -ForegroundColor White
Write-Host '║       Claude Dev Kit — Installer      ║' -ForegroundColor White
Write-Host '╚═══════════════════════════════════════╝' -ForegroundColor White
Write-Host ''

# ─── Phase 1: File Installation ───────────────────────────────────────────────
if (-not $McpOnly) {
    Write-Header 'Phase 1: Install .claude/ into your project'
    Write-Dim "Source: $KitRoot"
    Write-Dim "Target: $TargetDir"
    Write-Host ''

    if (-not $CiMode) {
        if (-not (Read-YN "Install .claude/ into $TargetDir?")) {
            Write-Host 'Aborted.'; exit 0
        }
    }

    New-Item -ItemType Directory -Path $TgtClaude -Force | Out-Null

    # ── Enumerate CDK source files ────────────────────────────────────────────
    $cdkFiles = Get-ChildItem -Path $CdkClaude -Recurse -File | Where-Object {
        $rel = $_.FullName.Substring($CdkClaude.Length + 1).Replace('\', '/')
        $rel -ne 'settings.json' -and
        $rel -ne 'settings.json.example' -and
        $rel -ne '.cdk-manifest' -and
        $rel -notmatch 'node_modules' -and
        $rel -notmatch '\.jsonl$' -and
        $rel -notmatch '^learning/'
    }

    # ── Categorise ────────────────────────────────────────────────────────────
    $catNew       = [System.Collections.Generic.List[string]]::new()
    $catUnchanged = [System.Collections.Generic.List[string]]::new()
    $catModified  = [System.Collections.Generic.List[string]]::new()

    foreach ($src in $cdkFiles) {
        $rel = $src.FullName.Substring($CdkClaude.Length + 1)
        $dst = Join-Path $TgtClaude $rel
        if (-not (Test-Path $dst)) {
            $catNew.Add($rel)
        } elseif (Compare-Content $src.FullName $dst) {
            $catUnchanged.Add($rel)
        } else {
            $catModified.Add($rel)
        }
    }

    $isFreshInstall = -not (Test-Path (Join-Path $TgtClaude '.cdk-manifest'))

    # ── Migration report (skipped on first install) ───────────────────────────
    if (-not $isFreshInstall) {
        Write-Header 'Migration Report'
        Write-Host ''
        Write-Host "  NEW       $($catNew.Count) file(s)   -- will be added"       -ForegroundColor Green
        Write-Host "  UNCHANGED $($catUnchanged.Count) file(s)   -- CDK version matches yours, will refresh" -ForegroundColor Cyan
        if ($catModified.Count -gt 0) {
            Write-Host "  MODIFIED  $($catModified.Count) file(s)   -- differ from CDK, requires your input" -ForegroundColor Yellow
            foreach ($f in $catModified) { Write-Host "    $f" -ForegroundColor Yellow }
        }
        Write-Host ''
    } else {
        Write-Info 'No existing .claude/ found — performing fresh install'
    }

    # ── Copy files ────────────────────────────────────────────────────────────
    $newCount        = 0
    $unchangedCount  = 0
    $modifiedApplied = 0
    $modifiedKept    = 0

    foreach ($src in $cdkFiles) {
        $rel    = $src.FullName.Substring($CdkClaude.Length + 1)
        $dst    = Join-Path $TgtClaude $rel
        $dstDir = Split-Path -Parent $dst

        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }

        if ($catNew.Contains($rel)) {
            Copy-Item $src.FullName $dst
            $newCount++
        } elseif ($catUnchanged.Contains($rel)) {
            Copy-Item $src.FullName $dst
            $unchangedCount++
        } else {
            # Modified file — ask in interactive mode
            if ($CiMode -or $isFreshInstall) {
                Copy-Item $src.FullName $dst
                $modifiedApplied++
            } else {
                Write-Host ''
                Write-Warn "Modified: $rel"
                Write-Dim  'Your version differs from the CDK source.'
                if (Read-YN 'Overwrite with CDK version? (your changes will be lost)') {
                    Copy-Item $src.FullName $dst
                    $modifiedApplied++
                } else {
                    $modifiedKept++
                }
            }
        }
    }

    if ($newCount -gt 0)         { Write-Ok   "$newCount new file(s) added" }
    if ($unchangedCount -gt 0)   { Write-Ok   "$unchangedCount unchanged file(s) refreshed" }
    if ($modifiedApplied -gt 0)  { Write-Ok   "$modifiedApplied modified file(s) updated to CDK version" }
    if ($modifiedKept -gt 0)     { Write-Info "$modifiedKept modified file(s) kept as your version" }

    # ── settings.json ─────────────────────────────────────────────────────────
    $tgtSettings = Join-Path $TgtClaude 'settings.json'
    $cdkSettings = Join-Path $CdkClaude 'settings.json'
    if (-not (Test-Path $cdkSettings)) {
        $cdkSettings = Join-Path $CdkClaude 'settings.json.example'
    }

    if (Test-Path $cdkSettings) {
        if (-not (Test-Path $tgtSettings)) {
            # No existing settings — create from CDK template, stripping internal keys
            $json = Invoke-NodeWithPath 'CDK_SETTINGS_PATH' $cdkSettings `
                'const s=JSON.parse(require("fs").readFileSync(process.env.CDK_SETTINGS_PATH,"utf8")); delete s._comment; delete s._hooks_note; process.stdout.write(JSON.stringify(s,null,2)+"\n");'
            [System.IO.File]::WriteAllText($tgtSettings, $json, [System.Text.UTF8Encoding]::new($false))
            Write-Ok 'settings.json: created from CDK template'
        } else {
            # Merge existing settings with CDK additions
            $tmp = [System.IO.Path]::GetTempFileName()
            try {
                $merged = node $MergeScript $tgtSettings $cdkSettings
                # Validate the merge output is parseable JSON
                $valid = $merged | node -e 'let d=""; process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d);process.exit(0)}catch{process.exit(1)}})' 2>$null
                if ($LASTEXITCODE -eq 0) {
                    [System.IO.File]::WriteAllText($tgtSettings, ($merged -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
                    Write-Ok 'settings.json: merged (permissions + hooks updated)'
                } else {
                    Write-Warn 'settings.json: merge produced invalid JSON — your original preserved'
                    Write-Warn "Manual merge reference: $cdkSettings"
                }
            } finally {
                Remove-Item $tmp -ErrorAction SilentlyContinue
            }
        }
    }

    # ── CLAUDE.md ─────────────────────────────────────────────────────────────
    $tgtMd      = Join-Path $TargetDir 'CLAUDE.md'
    $cdkTemplate = Join-Path $CdkClaude 'templates' 'claude-md-template.md'
    $startMarker = 'CDK:GENERATED:START'
    $endMarker   = 'CDK:GENERATED:END'

    if (Test-Path $cdkTemplate) {
        if (-not (Test-Path $tgtMd)) {
            Copy-Item $cdkTemplate $tgtMd
            Write-Ok 'CLAUDE.md: created from template'
        } else {
            $existing = Get-Content $tgtMd -Raw
            $template  = Get-Content $cdkTemplate -Raw

            # Extract CDK block from template (lines between markers, inclusive)
            if ($template -match "(?s)(<!-- $startMarker.*?<!-- $endMarker -->)") {
                $cdkBlock = $Matches[1]

                if ($existing -match [regex]::Escape("<!-- $startMarker")) {
                    # Replace existing CDK block in-place
                    $updated = $existing -replace "(?s)<!-- $([regex]::Escape($startMarker)).*?<!-- $([regex]::Escape($endMarker)) -->", $cdkBlock
                    [System.IO.File]::WriteAllText($tgtMd, $updated, [System.Text.UTF8Encoding]::new($false))
                    Write-Ok 'CLAUDE.md: CDK block updated (your custom content preserved)'
                } else {
                    # Append CDK block at end
                    $append = "`n---`n`n$cdkBlock"
                    [System.IO.File]::AppendAllText($tgtMd, $append, [System.Text.UTF8Encoding]::new($false))
                    Write-Ok 'CLAUDE.md: CDK block appended (your existing content preserved)'
                    Write-Info 'Tip: you can move the appended block — the markers let future migrations update it in place'
                }
            }
        }
    }

    # ── .gitignore ────────────────────────────────────────────────────────────
    $gitignore = Join-Path $TargetDir '.gitignore'
    $marker    = '# Claude Dev Kit — managed entries'
    $hasMarker = (Test-Path $gitignore) -and ((Get-Content $gitignore -Raw) -match [regex]::Escape($marker))

    if ($hasMarker) {
        Write-Info '.gitignore already contains CDK entries — skipping'
    } else {
        $entries = @(
            '',
            '# Claude Dev Kit — managed entries',
            '# settings.json may contain MCP API tokens written by install.ps1 — never commit it.',
            '.claude/settings.json',
            '# Audit log, install log, and migration manifest contain local paths — no need to track.',
            '.claude/audit.log',
            '.claude/install.log',
            '.claude/.cdk-manifest',
            '# Personal Claude overrides — machine-local, never shared with teammates.',
            'CLAUDE.local.md'
        ) -join "`n"
        [System.IO.File]::AppendAllText($gitignore, $entries, [System.Text.UTF8Encoding]::new($false))
        Write-Ok '.gitignore updated'
    }

    # ── CLAUDE.local.md.example ───────────────────────────────────────────────
    $exSrc  = Join-Path $KitRoot 'CLAUDE.local.md.example'
    $exDest = Join-Path $TargetDir 'CLAUDE.local.md.example'
    if ((Test-Path $exSrc) -and -not (Test-Path $exDest)) {
        Copy-Item $exSrc $exDest
        Write-Info 'CLAUDE.local.md.example added — copy to CLAUDE.local.md for personal preferences'
    }

    # ── Hook dependencies ─────────────────────────────────────────────────────
    New-Item -ItemType Directory -Path $TgtClaude -Force | Out-Null
    if (-not (Test-Path $LogFile)) {
        [System.IO.File]::WriteAllText($LogFile, '', [System.Text.UTF8Encoding]::new($false))
    }

    $hookDir = Join-Path $TgtClaude 'hooks' 'skill-activation-prompt'
    if (Test-Path (Join-Path $hookDir 'package.json')) {
        Write-Info 'Installing skill-activation-prompt hook dependencies...'
        Push-Location $hookDir
        try {
            if (Get-Command bun -ErrorAction SilentlyContinue) {
                bun install --silent >> $LogFile 2>&1
            } elseif (Get-Command npm -ErrorAction SilentlyContinue) {
                npm install --silent >> $LogFile 2>&1
            } else {
                Write-Warn "Neither bun nor npm found. Run manually: cd `"$hookDir`" && npm install"
            }
            Write-Ok 'Hook dependencies installed'
        } finally {
            Pop-Location
        }
    }

    # ── Write manifest ────────────────────────────────────────────────────────
    $manifestLines = @('# CDK Manifest — generated by scripts/install.ps1')
    $manifestLines += '# Lists all files installed by claude-dev-kit.'
    $manifestLines += '# Do not edit manually. Used to distinguish CDK-owned from user-created files.'
    $manifestLines += '#'
    foreach ($src in $cdkFiles) {
        $manifestLines += $src.FullName.Substring($CdkClaude.Length + 1).Replace('\', '/')
    }
    $manifest = Join-Path $TgtClaude '.cdk-manifest'
    [System.IO.File]::WriteAllText($manifest, ($manifestLines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
    Write-Ok 'Manifest written (.claude/.cdk-manifest — tracks CDK-owned files for future migrations)'
}

# ─── Phase 2: MCP Wizard ──────────────────────────────────────────────────────
Write-Host ''
Write-Header 'Phase 2: Configure Claude MCP integrations'
Write-Dim 'MCPs extend Claude with tools for your Git platform, ticket system, and design tools.'
Write-Host ''

if ($CiMode) {
    Write-Info 'CI mode detected — skipping MCP setup'
    Write-Host ''
} elseif (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Warn 'Claude CLI not found — cannot configure MCPs.'
    Write-Info 'Install the Claude CLI: https://claude.ai/code'
    Write-Info "Then re-run: pwsh -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`" -McpOnly"
    Write-Host ''
} else {
    Write-Host '  Security note:' -ForegroundColor Yellow
    Write-Dim "Tokens you enter will be stored in $TgtClaude\settings.json."
    Write-Dim 'That file has been added to .gitignore — never commit it.'
    Write-Dim 'Prefer setting tokens as PowerShell env vars instead:'
    Write-Dim '  $env:GITHUB_PERSONAL_ACCESS_TOKEN = "ghp_..."'
    Write-Dim '  $env:LINEAR_API_KEY = "lin_api_..."'
    Write-Dim 'Claude Code reads env vars automatically — no token in settings needed.'
    Write-Host ''

    if (-not (Read-YN 'Proceed with MCP token setup?')) {
        Write-Info 'Skipping MCP setup. Set env vars manually and re-run with -McpOnly'
        Write-Host ''
    } else {

        # Ensure log file exists for MCP-only runs
        New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null
        if (-not (Test-Path $LogFile)) {
            [System.IO.File]::WriteAllText($LogFile, '', [System.Text.UTF8Encoding]::new($false))
        }

        # ── 2a. Git Platform ──────────────────────────────────────────────────
        Write-Header 'Git Platform'
        $gitPlatform = Read-Menu 'Which Git platform do you use?' @(
            'GitHub', 'GitLab', 'Bitbucket', 'Azure DevOps', 'None / Self-hosted'
        )

        switch ($gitPlatform) {
            'GitHub' {
                Write-Host ''
                Write-Info 'Installing GitHub MCP...'
                Write-Dim 'Provides: issue/PR reading, repo search, file access via GitHub API'
                Write-Dim 'Or set GITHUB_PERSONAL_ACCESS_TOKEN as an env var to skip this prompt'
                $githubToken = if ($env:GITHUB_PERSONAL_ACCESS_TOKEN) {
                    Write-Info 'Using GITHUB_PERSONAL_ACCESS_TOKEN from environment'
                    $env:GITHUB_PERSONAL_ACCESS_TOKEN
                } else {
                    Read-Value 'GitHub Personal Access Token (repo + read:org scopes)'
                }
                if ($githubToken) {
                    Invoke-McpAdd 'GitHub' @('--scope', 'project', 'github',
                        'npx', '-y', '@modelcontextprotocol/server-github',
                        '--env', "GITHUB_PERSONAL_ACCESS_TOKEN=$githubToken")
                } else {
                    Write-Warn 'No token provided — skipping GitHub MCP (add later with: claude mcp add github)'
                }
            }
            'GitLab' {
                Write-Host ''
                Write-Info 'Installing GitLab MCP...'
                $gitlabToken = if ($env:GITLAB_PERSONAL_ACCESS_TOKEN) {
                    Write-Info 'Using GITLAB_PERSONAL_ACCESS_TOKEN from environment'
                    $env:GITLAB_PERSONAL_ACCESS_TOKEN
                } else {
                    Read-Value 'GitLab Personal Access Token'
                }
                $gitlabUrl = Read-Value 'GitLab URL' 'https://gitlab.com'
                if ($gitlabToken) {
                    Invoke-McpAdd 'GitLab' @('--scope', 'project', 'gitlab',
                        'npx', '-y', '@modelcontextprotocol/server-gitlab',
                        '--env', "GITLAB_PERSONAL_ACCESS_TOKEN=$gitlabToken",
                        '--env', "GITLAB_URL=$gitlabUrl")
                }
            }
            'None / Self-hosted' { Write-Info 'Skipping Git platform MCP' }
            default { Write-Warn "No official MCP for $gitPlatform yet — check https://github.com/modelcontextprotocol/servers" }
        }

        # ── 2b. Ticket System ─────────────────────────────────────────────────
        Write-Host ''
        Write-Header 'Ticket / Project Management'
        $ticketSystem = Read-Menu 'Which ticket system do you use?' @(
            'GitHub Issues (uses GitHub MCP above)', 'Linear', 'Jira', 'Notion', 'Trello', 'None'
        )

        switch -Wildcard ($ticketSystem) {
            'Linear' {
                Write-Host ''
                Write-Info 'Installing Linear MCP...'
                Write-Dim 'Provides: issue reading, project management, cycle tracking'
                $linearKey = if ($env:LINEAR_API_KEY) {
                    Write-Info 'Using LINEAR_API_KEY from environment'
                    $env:LINEAR_API_KEY
                } else {
                    Read-Value 'Linear API Key (from Linear Settings -> API)'
                }
                if ($linearKey) {
                    Invoke-McpAdd 'Linear' @('--scope', 'project', 'linear',
                        'npx', '-y', '@linear/mcp-server',
                        '--env', "LINEAR_API_KEY=$linearKey")
                }
            }
            'Jira' {
                Write-Host ''
                Write-Info 'Installing Jira MCP...'
                $jiraUrl   = Read-Value 'Jira URL (e.g. https://yourorg.atlassian.net)'
                $jiraEmail = Read-Value 'Jira account email'
                $jiraToken = if ($env:JIRA_API_TOKEN) {
                    Write-Info 'Using JIRA_API_TOKEN from environment'
                    $env:JIRA_API_TOKEN
                } else {
                    Read-Value 'Jira API Token (from id.atlassian.com/manage-profile/security/api-tokens)'
                }
                if ($jiraToken) {
                    Invoke-McpAdd 'Jira' @('--scope', 'project', 'jira',
                        'npx', '-y', '@modelcontextprotocol/server-jira',
                        '--env', "JIRA_URL=$jiraUrl",
                        '--env', "JIRA_EMAIL=$jiraEmail",
                        '--env', "JIRA_TOKEN=$jiraToken")
                }
            }
            'Notion' {
                Write-Host ''
                Write-Info 'Installing Notion MCP...'
                $notionToken = if ($env:NOTION_API_KEY) {
                    Write-Info 'Using NOTION_API_KEY from environment'
                    $env:NOTION_API_KEY
                } else {
                    Read-Value 'Notion Integration Token (from notion.so/my-integrations)'
                }
                if ($notionToken) {
                    Invoke-McpAdd 'Notion' @('--scope', 'project', 'notion',
                        'npx', '-y', '@modelcontextprotocol/server-notion',
                        '--env', "NOTION_API_KEY=$notionToken")
                }
            }
            default { Write-Info 'Skipping ticket system MCP' }
        }

        # ── 2c. Design Tools ──────────────────────────────────────────────────
        Write-Host ''
        Write-Header 'Design Tools'
        Write-Host '  Which design tools do you use? (select all that apply)' -ForegroundColor White
        Write-Dim 'Enter numbers separated by spaces (e.g. 1 3)'
        $designOptions = @('Figma', 'Storybook (component library)', 'None')
        for ($i = 0; $i -lt $designOptions.Count; $i++) {
            Write-Host "    $($i + 1)) $($designOptions[$i])"
        }
        $rawChoices   = (Read-Host '  Choices').Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        $designTools  = foreach ($n in $rawChoices) {
            $idx = [int]$n - 1
            if ($idx -ge 0 -and $idx -lt $designOptions.Count) { $designOptions[$idx] }
        }

        foreach ($tool in $designTools) {
            switch -Wildcard ($tool) {
                'Figma' {
                    Write-Host ''
                    Write-Info 'Installing Figma MCP...'
                    Write-Dim 'Provides: read Figma files, inspect components, extract design tokens'
                    $figmaToken = if ($env:FIGMA_API_KEY) {
                        Write-Info 'Using FIGMA_API_KEY from environment'
                        $env:FIGMA_API_KEY
                    } else {
                        Read-Value 'Figma Personal Access Token (from figma.com/developers/apps)'
                    }
                    if ($figmaToken) {
                        Invoke-McpAdd 'Figma' @('--scope', 'project', 'figma',
                            'npx', '-y', 'figma-developer-mcp',
                            '--env', "FIGMA_API_KEY=$figmaToken")
                    }
                }
                'Storybook*' {
                    Write-Info "Storybook: run 'storybook dev' and Claude can access it via browser tools"
                }
            }
        }

        # ── 2d. Core MCPs ─────────────────────────────────────────────────────
        Write-Host ''
        Write-Header 'Core MCPs (recommended for all projects)'

        if (Read-YN 'Install Context7 MCP? (instant access to up-to-date library docs)') {
            Invoke-McpAdd 'Context7' @('--scope', 'project', 'context7',
                'npx', '-y', '@upstash/context7-mcp')
        }

        if (Read-YN 'Install Sequential Thinking MCP? (improves multi-step reasoning)') {
            Invoke-McpAdd 'Sequential Thinking' @('--scope', 'project', 'sequential-thinking',
                'npx', '-y', '@modelcontextprotocol/server-sequential-thinking')
        }

        if (Read-YN 'Install Filesystem MCP? (direct file access without Claude Code file tools)') {
            Invoke-McpAdd 'Filesystem' @('--scope', 'project', 'filesystem',
                'npx', '-y', '@modelcontextprotocol/server-filesystem', $TargetDir)
            Write-Ok "Filesystem MCP scoped to $TargetDir"
        }

        # ── 2e. Serena ────────────────────────────────────────────────────────
        Write-Host ''
        if ((Get-Command uvx -ErrorAction SilentlyContinue) -or (Get-Command uv -ErrorAction SilentlyContinue)) {
            if (Read-YN 'Install Serena MCP? (semantic code navigation — highly recommended for large codebases)') {
                Invoke-McpAdd 'Serena' @('--scope', 'project', 'serena',
                    'uvx', '--from', 'serena[claude-code]', 'serena')
            }
        } else {
            Write-Dim 'Serena MCP skipped — requires Python/uv (install uv from https://astral.sh/uv)'
        }

    } # end MCP token setup
} # end claude CLI check

# ─── Phase 3: Summary ─────────────────────────────────────────────────────────
Write-Host ''
Write-Header 'Installation Complete!'
Write-Host ''

if (-not $McpOnly) {
    Write-Host "  v .claude/ merged into $TgtClaude"     -ForegroundColor Green
    Write-Host '  v Hook dependencies installed'          -ForegroundColor Green
    Write-Host '  v .gitignore updated (settings.json excluded)' -ForegroundColor Green
    Write-Dim 'settings.json and CLAUDE.md were preserved if they existed'
}

Write-Host ''
Write-Host '  Security reminder:' -ForegroundColor White
Write-Dim '.claude/settings.json is in .gitignore — never force-add it.'
Write-Dim 'Prefer env vars for tokens: $env:GITHUB_PERSONAL_ACCESS_TOKEN = "..."'
Write-Host ''
Write-Host '  Next steps:' -ForegroundColor White
Write-Host ''
Write-Host "  1. " -NoNewline; Write-Host "cd `"$TargetDir`"" -ForegroundColor Cyan
Write-Host ''
Write-Host '  2. ' -NoNewline
Write-Host 'Update CLAUDE.md' -ForegroundColor Cyan -NoNewline
Write-Host ' with your project stack and conventions.'
Write-Dim '(Or run /init in Claude Code to auto-generate it)'
Write-Host ''
Write-Host '  3. ' -NoNewline
Write-Host 'Add tool permissions' -ForegroundColor Cyan -NoNewline
Write-Host ' to .claude/settings.json for your build commands:'
Write-Dim 'e.g. "Bash(npm run:*)", "Bash(pytest:*)", "Bash(cargo:*)"'
Write-Host ''
Write-Host '  4. ' -NoNewline
Write-Host 'Open Claude Code' -ForegroundColor Cyan -NoNewline
Write-Host ' in your project and run:'
Write-Host '     /init          -- auto-detect stack and configure agents' -ForegroundColor White
Write-Host '     /primer        -- prime Claude project context'           -ForegroundColor White
Write-Host '     /pm:groom      -- groom your GitHub/Linear issues'        -ForegroundColor White
Write-Host '     /dev <issue>   -- implement your first feature autonomously' -ForegroundColor White
Write-Host ''
if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 0) {
    Write-Dim "Install log: $LogFile"
}
