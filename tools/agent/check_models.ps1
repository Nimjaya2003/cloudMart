
$region = "ap-south-1"

$models = aws bedrock list-foundation-models `
    --region $region `
    --query "modelSummaries[?contains(outputModalities, 'TEXT')].modelId" `
    --output json | ConvertFrom-Json

$results = foreach ($model in ($models | Sort-Object -Unique)) {

    Write-Host "Checking: $model"

    $raw = aws bedrock get-foundation-model-availability `
        --model-id $model `
        --region $region `
        --output json 2>$null

    if ($LASTEXITCODE -ne 0) {

        [PSCustomObject]@{
            Model = $model
            Authorization = "CHECK_FAILED"
            Region = "UNKNOWN"
            Entitlement = "UNKNOWN"
            Agreement = "UNKNOWN"
        }

        continue
    }

    $result = $raw | ConvertFrom-Json

    [PSCustomObject]@{
        Model = $model
        Authorization = $result.authorizationStatus
        Region = $result.regionAvailability
        Entitlement = $result.entitlementAvailability
        Agreement = $result.agreementAvailability.status
    }
}

Write-Host "`nALL MODEL RESULTS" -ForegroundColor Cyan

$results | Format-Table -AutoSize

Write-Host "`nAUTHORIZED MODELS" -ForegroundColor Green

$results |
    Where-Object {
        $_.Authorization -eq "AUTHORIZED"
    } |
    Format-Table -AutoSize

$results | Export-Csv `
    -Path "tools/agent/model-availability.csv" `
    -NoTypeInformation

Write-Host "`nResults saved successfully."
