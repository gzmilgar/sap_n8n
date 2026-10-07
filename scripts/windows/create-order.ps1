<#
.SYNOPSIS
    Creates a test order in the CAP service so the n8n approval loop fires.

.DESCRIPTION
    Posts to http://localhost:4004/odata/v4/order/Orders.
    Pass -Amount to force a value, or leave it out and CAP derives
    amount = Qty x Products.unitPrice from the price list.

.EXAMPLE
    .\create-order.ps1 -Amount 15000
    High value -> workflow 01 asks for approval on Telegram.

.EXAMPLE
    .\create-order.ps1 -Amount 500
    Low value -> workflow 01 auto-approves with approvedBy = auto-rule.

.EXAMPLE
    .\create-order.ps1 -Product "Endüstriyel Filtre Kartuşu" -Qty 40
    No -Amount: CAP calculates 40 x 375,00 = 15.000,00.
#>
[CmdletBinding()]
param(
    [double] $Amount,
    [string] $Customer = "Anadolu Makina A.Ş.",
    [string] $Product  = "Endüstriyel Filtre Kartuşu",
    [int]    $Qty      = 40,
    [string] $BaseUrl  = "http://localhost:4004/odata/v4/order"
)

$ErrorActionPreference = "Stop"

$body = [ordered]@{
    customer = $Customer
    product  = $Product
    qty      = $Qty
}
# Only send amount when the caller supplied one, otherwise let CAP calculate it.
if ($PSBoundParameters.ContainsKey('Amount')) { $body.amount = $Amount }

$json = $body | ConvertTo-Json -Depth 5

Write-Host "POST $BaseUrl/Orders" -ForegroundColor Cyan
Write-Host $json -ForegroundColor DarkGray

try {
    # -ContentType with charset keeps Turkish characters intact on Windows PowerShell 5.1.
    $resp = Invoke-RestMethod -Method Post -Uri "$BaseUrl/Orders" `
        -ContentType "application/json; charset=utf-8" `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
}
catch {
    Write-Host "Order creation FAILED: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "Order created" -ForegroundColor Green
Write-Host ("  ID       : {0}" -f $resp.ID)
Write-Host ("  Customer : {0}" -f $resp.customer)
Write-Host ("  Product  : {0}" -f $resp.product)
Write-Host ("  Qty      : {0}" -f $resp.qty)
Write-Host ("  Amount   : {0} {1}" -f $resp.amount, $resp.currency)
Write-Host ("  Status   : {0}" -f $resp.status)
Write-Host ""

if ([double]$resp.amount -gt 10000) {
    Write-Host "Amount is over 10.000 -> approval requested (check Telegram, or the n8n form when offline)." -ForegroundColor Yellow
} else {
    Write-Host "Amount is under 10.000 -> should auto-approve within a few seconds." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Poll the result with:" -ForegroundColor Cyan
# OData V4 key syntax: /Orders(<uuid>) - no guid'...' wrapper (that is V2 and returns 400).
Write-Host ("  Invoke-RestMethod '{0}/Orders({1})' | Select-Object status, approvedBy, approvedAt" -f $BaseUrl, $resp.ID)
