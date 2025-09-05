# Get-OTPCode.ps1
<#
.SYNOPSIS
    Generates One-Time Password (OTP) codes.
.DESCRIPTION
    This cmdlet generates TOTP (Time-based One-Time Password) or HOTP (HMAC-based One-Time Password)
    codes using a provided seed value. It supports both time-based and counter-based algorithms
    and different hash algorithms (SHA1, SHA256, SHA512).

    The function supports caching of decoded seeds for improved performance with TOTP codes,
    and provides both console and GUI interfaces for code generation.

    Security Note:
    - SHA1 is supported for compatibility but SHA256 or SHA512 are recommended
    - Minimum seed length is 16 Base32 characters (80 bits) for basic security
    - Seeds should be kept secure and never shared

    The Get-OTPCode function generates Time-based (TOTP) or HMAC-based (HOTP)
    one-time password codes using the provided secret key. It supports various
    hash algorithms and can display codes in a user-friendly interface.

    Features:
    - Supports both TOTP and HOTP algorithms
    - Multiple hash algorithms (SHA1, SHA256, SHA512)
    - Configurable code length (6-8 digits)
    - Optional console or GUI display
    - Tag-based organization
    - Pipeline support for batch processing
    - QR code integration

    The generated codes are compatible with common authenticator apps and
    follow RFC 4226 (HOTP) and RFC 6238 (TOTP) specifications.

.PARAMETER Seed
    The Base32 encoded secret key used to generate the OTP code.
    Minimum recommended length is 16 characters (80 bits).
    Must contain only characters A-Z, 2-7 and optionally padding with =.
.PARAMETER Algorithm
    The OTP algorithm to use. Valid values are 'TOTP' (default) and 'HOTP'.
    - TOTP: Time-based OTP, generates codes based on current time
    - HOTP: Counter-based OTP, generates codes based on counter value
.PARAMETER Counter
    The counter value for HOTP algorithm. Must be a non-negative integer. Ignored for TOTP.
    Each code generation should increment this value.
.PARAMETER HashAlgorithm
    The hash algorithm to use. Valid values are:
    - SHA1 (default, 160 bits) - Supported for compatibility
    - SHA256 (256 bits, more secure) - Recommended
    - SHA512 (512 bits, most secure) - Recommended for high security
.PARAMETER ShowUI
    Switch parameter to display a WPF window with live OTP updates.
    Provides a graphical interface with auto-updating TOTP codes.
.PARAMETER ForceConsole
    Switch parameter to force using console-based output even when WPF UI is available.
    Useful in environments where GUI is not desired or available.
.PARAMETER Tag
    Optional tag to filter OTP codes.
    Accepts input from pipeline by property name.
.PARAMETER Path
    Path to the QR code image file.
    Accepts input from pipeline by property name.
    This parameter is hidden from autocompletion.
.PARAMETER IncludePath
    Switch to include the Path value in the Tag array.
    When used with -Path, the path will be added as a tag.
.EXAMPLE
    New-OTPSecret | Get-OTPCode
    Generates a new random seed and gets its current OTP code.
.EXAMPLE
    Get-OTPCode -Seed 'JBSWY3DPEHPK3PXP' -Algorithm 'HOTP' -Counter 1
    Generates an HOTP code using a specific seed and counter.
.EXAMPLE
    Get-OTPCode -Seed 'JBSWY3DPEHPK3PXP' -ShowUI -ForceConsole
    Generates a TOTP code and displays it in the console interface, even on Windows.
.EXAMPLE
    Get-OTPCode -Seed 'JBSWY3DPEHPK3PXP' -HashAlgorithm SHA256
    Generates a TOTP code using SHA256 for increased security.
.EXAMPLE
    Get-OTPCode -Tag 'Work'
    Gets OTP codes for all work-related accounts.
.EXAMPLE
    $config = Read-OTPQRCode -Path 'qrcode.png'
    $config | Get-OTPCode
    Gets OTP code for a configuration from a QR code.
.NOTES
    The module uses secure random number generation and follows RFC 4226 (HOTP)
    and RFC 6238 (TOTP) specifications. It provides secure seed handling and
    supports modern hash algorithms for enhanced security.

    This version of the cmdlet was created using "Educated Prompting" by using Claude 3.5 Sonnect (by Anthropic) and Anysphere (cursor.sh).
.LINK
    https://tools.ietf.org/html/rfc4226
    https://tools.ietf.org/html/rfc6238
    https://github.com/thorstenbutz/otp
