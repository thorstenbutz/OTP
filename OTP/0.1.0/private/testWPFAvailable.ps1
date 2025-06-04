function testWPFAvailable {
    <#
    .SYNOPSIS
        Checks if Windows Presentation Foundation (WPF) is available on the system.
    .DESCRIPTION
        Attempts to load required WPF assemblies and validates key WPF types.
        Returns $true if WPF is available, $false otherwise.
    #>
    
    $wpfAssemblies = @(
        'PresentationFramework',
        'PresentationCore',
        'WindowsBase',
        'System.Xaml'
    )
    
    try {
        foreach ($assembly in $wpfAssemblies) {
            Add-Type -AssemblyName $assembly -ErrorAction Stop
        }
        
        # Validate key WPF types
        $null = [System.Windows.Window]
        $null = [System.Windows.Markup.XamlReader]
        $null = [System.Windows.Threading.DispatcherTimer]
        
        $true
    }
    catch {
        Write-Verbose "WPF is not available: $_"
        $false
    }
} 