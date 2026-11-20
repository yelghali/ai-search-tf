$ErrorActionPreference = 'Stop'

try {
    $token = az account get-access-token --resource https://search.azure.com --subscription $env:AZURE_SUBSCRIPTION_ID --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($token)) {
        throw 'Failed to obtain a Search access token. Log in to Azure CLI as the Terraform identity.'
    }

    for ($attempt = 1; $attempt -le 60; $attempt++) {
        $response = Invoke-WebRequest -Method Put -Uri $env:SEARCH_INDEX_ENDPOINT `
            -Headers @{ Authorization = "Bearer $token" } `
            -ContentType 'application/json; charset=utf-8' `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($env:SEARCH_INDEX_DEFINITION)) `
            -SkipHttpErrorCheck -TimeoutSec 60
        $status = [int]$response.StatusCode
        if ($status -in 200, 201) {
            Write-Host "Search index created or updated (HTTP $status)."
            exit 0
        }
        if ($status -notin 401, 403, 429, 502, 503, 504 -or $attempt -eq 60) {
            throw "Index creation failed (HTTP $status): $($response.Content)"
        }
        Write-Warning "Index creation attempt $attempt returned HTTP $status; waiting 10 seconds for service/RBAC readiness."
        Start-Sleep -Seconds 10
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
