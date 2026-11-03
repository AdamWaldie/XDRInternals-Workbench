# Raw portal API

1 cmdlets. Run them through `tools/agent/Invoke-XdrAgent.ps1`. Guard and tenant rules are in `../../SKILL.md`.

## Invoke-XdrRestMethod

Guard: `read (GET only)`

Invokes a REST API call to Microsoft Defender XDR with authenticated session.

Executes REST API requests to Microsoft Defender XDR endpoints using the authenticated session and headers.
This is a wrapper function that ensures connection settings are updated before making the API call.

```powershell
Invoke-XdrRestMethod -Uri <String> [-Method <String>] [-ContentType <String>] [-WebSession <Object>] [-Headers <Hashtable>] [-Body <Object>]
```

| Parameter | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| -Uri | String | yes |  | The URI of the API endpoint to call. |
| -Method | String |  | GET | The HTTP method to use for the request. Defaults to "GET". |
| -ContentType | String |  | application/json | The content type of the request. Defaults to "application/json". |
| -WebSession | Object |  | $script:session | The web session to use for the request. Defaults to the script-scoped session variable. |
| -Headers | Hashtable |  | $script:headers | The headers to include in the request. Defaults to the script-scoped headers variable. |
| -Body | Object |  |  | The body of the request, if applicable. |

Example 1:

```powershell
Invoke-XdrRestMethod -Uri "https://security.microsoft.com/apiproxy/mtp/settings/GetAdvancedFeaturesSetting"
```

Makes a GET request to the specified XDR API endpoint.

Example 2:

```powershell
Invoke-XdrRestMethod -Uri "https://security.microsoft.com/apiproxy/mtp/..." -Method "POST"
```

Makes a POST request to the specified XDR API endpoint.

