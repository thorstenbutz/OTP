# Platform-specific UI implementations
class ConsoleUI {
    [System.Collections.Generic.List[object]]$Codes
    [bool]$Running = $false
    [int]$UpdateInterval = 30
    [System.Timers.Timer]$Timer
    hidden [int]$MaxSeedWidth = 0
    hidden [int]$MaxCodeWidth = 0
    hidden [int]$MaxAlgoWidth = 0
    hidden [int]$MaxHashWidth = 0
    hidden [int]$LastUpdateTime = 0
    hidden [object]$SyncRoot = [System.Object]::new()

    ConsoleUI() {
        $this.Codes = [System.Collections.Generic.List[object]]::new()
        $this.Timer = [System.Timers.Timer]::new()
        $this.Timer.Interval = 1000 # 1 second
        
        # Use synchronized timer event to avoid cross-thread issues
        $this.Timer.Add_Elapsed({
            if (-not $this.Running) { return }
            
            # Synchronize timer updates to avoid multiple simultaneous updates
            [System.Threading.Monitor]::Enter($this.SyncRoot)
            try {
                $this.UpdateTimerDisplay()
            }
            finally {
                [System.Threading.Monitor]::Exit($this.SyncRoot)
            }
        })
    }

    hidden [void]UpdateColumnWidths() {
        $this.MaxSeedWidth = 0
        $this.MaxCodeWidth = 0
        $this.MaxAlgoWidth = 0
        $this.MaxHashWidth = 0

        foreach ($code in $this.Codes) {
            $this.MaxSeedWidth = [Math]::Max($this.MaxSeedWidth, $code.Seed.Length)
            $this.MaxCodeWidth = [Math]::Max($this.MaxCodeWidth, $code.Code.Length)
            $this.MaxAlgoWidth = [Math]::Max($this.MaxAlgoWidth, $code.Algorithm.Length)
            $this.MaxHashWidth = [Math]::Max($this.MaxHashWidth, $code.HashAlgorithm.Length)
        }
    }

    hidden [int]GetRemainingSeconds() {
        # Calculate remaining seconds until next 30-second interval
        $unixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        return 30 - ($unixTime % 30)
    }

    hidden [void]UpdateTimerDisplay() {
        try {
            # Check if we need to update based on time
            $currentTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            if (($currentTime - $this.LastUpdateTime) -lt 1) { return }
            $this.LastUpdateTime = $currentTime

            # Save current cursor position
            $currentTop = [System.Console]::CursorTop
            $currentLeft = [System.Console]::CursorLeft
            
            # Move to the last line
            [System.Console]::SetCursorPosition(0, [System.Console]::WindowTop + [System.Console]::WindowHeight - 1)
            
            # Get remaining seconds and check if we need to update codes
            $remainingSeconds = $this.GetRemainingSeconds()
            if ($remainingSeconds -eq 30) {
                $this.UpdateDisplay($true)
            } else {
                # Update timer display
                $timerLine = "Next update in: $remainingSeconds seconds"
                Write-Host $timerLine.PadRight([Console]::WindowWidth - 1) -NoNewline -ForegroundColor Green
            }
            
            # Restore cursor position
            [System.Console]::SetCursorPosition($currentLeft, $currentTop)
        }
        catch {
            # Ignore any console errors
        }
    }

    [void]ShowCodes() {
        $this.Running = $true
        $this.UpdateColumnWidths()
        $this.UpdateDisplay($true)
        $this.Timer.Start()
        
        try {
            while ($this.Running) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq [ConsoleKey]::Q) {
                        $this.Running = $false
                    }
                    elseif ($key.Key -eq [ConsoleKey]::R) {
                        $this.UpdateDisplay($true)
                    }
                }
                Start-Sleep -Milliseconds 100
            }
        }
        finally {
            $this.Timer.Stop()
        }
    }

    [void]UpdateDisplay([bool]$force) {
        if (-not $this.Running) { return }
        
        Clear-Host
        Write-Host "One-Time Password Codes`n" -ForegroundColor Cyan
        Write-Host "Press 'Q' to quit, 'R' to refresh`n" -ForegroundColor Yellow
        
        # Header
        Write-Host "Tag".PadRight(20) -NoNewline -ForegroundColor DarkGray
        Write-Host "Code".PadRight($this.MaxCodeWidth + 2) -NoNewline -ForegroundColor DarkGray
        Write-Host "Algorithm".PadRight($this.MaxAlgoWidth + 2) -NoNewline -ForegroundColor DarkGray
        Write-Host "Hash".PadRight($this.MaxHashWidth + 2) -NoNewline -ForegroundColor DarkGray
        Write-Host "Seed" -ForegroundColor DarkGray
        Write-Host ("-" * ([Console]::WindowWidth - 1)) -ForegroundColor DarkGray

        foreach ($code in $this.Codes) {
            # Tag with fixed width
            $tag = if ($code.Tag) { "[$($code.Tag -join ', ')] " } else { "" }
            Write-Host $tag.PadRight(20) -NoNewline -ForegroundColor Blue

            # Code with fixed width
            Write-Host $code.Code.PadRight($this.MaxCodeWidth + 2) -NoNewline -ForegroundColor White

            # Algorithm and Hash with fixed width
            Write-Host $code.Algorithm.PadRight($this.MaxAlgoWidth + 2) -NoNewline -ForegroundColor Gray
            Write-Host $code.HashAlgorithm.PadRight($this.MaxHashWidth + 2) -NoNewline -ForegroundColor Gray

            # Show full seed
            Write-Host $code.Seed -ForegroundColor Gray
        }

        Write-Host "`nNext update in: $($this.GetRemainingSeconds()) seconds" -NoNewline -ForegroundColor Green
    }

    [void]AddCode([object]$code) {
        # Validate code object
        if (-not $code.Seed -or -not $code.Code -or -not $code.Algorithm) {
            throw [System.ArgumentException]::new("Invalid code object. Missing required properties.")
        }
        $this.Codes.Add($code)
        $this.UpdateColumnWidths()
    }

    [void]Dispose() {
        $this.Running = $false
        if ($this.Timer) {
            $this.Timer.Stop()
            $this.Timer.Dispose()
        }
        # Clear sensitive data
        foreach ($code in $this.Codes) {
            $code.Seed = $null
            $code.Code = $null
        }
        $this.Codes.Clear()
    }
}

function New-OTPUI {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ForceConsole
    )

    # If ForceConsole is specified, always use console UI
    if ($ForceConsole) {
        Write-Verbose "Using console UI as requested"
        return [ConsoleUI]::new()
    }

    # Check platform
    $isWindows = $PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows -or 
                 $PSVersionTable.PSVersion.Major -lt 6 -and $true

    if ($isWindows) {
        $wpfUI = Initialize-OTPUI
        if ($wpfUI) {
            return $wpfUI
        }
    }
    
    # Fall back to console UI if WPF is not available or not on Windows
    return [ConsoleUI]::new()
} 
