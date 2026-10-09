$ErrorActionPreference = "Stop"

$root = $PSScriptRoot

Write-Host "Installing Upload Lambda dependencies..."
Push-Location (Join-Path $root "lambda\upload")
try {
    npm ci --omit=dev
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Upload Lambda dependencies."
    }
}
finally {
    Pop-Location
}

Write-Host "Installing Crop Lambda dependencies for Linux x64..."
Push-Location (Join-Path $root "lambda\crop")
try {
    npm ci --omit=dev --os=linux --cpu=x64 --libc=glibc
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install Crop Lambda dependencies."
    }
}
finally {
    Pop-Location
}

Write-Host "Lambda dependencies installed successfully."