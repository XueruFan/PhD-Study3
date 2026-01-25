# ===============================
# Batch gunzip all .nii.gz files
# Keep original .nii.gz
# ===============================

$root = "E:\PhDproject\Study3\data"

Get-ChildItem -Path $root -Recurse -Filter "*.nii.gz" | ForEach-Object {

    $gzFile  = $_.FullName
    $outFile = $gzFile -replace '\.gz$', ''

    if (Test-Path $outFile) {
        Write-Host "SKIP (exists): $outFile"
    }
    else {
        Write-Host "Extracting: $gzFile"
        $in  = [System.IO.File]::OpenRead($gzFile)
        $out = [System.IO.File]::Create($outFile)
        $gz  = New-Object System.IO.Compression.GzipStream($in, [System.IO.Compression.CompressionMode]::Decompress)
        $gz.CopyTo($out)
        $gz.Close()
        $out.Close()
        $in.Close()
    }
}

Write-Host "DONE"
