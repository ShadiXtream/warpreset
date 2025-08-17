<#
.SYNOPSIS
    Enhanced Warp application cleanup and restart utility.

.DESCRIPTION
    This script provides a robust solution for cleaning up Warp application data files,
    stopping the application gracefully, removing log/analytics files, and restarting
    the application with proper error handling and logging.

.PARAMETER UserName
    Specifies the username for the target user profile. Defaults to current user.

.PARAMETER WaitTimeSeconds
    Time to wait after stopping processes before cleanup (default: 3 seconds).

.PARAMETER MaxRetries
    Maximum number of retry attempts for process operations (default: 3).

.PARAMETER LogPath
    Path for script execution logs. Defaults to temp directory.

.PARAMETER WhatIf
    Shows what would be done without actually performing the operations.

.EXAMPLE
    .\Clean-WarpData.ps1
    Runs cleanup for current user with default settings.

.EXAMPLE
    .\Clean-WarpData.ps1 -UserName "john.doe" -WaitTimeSeconds 5 -WhatIf
    Shows what would be done for user john.doe with 5-second wait time.

.NOTES
    Author: ShadiXtream & Claude Sonnet 4 (custom project)
    Version: 2.0
    Requires: PowerShell 5.0+ and appropriate permissions
    
    WARNING: This script will terminate Warp processes and delete data files.
    Ensure Warp is not performing critical operations before running.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Target username (defaults to current user)")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName = $env:USERNAME,
    
    [Parameter(Mandatory = $false, HelpMessage = "Wait time in seconds after stopping processes")]
    [ValidateRange(1, 30)]
    [int]$WaitTimeSeconds = 3,
    
    [Parameter(Mandatory = $false, HelpMessage = "Maximum retry attempts for operations")]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3,
    
    [Parameter(Mandatory = $false, HelpMessage = "Path for execution logs")]
    [ValidateScript({ Test-Path (Split-Path $_) -PathType Container })]
    [string]$LogPath = "$env:TEMP\WarpCleanup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

#Requires -Version 5.0

# Script configuration
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'Continue'

