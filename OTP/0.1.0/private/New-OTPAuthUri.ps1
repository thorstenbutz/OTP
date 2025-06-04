# New-OTPAuthUri.ps1
<#
.SYNOPSIS
    Creates a new otpauth:// URI.
.DESCRIPTION
    This cmdlet generates a valid otpauth:// URI that can be used with authenticator apps.
    It supports both TOTP and HOTP configurations and allows customization of all relevant parameters.
    The generated URI follows the Google Authenticator Key URI Format specification.

    The function provides:
    - Full RFC compliance for URI generation
    - Support for both TOTP and HOTP
    - Customizable security parameters
    - Input validation for all parameters
    - URI encoding of special characters
    - Default values aligned with industry standards

    Generated URIs are compatible with:
    - Google Authenticator
    - Microsoft Authenticator
    - Authy
    - Other RFC-compliant authenticator apps
.PARAMETER Type
    The type of OTP to configure. Valid values are:
    - 'totp' (Time-based) - Generates codes based on current time
    - 'hotp' (Counter-based) - Generates codes based on counter value
.PARAMETER Issuer
    The organization or service name (e.g., 'Microsoft', 'Google', 'GitHub').
    This helps users identify the account in their authenticator app.
    Will be URI-encoded in the output.
.PARAMETER Account
    The account identifier (e.g., email address, username).
    This can be just the account name or already include an issuer prefix (issuer:account).
    Will be URI-encoded in the output.
.PARAMETER Seed
    The Base32 encoded secret key. If not provided, a new one will be generated.
    Must be at least 16 characters long (80 bits).
    Must contain only characters A-Z, 2-7 and optionally padding with =.
.PARAMETER Algorithm
    The hash algorithm to use. Valid values are:
    - 'SHA1' (default) - Widely supported, but SHA256/512 recommended
    - 'SHA256' - Recommended for new implementations
    - 'SHA512' - Highest security level
.PARAMETER Digits
    The number of digits in the generated OTP code. Valid values:
    - 6 (default) - Standard length, widely supported
    - 7 - Extended length for more security
    - 8 - Maximum length, highest security
.PARAMETER Period
    For TOTP only: The time step in seconds. Default is 30.
    Valid range: 15-60 seconds
    Note: Most authenticator apps expect 30 seconds
.PARAMETER Counter
    For HOTP only: The initial counter value. Default is 0.
    Must be a non-negative integer.
    Should be incremented for each code generation.
.EXAMPLE
    New-OTPAuthUri -Type totp -Issuer 'Contoso' -Account 'alice@contoso.com' | New-OTPQRCode -OutFile 'qr.png'
    Creates a new TOTP URI and generates a QR code for it.
.EXAMPLE
    $uri = New-OTPAuthUri -Type hotp -Issuer 'MyApp' -Account 'bob' -Algorithm SHA256 -Digits 8
    $uri | New-OTPQRCode
    Creates an HOTP URI with SHA256 and 8 digits, then generates a QR code.
.EXAMPLE
    New-OTPAuthUri -Type totp -Account 'Contoso:alice@contoso.com' -Issuer 'Contoso'
    Creates a URI where the account already includes the issuer prefix.
.NOTES
    The function follows the Google Authenticator Key URI Format specification
    and implements all security recommendations from RFC 4226 and RFC 6238.
    
    If the Account parameter already contains an issuer prefix (contains a colon),
    it will be used as-is. Otherwise, the Issuer will be prepended if provided.
    
    Security considerations:
    - Use SHA256 or SHA512 for new implementations
    - Consider using 8 digits for enhanced security
    - Keep seeds secure and never share them
    - Use unique seeds for each account
.LINK
    https://github.com/google/google-authenticator/wiki/Key-Uri-Format
    https://tools.ietf.org/html/rfc4226
    https://tools.ietf.org/html/rfc6238
    https://github.com/thorstenbutz/otp
#>
function New-OTPAuthUri {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('totp', 'hotp')]
        [string]$Type,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Issuer,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Account,

        [Parameter()]
        [ValidatePattern('^[A-Z2-7=]*$')]
        [string]$Seed,

        [Parameter()]
        [ValidateSet('SHA1', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA1',

        [Parameter()]
        [ValidateRange(6, 8)]
        [int]$Digits = 6,

        [Parameter()]
        [ValidateRange(15, 60)]
        [int]$Period = 30,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$Counter = 0
    )

    try {
        # Generate seed if not provided
        if (-not $Seed) {
            $seedObj = New-OTPSecret
            $Seed = $seedObj.Seed
        }

        # Build the label - use Account as-is if it already contains issuer prefix
        if ($Account -like '*:*' -or -not $Issuer) {
            $label = [Uri]::EscapeDataString($Account)
        } else {
            $label = "$([Uri]::EscapeDataString($Issuer)):$([Uri]::EscapeDataString($Account))"
        }

        # Build the URI - ensure type is lowercase per otpauth standard
        $uri = "otpauth://$($Type.ToLower())/$label"
        
        # Build query parameters
        $params = [System.Collections.ArrayList]::new()
        [void]$params.Add("secret=$Seed")
        
        if ($Issuer) {
            [void]$params.Add("issuer=$([Uri]::EscapeDataString($Issuer))")
        }
        
        if ($Algorithm -ne 'SHA1') {
            [void]$params.Add("algorithm=$Algorithm")
        }
        
        if ($Digits -ne 6) {
            [void]$params.Add("digits=$Digits")
        }
        
        if ($Type -eq 'totp' -and $Period -ne 30) {
            [void]$params.Add("period=$Period")
        }
        
        if ($Type -eq 'hotp') {
            [void]$params.Add("counter=$Counter")
        }

        # Combine URI with parameters
        $uri = "$uri`?$($params -join '&')"

        if ($VerbosePreference -eq 'Continue') {
            Write-Verbose "Generated $Type configuration for $Account"
            Write-Verbose "Using algorithm: $Algorithm"
            Write-Verbose "URI length: $($uri.Length) characters"
        }

        # Return both the URI and the configuration details
        [PSCustomObject]@{
            Uri = $uri
            Type = $Type
            Issuer = $Issuer
            Account = $Account
            Seed = $Seed
            Algorithm = $Algorithm
            Digits = $Digits
            Period = if ($Type -eq 'totp') { $Period } else { $null }
            Counter = if ($Type -eq 'hotp') { $Counter } else { $null }
            PSTypeName = 'OTP.Configuration'
        }
    }
    catch {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $_.Exception,
            'ConfigurationError',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
        Write-Error -ErrorRecord $errorRecord
    }
} 