# UtilKit

UtilKit is a small PowerShell CLI for automating repetitive local tasks.

## Installation Without Administrator Permissions

This installation uses a folder in the user `PATH`. It does not modify system environment variables.

From this folder:

```powershell
.\install-user-path.cmd
```

Close and reopen your terminal. Then verify:

```powershell
utilkit help
```

The installed command uses `bin\utilkit.cmd`, which invokes PowerShell with `-ExecutionPolicy Bypass` only for UtilKit. If you prefer to run `.ps1` files directly, you can enable signed or local scripts for your user:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## Commands

### `replace-secrets`

Replaces tokens in local files using an unversioned JSON file.

By default, it searches recursively from the current folder:

- `appsettings*.json`
- `web.config`
- `web.*.config`

It ignores common folders such as `.git`, `.vs`, `bin`, `obj`, `node_modules`, and `packages`.

1. Copy the example:

```powershell
Copy-Item .\.local-secrets.example.json .\.local-secrets.json
```

2. Edit `.local-secrets.json` with your local secrets.

3. Run a dry run first:

```powershell
utilkit replace-secrets --what-if
```

4. Apply the replacements:

```powershell
utilkit replace-secrets
```

You can also use another file:

```powershell
utilkit replace-secrets --config .\mi-config.local-secrets.json
```

You can also provide another root folder:

```powershell
utilkit replace-secrets --root C:\Proyectos\MiProyecto
```

Recommended format:

```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "value": "password-local"
    },
    {
      "name": "API_KEY",
      "value": "api-key-local"
    }
  ]
}
```

With that format, UtilKit replaces `{{DB_PASSWORD}}` and `{{API_KEY}}` in the files it finds.

If the token does not match the secret name, use `token`:

```json
{
  "secrets": [
    {
      "token": "__DB_PASSWORD__",
      "value": "password-local"
    }
  ]
}
```

You can also use a short map:

```json
{
  "secrets": {
    "DB_PASSWORD": "password-local",
    "API_KEY": "api-key-local"
  }
}
```

That map replaces `{{DB_PASSWORD}}` and `{{API_KEY}}`.

If you need to target specific files, add `files`:

```json
{
  "secrets": [
    {
      "name": "DB_PASSWORD",
      "value": "password-local"
    },
    {
      "name": "API_KEY",
      "value": "api-key-local"
    }
  ],
  "files": [
    {
      "path": ".\\appsettings.Development.json"
    },
    {
      "path": ".\\.env",
      "replacements": {
        "{{API_KEY}}": "api-key-solo-para-env"
      }
    }
  ]
}
```

Without `files`, UtilKit automatically discovers .NET configuration files. With `files`, it only processes those files.

Root-level `secrets` applies to all processed files. `files[].replacements` lets you override or add values for a single file. `replacements` is still supported if you prefer to declare exact tokens such as `{{DB_PASSWORD}}`.

### `run-iso-report`

Runs ISO Report from a configured local folder using the only two modes currently needed: `-7` and `-14`.

1. Copy the example:

```powershell
Copy-Item .\.iso-report.local.example.json .\.iso-report.local.json
```

2. Edit `.iso-report.local.json` with the local ISO Report path:

```json
{
  "path": "C:\\Path\\To\\IsoReport",
  "defaultMode": "-7"
}
```

3. Run it:

```powershell
utilkit run-iso-report -7
utilkit run-iso-report -14
```

You can also override the path for one run:

```powershell
utilkit run-iso-report -7 --path C:\Path\To\IsoReport
```

To verify the resolved command without running it:

```powershell
utilkit run-iso-report -7 --dry-run
```

## Security

Do not store real secrets or machine-specific paths in versioned files. `.local-secrets.json`, `*.local-secrets.json`, and `.iso-report.local.json` are ignored by Git.
