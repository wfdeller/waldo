# Waldo Windows Round-trip Validation Test Suite
param(
    [switch]$Verbose,
    [switch]$Debug,
    [switch]$KeepFiles,
    [switch]$DesktopOnly,
    [switch]$Help
)

if ($Help) {
    Write-Host "Waldo Windows Round-trip Validation Test Suite"
    Write-Host ""
    Write-Host "Usage: .\test_roundtrip.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Verbose      Show detailed output"
    Write-Host "  -Debug        Show debug information"
    Write-Host "  -KeepFiles    Keep test files after completion"
    Write-Host "  -DesktopOnly  Run only desktop capture tests"
    Write-Host "  -Help         Show this help message"
    exit 0
}

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

function Write-Success {
    param($Message)
    Write-Host "✅ $Message" -ForegroundColor $Green
}

function Write-Error {
    param($Message)
    Write-Host "❌ $Message" -ForegroundColor $Red
}

function Write-Warning {
    param($Message)
    Write-Host "⚠️  $Message" -ForegroundColor $Yellow
}

function Write-Info {
    param($Message)
    Write-Host "ℹ️  $Message" -ForegroundColor $Blue
}

# Configuration
$BinaryPath = ".\src\Waldo.CLI\bin\Debug\net8.0\waldo.exe"
$TempDir = ".\test_temp"
$TestCount = 0
$PassedCount = 0
$FailedCount = 0

# Check if binary exists
if (-not (Test-Path $BinaryPath)) {
    Write-Error "Waldo binary not found at $BinaryPath"
    Write-Info "Please build the project first:"
    Write-Host "  dotnet build"
    exit 1
}

Write-Host "=== Waldo Windows Round-trip Validation Test Suite ===" -ForegroundColor $Blue
Write-Host "Binary: $BinaryPath"
Write-Host "Temp directory: $TempDir"
Write-Host ""

# Create temp directory
if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir | Out-Null
}

function Test-Command {
    param(
        [string]$Name,
        [string]$Command,
        [string]$ExpectedOutput = "Watermark detected!"
    )
    
    $global:TestCount++
    
    if ($Verbose) {
        Write-Host "Running $Name..." -NoNewline
    }
    
    try {
        $output = Invoke-Expression $Command 2>&1
        
        if ($output -match $ExpectedOutput) {
            if ($Verbose) {
                Write-Success " PASSED"
            } else {
                Write-Success "$Name PASSED"
            }
            $global:PassedCount++
            return $true
        } else {
            if ($Debug) {
                Write-Error " FAILED"
                Write-Host "Command: $Command"
                Write-Host "Output: $output"
            } else {
                Write-Error "$Name FAILED"
            }
            $global:FailedCount++
            return $false
        }
    } catch {
        if ($Debug) {
            Write-Error " FAILED"
            Write-Host "Command: $Command"
            Write-Host "Error: $_"
        } else {
            Write-Error "$Name FAILED"
        }
        $global:FailedCount++
        return $false
    }
}

