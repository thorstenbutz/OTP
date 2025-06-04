# Dot source private functions
$privatePath = Join-Path -Path $PSScriptRoot -ChildPath 'private'
if (Test-Path -Path $privatePath) {
    Get-ChildItem -Path $privatePath\*.ps1 | ForEach-Object {
        try {
            . $_.FullName
            Write-Verbose -Message ('Loaded private function: ' + $_.BaseName)
        }
        catch {
            Write-Error -Message ('Failed to load private function {0}: {1}' -f $_.BaseName, $_.Exception.Message)
        }
    }
}

# Dot source public functions
$publicPath = Join-Path -Path $PSScriptRoot -ChildPath 'public'
if (Test-Path -Path $publicPath) {
    Get-ChildItem -Path $publicPath\*.ps1 | ForEach-Object {
        try {
            . $_.FullName
            Write-Verbose -Message ('Loaded public function: ' + $_.BaseName)
        }
        catch {
            Write-Error -Message ('Failed to load public function {0}: {1}' -f $_.BaseName, $_.Exception.Message)
        }
    }
}

# Add required assemblies for WPF
$wpfAssemblies = @(
    'PresentationFramework',
    'PresentationCore',
    'WindowsBase',
    'System.Xaml'
)

foreach ($assembly in $wpfAssemblies) {
    try {
        Add-Type -AssemblyName $assembly -ErrorAction Stop
        Write-Verbose -Message ('Loaded WPF assembly: ' + $assembly)
    }
    catch {
        Write-Warning -Message ('Failed to load WPF assembly {0}: {1}' -f $assembly, $_.Exception.Message)
    }
}

# Create aliases
Set-Alias -Name 'gotp' -Value Get-OTPCode
Set-Alias -Name 'notp' -Value New-OTPSecret
Set-Alias -Name 'rotp' -Value Read-OTPQRCode