# Initialize logging
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
        [string]$Level = 'INFO'
    )
    
    process {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $logEntry = "[$timestamp] [$Level] $Message"
        
        # Console output with colors
        switch ($Level) {
            'ERROR' { Write-Host $logEntry -ForegroundColor Red }
            'WARNING' { Write-Host $logEntry -ForegroundColor Yellow }
            'DEBUG' { Write-Host $logEntry -ForegroundColor Cyan }
            default { Write-Host $logEntry -ForegroundColor Green }
        }
        
        # File logging
        try {
            $logEntry | Out-File -FilePath $LogPath -Append -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

# Validate and construct paths
function Initialize-Paths {
    [CmdletBinding()]
    param([string]$User)
    
    $paths = @{
        UserProfile = "C:\Users\$User"
        WarpData = "C:\Users\$User\AppData\Local\warp\Warp\data"
        WarpExecutable = "C:\Users\$User\AppData\Local\Programs\Warp\warp.exe"
    }
    
    # Alternative common installation paths
    $alternativePaths = @(
        "C:\Program Files\Warp\warp.exe",
        "C:\Program Files (x86)\Warp\warp.exe",
        "$env:LOCALAPPDATA\Programs\Warp\warp.exe"
    )
    
    # Validate user profile exists
    if (-not (Test-Path $paths.UserProfile -PathType Container)) {
        throw "User profile not found: $($paths.UserProfile)"
    }
    
    # Find Warp executable
    if (-not (Test-Path $paths.WarpExecutable -PathType Leaf)) {
        Write-Log "Default Warp path not found, searching alternatives..." -Level WARNING
        
        $foundPath = $alternativePaths | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
        
        if ($foundPath) {
            $paths.WarpExecutable = $foundPath
            Write-Log "Found Warp executable at: $foundPath" -Level INFO
        }
        else {
            throw "Warp executable not found in any common locations"
        }
    }
    
    return $paths
}

# Enhanced process management with retries
function Stop-WarpProcesses {
    [CmdletBinding()]
    param(
        [int]$MaxAttempts,
        [int]$WaitTime
    )
    
    $attempt = 1
    $processNames = @('warp', 'Warp')  # Handle case variations
    
    while ($attempt -le $MaxAttempts) {
        try {
            Write-Log "Attempt $attempt/$MaxAttempts to stop Warp processes" -Level INFO
            
            $runningProcesses = Get-Process -Name $processNames -ErrorAction SilentlyContinue
            
            if (-not $runningProcesses) {
                Write-Log "No Warp processes found running" -Level INFO
                return $true
            }
            
            foreach ($process in $runningProcesses) {
                Write-Log "Stopping process: $($process.ProcessName) (PID: $($process.Id))" -Level INFO
                
                if ($PSCmdlet.ShouldProcess($process.ProcessName, "Stop Process")) {
                    # Try graceful shutdown first
                    if (-not $process.CloseMainWindow()) {
                        Write-Log "Graceful shutdown failed, forcing termination for PID $($process.Id)" -Level WARNING
                        $process | Stop-Process -Force
                    }
                }
            }
            
            # Wait and verify
            Start-Sleep -Seconds $WaitTime
            $remainingProcesses = Get-Process -Name $processNames -ErrorAction SilentlyContinue
            
            if (-not $remainingProcesses) {
                Write-Log "All Warp processes successfully stopped" -Level INFO
                return $true
            }
            
            Write-Log "Some processes still running, retrying..." -Level WARNING
            $attempt++
        }
        catch {
            Write-Log "Error stopping processes (attempt $attempt): $($_.Exception.Message)" -Level ERROR
            $attempt++
            if ($attempt -le $MaxAttempts) {
                Start-Sleep -Seconds 2
            }
        }
    }
    
    Write-Log "Failed to stop all Warp processes after $MaxAttempts attempts" -Level ERROR
    return $false
}

# Enhanced file cleanup with detailed logging
function Clear-WarpData {
    [CmdletBinding()]
    param(
        [string]$DataPath,
        [string[]]$ExcludeFiles = @('warp.sqlite')
    )
    
    if (-not (Test-Path $DataPath -PathType Container)) {
        Write-Log "Warp data directory not found: $DataPath" -Level WARNING
        return $false
    }
    
    try {
        Write-Log "Starting cleanup in: $DataPath" -Level INFO
        
        # Get files to clean (excluding specified files)
        $filesToRemove = Get-ChildItem -Path $DataPath -File -ErrorAction Stop | 
                        Where-Object { $_.Name -notin $ExcludeFiles }
        
        if (-not $filesToRemove) {
            Write-Log "No files to clean up (excluding: $($ExcludeFiles -join ', '))" -Level INFO
            return $true
        }
        
        Write-Log "Found $($filesToRemove.Count) files to remove" -Level INFO
        
        $successCount = 0
        $errorCount = 0
        
        foreach ($file in $filesToRemove) {
            try {
                if ($PSCmdlet.ShouldProcess($file.FullName, "Delete File")) {
                    # Additional safety check for critical files
                    if ($file.Extension -eq '.exe' -or $file.Extension -eq '.dll') {
                        Write-Log "Skipping potentially critical file: $($file.Name)" -Level WARNING
                        continue
                    }
                    
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                    Write-Log "Removed: $($file.Name) ($($file.Length) bytes)" -Level DEBUG
                    $successCount++
                }
            }
            catch {
                Write-Log "Failed to remove $($file.Name): $($_.Exception.Message)" -Level ERROR
                $errorCount++
            }
        }
        
        Write-Log "Cleanup completed: $successCount files removed, $errorCount errors" -Level INFO
        return ($errorCount -eq 0)
    }
    catch {
        Write-Log "Error during cleanup: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Enhanced Warp startup with process verification
function Start-WarpApplication {
    [CmdletBinding()]
    param(
        [string]$ExecutablePath,
        [int]$VerificationWaitSeconds = 5
    )
    
    try {
        if ($PSCmdlet.ShouldProcess($ExecutablePath, "Start Process")) {
            Write-Log "Starting Warp application: $ExecutablePath" -Level INFO
            
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $ExecutablePath
            $startInfo.WorkingDirectory = Split-Path $ExecutablePath
            $startInfo.UseShellExecute = $true
            
            $process = [System.Diagnostics.Process]::Start($startInfo)
            
            if ($process) {
                Write-Log "Warp started successfully (PID: $($process.Id))" -Level INFO
                
                # Verify startup
                Start-Sleep -Seconds $VerificationWaitSeconds
                $runningProcess = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
                
                if ($runningProcess) {
                    Write-Log "Warp startup verified - process is running" -Level INFO
                    return $true
                }
                else {
                    Write-Log "Warp process terminated unexpectedly after startup" -Level WARNING
                    return $false
                }
            }
        }
        
        return $false
    }
    catch {
        Write-Log "Error starting Warp: $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

# Performance monitoring
function Measure-ScriptExecution {
    [CmdletBinding()]
    param([scriptblock]$ScriptBlock)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = & $ScriptBlock
        return @{
            Success = $true
            Result = $result
            Duration = $stopwatch.Elapsed
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            Duration = $stopwatch.Elapsed
        }
    }
    finally {
        $stopwatch.Stop()
    }
}

# Main execution flow
try {
    Write-Log "=== Warp Cleanup Script Started ===" -Level INFO
    Write-Log "Parameters: User=$UserName, WaitTime=$WaitTimeSeconds, MaxRetries=$MaxRetries" -Level INFO
    
    # Initialize paths and validate environment
    $paths = Initialize-Paths -User $UserName
    Write-Log "Paths validated successfully" -Level INFO
    
    # Execution phases
    $phases = @(
        @{ Name = "Stop Processes"; Action = { Stop-WarpProcesses -MaxAttempts $MaxRetries -WaitTime $WaitTimeSeconds } },
        @{ Name = "Clean Data"; Action = { Clear-WarpData -DataPath $paths.WarpData } },
        @{ Name = "Start Application"; Action = { Start-WarpApplication -ExecutablePath $paths.WarpExecutable } }
    )
    
    $overallSuccess = $true
    $totalDuration = [TimeSpan]::Zero
    
    foreach ($phase in $phases) {
        Write-Log "--- Phase: $($phase.Name) ---" -Level INFO
        
        $result = Measure-ScriptExecution -ScriptBlock $phase.Action
        $totalDuration = $totalDuration.Add($result.Duration)
        
        Write-Log "Phase '$($phase.Name)' completed in $($result.Duration.TotalSeconds.ToString('F2')) seconds" -Level INFO
        
        if (-not $result.Success) {
            Write-Log "Phase '$($phase.Name)' failed: $($result.Error)" -Level ERROR
            $overallSuccess = $false
            
            # Critical failure handling
            if ($phase.Name -eq "Stop Processes") {
                Write-Log "Critical phase failed - aborting script execution" -Level ERROR
                throw "Cannot proceed without stopping Warp processes safely"
            }
        }
        elseif ($result.Result -eq $false) {
            Write-Log "Phase '$($phase.Name)' completed with warnings" -Level WARNING
            # Continue execution for non-critical warnings
        }
    }
    
    # Final summary
    $status = if ($overallSuccess) { "SUCCESS" } else { "COMPLETED WITH ERRORS" }
    Write-Log "=== Script Execution $status ===" -Level INFO
    Write-Log "Total execution time: $($totalDuration.TotalSeconds.ToString('F2')) seconds" -Level INFO
    Write-Log "Log file: $LogPath" -Level INFO
    
    if (-not $overallSuccess) {
        Write-Log "Some operations failed. Check the log for details." -Level WARNING
        exit 1
    }
}
catch {
    Write-Log "=== SCRIPT EXECUTION FAILED ===" -Level ERROR
    Write-Log "Fatal error: $($_.Exception.Message)" -Level ERROR
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level DEBUG
    Write-Log "Log file: $LogPath" -Level INFO
    exit 2
}
finally {
    Write-Log "=== Warp Cleanup Script Finished ===" -Level INFO
}