if (-not $DesktopOnly) {
    Write-Host "=== Core Round-trip Tests ===" -ForegroundColor $Blue
    
    # Test 1: Small overlay
    $testFile = "$TempDir\small.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 300 --height 200 --opacity 100"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Small overlay (300x200)" $extractCmd
    } catch {
        Write-Error "Small overlay (300x200) FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 2: Medium overlay
    $testFile = "$TempDir\medium.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 800 --height 600 --opacity 80"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Medium overlay (800x600)" $extractCmd
    } catch {
        Write-Error "Medium overlay (800x600) FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 3: Large overlay
    $testFile = "$TempDir\large.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 1200 --height 900 --opacity 60"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Large overlay (1200x900)" $extractCmd
    } catch {
        Write-Error "Large overlay (1200x900) FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 4: High opacity overlay
    $testFile = "$TempDir\high_opacity.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 600 --height 400 --opacity 100"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "High opacity overlay" $extractCmd
    } catch {
        Write-Error "High opacity overlay FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 5: Low opacity overlay
    $testFile = "$TempDir\low_opacity.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 600 --height 400 --opacity 20"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Low opacity overlay" $extractCmd
    } catch {
        Write-Error "Low opacity overlay FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 6: Square overlay
    $testFile = "$TempDir\square.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 500 --height 500 --opacity 80"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Square overlay" $extractCmd
    } catch {
        Write-Error "Square overlay FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 7: Wide overlay (16:9)
    $testFile = "$TempDir\wide.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 800 --height 450 --opacity 70"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Wide overlay (16:9)" $extractCmd
    } catch {
        Write-Error "Wide overlay (16:9) FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    # Test 8: Tall overlay (9:16)
    $testFile = "$TempDir\tall.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 450 --height 800 --opacity 70"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        Test-Command "Tall overlay (9:16)" $extractCmd
    } catch {
        Write-Error "Tall overlay (9:16) FAILED - Could not create overlay"
        $global:TestCount++
        $global:FailedCount++
    }
    
    Write-Host ""
    Write-Host "=== Performance Testing ===" -ForegroundColor $Blue
    
    # Performance test
    $testFile = "$TempDir\performance.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 1920 --height 1080 --opacity 80"
    $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"
    
    Write-Info "Testing creation performance..."
    $createTime = Measure-Command { Invoke-Expression $saveCmd | Out-Null }
    Write-Success "Overlay creation: $([math]::Round($createTime.TotalMilliseconds))ms"
    
    Write-Info "Testing extraction performance..."
    $extractTime = Measure-Command { Invoke-Expression $extractCmd | Out-Null }
    Write-Success "Watermark extraction: $([math]::Round($extractTime.TotalMilliseconds))ms"
    
    Write-Host ""
    Write-Host "=== Threshold Testing ===" -ForegroundColor $Blue
    
    # Threshold tests
    $testFile = "$TempDir\threshold_test.png"
    $saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 400 --height 300 --opacity 80"
    
    try {
        Invoke-Expression $saveCmd | Out-Null
        
        $thresholds = @(0.1, 0.3, 0.5, 0.7, 0.9)
        $thresholdPassed = 0
        
        foreach ($threshold in $thresholds) {
            $extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction --threshold $threshold"
            if (Test-Command "Testing threshold $threshold" $extractCmd) {
                $thresholdPassed++
            }
        }
        
        Write-Success "Threshold tests: $thresholdPassed/$($thresholds.Length) passed"
    } catch {
        Write-Error "Threshold testing failed - Could not create test overlay"
    }
}

Write-Host ""
Write-Host "=== Edge Case Testing ===" -ForegroundColor $Blue

# Very small image test
$testFile = "$TempDir\very_small.png"
$saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 100 --height 100 --opacity 100"
$extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"

try {
    Invoke-Expression $saveCmd | Out-Null
    Test-Command "Testing very small image (100x100)" $extractCmd
} catch {
    Write-Error "Very small image test FAILED - Could not create overlay"
    $global:TestCount++
    $global:FailedCount++
}

# Very high opacity test
$testFile = "$TempDir\very_high_opacity.png"
$saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 400 --height 300 --opacity 100"
$extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"

try {
    Invoke-Expression $saveCmd | Out-Null
    Test-Command "Testing very high opacity (100)" $extractCmd
} catch {
    Write-Error "Very high opacity test FAILED - Could not create overlay"
    $global:TestCount++
    $global:FailedCount++
}

# Low opacity test
$testFile = "$TempDir\very_low_opacity.png"
$saveCmd = "& `"$BinaryPath`" overlay save-overlay `"$testFile`" --width 400 --height 300 --opacity 10"
$extractCmd = "& `"$BinaryPath`" extract `"$testFile`" --simple-extraction"

try {
    Invoke-Expression $saveCmd | Out-Null
    Test-Command "Testing low opacity (10)" $extractCmd
} catch {
    Write-Error "Low opacity test FAILED - Could not create overlay"
    $global:TestCount++
    $global:FailedCount++
}

# Cleanup
if (-not $KeepFiles) {
    Write-Info "Cleaning up test files..."
    Remove-Item "$TempDir\*" -Force -ErrorAction SilentlyContinue
} else {
    Write-Info "Test files kept in $TempDir"
}

Write-Host ""
Write-Host "=== Test Results Summary ===" -ForegroundColor $Blue

if ($FailedCount -eq 0) {
    Write-Success "All core tests passed: $PassedCount/$TestCount"
    Write-Host "🎉 Waldo Windows round-trip validation: SUCCESS" -ForegroundColor $Green
} else {
    Write-Warning "Some tests failed: $PassedCount passed, $FailedCount failed out of $TestCount total"
    if ($PassedCount -gt 0) {
        Write-Host "✅ Partial success: Core functionality working" -ForegroundColor $Yellow
    } else {
        Write-Host "❌ Critical failure: No tests passed" -ForegroundColor $Red
    }
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor $Blue
Write-Host "  • Test with real camera photos: waldo overlay start && take photo && waldo extract photo.jpg"
Write-Host "  • Test overlay functionality: waldo overlay start --opacity 100"
Write-Host "  • Test screenshot extraction: waldo extract screenshot.png --threshold 0.2 --debug"
Write-Host "  • Run performance benchmarks: Measure-Command { waldo overlay save-overlay test.png }"
Write-Host "  • Debug extraction: waldo extract image.png --threshold 0.1 --debug --verbose"

exit $FailedCount