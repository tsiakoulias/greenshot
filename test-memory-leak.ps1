# Memory Leak Test for GCHandle fix in DibFileFormatHandler
# PR #813: https://github.com/greenshot/greenshot/pull/813
#
# This script monitors Greenshot's memory and handle count while you perform paste operations.
# The fix ensures GCHandle is freed after DIBV5 clipboard operations.
#
# USAGE:
# 1. Build Greenshot (old version without fix for baseline, then with fix)
# 2. Run Greenshot
# 3. Run this script
# 4. Perform 50+ paste operations (Ctrl+V in Greenshot editor with image on clipboard)
# 5. Compare results

param(
    [int]$IntervalSeconds = 2,
    [int]$DurationMinutes = 5
)

$processName = "Greenshot"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " GCHandle Memory Leak Test" -ForegroundColor Cyan
Write-Host " PR #813 - DibFileFormatHandler Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find Greenshot process
$process = Get-Process -Name $processName -ErrorAction SilentlyContinue

if (-not $process) {
    Write-Host "ERROR: Greenshot is not running. Please start it first." -ForegroundColor Red
    exit 1
}

Write-Host "Found Greenshot (PID: $($process.Id))" -ForegroundColor Green
Write-Host ""
Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
Write-Host "1. Copy an image to clipboard (e.g., PrtScn or from any app)"
Write-Host "2. Open Greenshot editor (take a screenshot)"
Write-Host "3. Repeatedly paste (Ctrl+V) the clipboard image"
Write-Host "4. Watch the memory/handle count below"
Write-Host ""
Write-Host "WITHOUT FIX: Memory and handles will grow continuously"
Write-Host "WITH FIX: Memory and handles should stabilize"
Write-Host ""
Write-Host "Press Ctrl+C to stop monitoring"
Write-Host ""
Write-Host "----------------------------------------"

# Baseline
$baseline = Get-Process -Id $process.Id
$baselineMemory = [math]::Round($baseline.WorkingSet64 / 1MB, 2)
$baselineHandles = $baseline.HandleCount

Write-Host ("BASELINE - Memory: {0} MB | Handles: {1}" -f $baselineMemory, $baselineHandles) -ForegroundColor Magenta
Write-Host "----------------------------------------"
Write-Host ""

# Header
Write-Host ("{0,-12} {1,12} {2,12} {3,14} {4,14}" -f "Time", "Memory (MB)", "Handles", "Mem Change", "Handle Change")
Write-Host ("{0,-12} {1,12} {2,12} {3,14} {4,14}" -f "----", "-----------", "-------", "----------", "-------------")

$startTime = Get-Date
$endTime = $startTime.AddMinutes($DurationMinutes)

try {
    while ((Get-Date) -lt $endTime) {
        Start-Sleep -Seconds $IntervalSeconds
        
        $current = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
        if (-not $current) {
            Write-Host "Greenshot process ended." -ForegroundColor Red
            break
        }
        
        $currentMemory = [math]::Round($current.WorkingSet64 / 1MB, 2)
        $currentHandles = $current.HandleCount
        
        $memDiff = [math]::Round($currentMemory - $baselineMemory, 2)
        $handleDiff = $currentHandles - $baselineHandles
        
        $memColor = if ($memDiff -gt 50) { "Red" } elseif ($memDiff -gt 20) { "Yellow" } else { "Green" }
        $handleColor = if ($handleDiff -gt 100) { "Red" } elseif ($handleDiff -gt 50) { "Yellow" } else { "Green" }
        
        $timestamp = (Get-Date).ToString("HH:mm:ss")
        $memSign = if ($memDiff -ge 0) { "+" } else { "" }
        $handleSign = if ($handleDiff -ge 0) { "+" } else { "" }
        
        Write-Host ("{0,-12} {1,12} {2,12} " -f $timestamp, $currentMemory, $currentHandles) -NoNewline
        Write-Host ("{0,14} " -f "$memSign$memDiff MB") -ForegroundColor $memColor -NoNewline
        Write-Host ("{0,14}" -f "$handleSign$handleDiff") -ForegroundColor $handleColor
    }
}
catch {
    # Ctrl+C pressed
}

Write-Host ""
Write-Host "----------------------------------------"

# Final stats
$final = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
if ($final) {
    $finalMemory = [math]::Round($final.WorkingSet64 / 1MB, 2)
    $finalHandles = $final.HandleCount
    
    Write-Host "FINAL RESULTS:" -ForegroundColor Cyan
    Write-Host ("  Memory: {0} MB (started at {1} MB, change: {2} MB)" -f $finalMemory, $baselineMemory, [math]::Round($finalMemory - $baselineMemory, 2))
    Write-Host ("  Handles: {0} (started at {1}, change: {2})" -f $finalHandles, $baselineHandles, ($finalHandles - $baselineHandles))
    Write-Host ""
    
    $memGrowth = $finalMemory - $baselineMemory
    if ($memGrowth -gt 50) {
        Write-Host "WARNING: Significant memory growth detected. Possible leak." -ForegroundColor Red
    } else {
        Write-Host "Memory growth within normal range." -ForegroundColor Green
    }
}
