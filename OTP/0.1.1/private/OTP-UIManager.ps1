function Initialize-OTPUI {
    [CmdletBinding()]
    param()

    try {
        # Check if WPF is available
        if (-not (testWPFAvailable)) {
            Write-Warning "WPF UI is not available in this PowerShell environment. Falling back to console output."
            return $null
        }

        $script:codes = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
        
        # Load XAML from file
        $xamlPath = Join-Path $PSScriptRoot 'OTP-UI.xaml'
        if (-not (Test-Path $xamlPath)) {
            throw "XAML file not found: $xamlPath"
        }

        $xamlContent = Get-Content -Path $xamlPath -Raw
        $stream = [System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($xamlContent))
        
        try {
            # Parse XAML
            $script:window = [System.Windows.Markup.XamlReader]::Load($stream)
            
            # Find controls
            $script:codesGrid = $script:window.FindName('CodesGrid')
            $script:timerText = $script:window.FindName('TimerText')
            $script:refreshButton = $script:window.FindName('RefreshButton')

            # Initialize UI state
            $script:codesGrid.ItemsSource = $script:codes

            # Create WPF UI wrapper class
            $wpfUI = [PSCustomObject]@{
                PSTypeName = 'OTP.WPFUI'
                Window = $script:window
                Codes = $script:codes
                Timer = $script:countdownTimer
            }

            # Add methods
            $wpfUI | Add-Member -MemberType ScriptMethod -Name 'AddCode' -Value {
                param(
                    [Parameter(Mandatory)]
                    [object]$Code
                )
                $this.Codes.Add($Code)
            }

            $wpfUI | Add-Member -MemberType ScriptMethod -Name 'ShowCodes' -Value {
                $script:countdownTimer.Start()
                $null = $this.Window.ShowDialog()
            }

            $wpfUI | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value {
                if ($this.Timer) {
                    $this.Timer.Stop()
                }
                $this.Window = $null
                $this.Codes.Clear()
            }

            # Add refresh button click handler
            $script:refreshButton.Add_Click({
                Update-OTPDisplay -ResetTimer
            })

            # Create dispatcher timer
            $script:countdownTimer = New-Object System.Windows.Threading.DispatcherTimer -ErrorAction Stop
            $script:countdownTimer.Interval = [TimeSpan]::FromSeconds(1)
            
            # Timer tick handler
            $script:countdownTimer.Add_Tick({
                Update-OTPTimer
            })

            # Window closed handler
            $script:window.Add_Closed({
                if ($wpfUI) {
                    $wpfUI.Dispose()
                }
            })

            if ($VerbosePreference -eq 'Continue') {
                Write-Verbose "WPF UI initialized successfully"
            }

            return $wpfUI
        }
        finally {
            $stream.Dispose()
        }
    }
    catch {
        Write-Warning "Failed to initialize WPF UI: $_"
        Write-Warning "Falling back to console output."
        return $null
    }
}

function Update-OTPDisplay {
    [CmdletBinding()]
    param(
        [switch]$ResetTimer
    )

    try {
        if ($ResetTimer) {
            $script:timerText.Text = "30"
        }
        
        # Update codes and refresh UI
        $updatedCodes = @(updateOtpCodes -inputCodes $script:codes)
        if ($updatedCodes) {
            # Clear existing items and add new ones in batch
            $script:codes.Clear()
            foreach ($code in $updatedCodes) {
                $script:codes.Add($code)
            }

            if ($VerbosePreference -eq 'Continue') {
                Write-Verbose "Updated display with $($updatedCodes.Count) codes at $(Get-Date -Format 'HH:mm:ss')"
            }
        }
    }
    catch {
        Write-Warning "Failed to update display: $_"
    }
}

function Update-OTPTimer {
    try {
        # Calculate remaining seconds until next 30-second interval
        $unixTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $remainingSeconds = 30 - ($unixTime % 30)
        
        if ($remainingSeconds -eq 30) {
            Update-OTPDisplay
        }
        
        $script:timerText.Text = $remainingSeconds.ToString()
    }
    catch {
        Write-Warning "Failed to update timer: $_"
    }
}

function Cleanup-OTPUI {
    try {
        $script:countdownTimer.Stop()
        $script:window = $null
        $script:codes.Clear()
        [System.GC]::Collect()
    }
    catch {
        Write-Warning "Error during UI cleanup: $_"
    }
} 