#>
function Get-OTPCode {
    [CmdletBinding()]
    [Alias('gotp')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Seed,
        
        [Parameter()]
        [ValidateSet('TOTP', 'HOTP')]
        [string]$Algorithm = 'TOTP',
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Counter = 0,
        
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet('SHA1', 'SHA256', 'SHA512')]
        [string]$HashAlgorithm = 'SHA1',

        [Parameter()]
        [switch]$ShowUI,

        [Parameter()]
        [switch]$ForceConsole,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Tag,

        [Parameter(ValueFromPipelineByPropertyName)]
        [System.Management.Automation.HiddenAttribute()]
        [string]$Path,

        [Parameter()]
        [switch]$IncludePath
    )
    
    begin {
        # Cache for decoded Base32 seeds to improve performance
        $script:seedCache = @{}
        
        # Only show warning if SHA1 was explicitly chosen
        if ($PSBoundParameters.ContainsKey('HashAlgorithm') -and $HashAlgorithm -eq 'SHA1') {
            Write-Warning -Message 'SHA1 was explicitly selected. Consider using SHA256 or SHA512 for increased security.'
        }

        # Initialize UI if requested
        if ($ShowUI -or $ForceConsole) {
            $script:ui = New-OTPUI -ForceConsole:$ForceConsole
            if (-not $script:ui) {
                $ShowUI = $false
                $ForceConsole = $false
                return
            }
        }
    }
    
    process {
        foreach ($secretKey in $Seed) {
            try {
                # Convert to uppercase before validation
                $secretKey = $secretKey.ToUpperInvariant()

                # Add Path to Tag array if provided and IncludePath is specified
                $currentTags = @()
                if ($Tag) {
                    $currentTags += $Tag
                }
                if ($PSBoundParameters.ContainsKey('Path') -and $IncludePath) {
                    $currentTags += $Path
                }

                # Enhanced Base32 validation with specific error messages
                if ([string]::IsNullOrWhiteSpace($secretKey)) {
                    throw [System.ArgumentException]::new(
                        'Seed cannot be empty or whitespace.',
                        'Seed'
                    )
                }
                
                if (-not [regex]::IsMatch($secretKey, '^[A-Z2-7=]*$')) {
                    throw [System.ArgumentException]::new(
                        'Invalid Base32 encoding in seed. Found invalid characters. Only A-Z, 2-7, and = are allowed.',
                        'Seed'
                    )
                }

                # Check seed length (minimum 16 bytes for security)
                $decodedLength = [Math]::Floor($secretKey.Replace('=', '').Length * 5 / 8)
                $warningMessage = "Seed length ($decodedLength bytes after Base32 decoding) is less than recommended minimum of 10 bytes. This may compromise security."
                if ($secretKey.Replace('=', '').Length -lt 16) {  # Check Base32 character length directly
                    Write-Warning $warningMessage
                }

                if ($VerbosePreference -eq 'Continue') {
                    Write-Verbose "Processing seed: $secretKey"
                    if ($Tag) {
                        Write-Verbose "Tags: $($Tag -join ', ')"
                    }
                }

                # Use cached decoded bytes if available
                $secretBytes = $null
                $cacheKey = "${secretKey}_${HashAlgorithm}"
                
                if (-not $script:seedCache.ContainsKey($cacheKey)) {
                    try {
                        $secretBytes = [OtpNet.Base32Encoding]::ToBytes($secretKey)
                        # Only cache for TOTP as it's reused
                        if ($Algorithm -eq 'TOTP') {
                            $script:seedCache[$cacheKey] = $secretBytes
                        }
                    }
                    catch {
                        throw [System.ArgumentException]::new(
                            "Failed to decode Base32 seed: $($_.Exception.Message)",
                            'Seed',
                            $_.Exception
                        )
                    }
                }
                else {
                    $secretBytes = $script:seedCache[$cacheKey]
                }
                
                switch ($Algorithm) {
                    'TOTP' {
                        try {
                            $otp = [OtpNet.Totp]::new($secretBytes, 30, [OtpNet.OtpHashMode]::$HashAlgorithm)
                            $code = $otp.ComputeTotp()
                            
                            if ($VerbosePreference -eq 'Continue') {
                                $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                                Write-Verbose "Current Unix timestamp: $timestamp"
                                Write-Verbose "Time step: 30 seconds"
                                Write-Verbose "Hash algorithm: $HashAlgorithm"
                            }
                        }
                        catch {
                            throw [System.Security.SecurityException]::new(
                                "Failed to compute TOTP code: $($_.Exception.Message)",
                                $_.Exception
                            )
                        }
                    }
                    'HOTP' {
                        try {
                            $otp = [OtpNet.Hotp]::new($secretBytes, [OtpNet.OtpHashMode]::$HashAlgorithm)
                            $code = $otp.ComputeHOTP($Counter)
                            
                            if ($VerbosePreference -eq 'Continue') {
                                Write-Verbose "Current counter value: $Counter"
                                Write-Verbose "Hash algorithm: $HashAlgorithm"
                            }
                        }
                        catch {
                            throw [System.Security.SecurityException]::new(
                                "Failed to compute HOTP code: $($_.Exception.Message)",
                                $_.Exception
                            )
                        }
                    }
                }
                
                $result = [PSCustomObject]@{
                    Code = $code
                    Algorithm = $Algorithm
                    HashAlgorithm = $HashAlgorithm
                    Seed = $secretKey
                    PSTypeName = 'OTP.Code'
                }

                # Add Tag property only if we have tags
                if ($currentTags.Count -gt 0) {
                    Add-Member -InputObject $result -MemberType NoteProperty -Name 'Tag' -Value $currentTags
                    if ($ShowUI -or $ForceConsole) {
                        Add-Member -InputObject $result -MemberType NoteProperty -Name 'TagDisplay' -Value ($currentTags -join ', ')
                    }
                }
                elseif ($ShowUI -or $ForceConsole) {
                    Add-Member -InputObject $result -MemberType NoteProperty -Name 'TagDisplay' -Value ''
                }

                if ($ShowUI -or $ForceConsole) {
                    $script:ui.AddCode($result)
                }
                else {
                    $result
                }
            }
            catch [System.ArgumentException] {
                Write-Error -ErrorRecord $_
            }
            catch [System.Security.SecurityException] {
                Write-Error -ErrorRecord $_
            }
            catch {
                $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                    $_.Exception,
                    'OTPGenerationError',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $secretKey
                )
                Write-Error -ErrorRecord $errorRecord
            }
        }
    }

    end {
        if (($ShowUI -or $ForceConsole) -and $script:ui) {
            try {
                $script:ui.ShowCodes()
            }
            finally {
                if ($script:ui -is [System.IDisposable]) {
                    $script:ui.Dispose()
                }
                $script:ui = $null
                # Clear the seed cache when done
                $script:seedCache.Clear()
            }
        }
    }
} 
