## New-OTPSecret.ps1
<#
.SYNOPSIS
    Generates a secure OTP secret and complete otpauth URI.
.DESCRIPTION
    This cmdlet generates a secure OTP secret suitable for use with
    TOTP (Time-based One-Time Password) or HOTP (HMAC-based One-Time Password) algorithms.
    The output includes:
    - A cryptographically secure random secret (Base32 encoded)
    - A valid otpauth URI with all required components
    - Optional parameters for customization

    The function ensures:
    - Cryptographically secure random number generation
    - Appropriate secret length for security (minimum 80 bits/16 Base32 chars)
    - Proper Base32 encoding
    - Valid otpauth URI format with all required components

    URI Format:
    The otpauth URI format includes:
    - Type (lowercase totp/hotp)
    - Label (URL-encoded account identifier)
    - Secret (Base32 encoded)
    - Optional parameters (issuer, algorithm, digits, period, counter)

    Example URI format:
    otpauth://totp/otp%3amodule?secret=JBSWY3DPEHPK3PXP

    Security Note:
    - Default secret length is 10 bytes (80 bits) for basic security
    - Each byte provides 8 bits of entropy (randomness)
    - Entropy is a measure of unpredictability or randomness
    - Higher entropy means better security against brute-force attacks
    - Recommended minimum is 80 bits (10 bytes) of entropy
    - High-security applications should use 160 bits (20 bytes) or more

    Output Properties:
    - Type: TOTP or HOTP
    - Label: The account identifier
    - Seed: The Base32 encoded secret
    - Characters: Number of characters in the Base32 string
    - Length: Number of bytes (each byte provides 8 bits of entropy)
    - Algorithm: Hash algorithm (SHA1, SHA256, SHA512)
    - Digits: Number of digits in the OTP
    - Period: Time step in seconds (TOTP only)
    - Counter: Initial counter value (HOTP only)
    - Tag: Optional organizational tags
    - Issuer: The service or organization name
    - URI: The complete otpauth:// URI
.PARAMETER Length
    The length of the random seed in bytes before Base32 encoding.
    Default is 10 bytes (80 bits) which provides basic security.
    Each byte adds 8 bits of entropy.
    Examples:
    - 10 bytes = 80 bits of entropy (minimum recommended)
    - 15 bytes = 120 bits of entropy
    - 20 bytes = 160 bits of entropy (high security)
.PARAMETER Seed
    An existing Base32 encoded seed to use instead of generating a new one.
    Must contain only characters A-Z, 2-7 and optionally padding with =.
    If specified, the Length parameter is ignored.
.PARAMETER Padding
    Controls whether Base32 padding characters (=) are included in the output.
    Base32 encoding normally adds padding to ensure the output length is a multiple of 8.
    Some authenticator apps prefer or require the padding to be removed.
    The actual secret value remains the same with or without padding.
    Examples:
    - Without padding (default): JBSWY3DPEHPK3PXP6HY7
    - With padding (-Padding):   JBSWY3DPEHPK3PXP6HY7====
.PARAMETER Label
    The account identifier in the URI path.
    This can be any string that helps identify the account.
    Common formats include:
    - "user@example.com"
    - "username"
    - "Company:user@example.com"
    Note: Even if Label includes an issuer prefix, the -Issuer parameter
    is still used separately in the URI parameters.
.PARAMETER Issuer
    The service or organization name.
    This is added as an issuer parameter in the URI to prevent account collisions.
    The issuer parameter helps authenticator apps distinguish between accounts
    that might have similar labels but are for different services.
    Example: If Label is "user@example.com" and Issuer is "Company",
    the URI will be: otpauth://TYPE/user@example.com?...&issuer=Company
.PARAMETER Tag
    Optional tags to associate with the seed for organization.
    Useful when managing multiple OTP seeds.
    Accepts input from pipeline by property name.
.PARAMETER Algorithm
    The hash algorithm to use for OTP generation.
    Valid options are 'SHA1', 'SHA256', or 'SHA512'.
    Default is 'SHA1'.
.PARAMETER Type
    The type of OTP.
    Valid options are 'TOTP' or 'HOTP'.
    Default is 'TOTP'.
.PARAMETER Digits
    The number of digits in the generated OTP code.
    Default is 6 digits.
.PARAMETER Period
    The time step size in seconds for TOTP.
    Default is 30 seconds.
.PARAMETER Counter
    The initial counter value for HOTP.
    Required when Type is 'HOTP'.
.PARAMETER SaveQRCode
    The path to save the generated QR code image.
    If the file already exists, you will be prompted to confirm overwrite.
.PARAMETER ShowQRCode
    Switch to display the generated QR code image.
    Can only be used with SaveQRCode parameter.
.EXAMPLE
    New-OTPSecret
    Generates a new random seed with default settings:
    - Type: TOTP
    - Label: otp:module
    - Length: 10 bytes
    - Digits: 6
    - Period: 30 seconds
.EXAMPLE
    New-OTPSecret -Length 15
    Generates a medium-security seed with 120-bit length (15 bytes).
    All other settings use defaults.
.EXAMPLE
    New-OTPSecret -Length 20
    Generates a high-security seed with 160-bit length (20 bytes).
    All other settings use defaults.
.EXAMPLE
    New-OTPSecret -IncludePadding
    Generates a seed with Base32 padding characters.
    All other settings use defaults.
.EXAMPLE
    New-OTPSecret -Tag 'Work', 'Email'
    Generates a seed with associated tags.
    All other settings use defaults.
.EXAMPLE
    New-OTPSecret -Label 'Example:john.doe@email.com'
    Generates a seed with custom label.
    All other settings use defaults.
.EXAMPLE
    New-OTPSecret -Label 'Example:john.doe@email.com' -Type HOTP
    Generates a seed with custom label and HOTP type.
    All other settings use defaults.
.EXAMPLE
    $config = Read-OTPQRCode -Path 'qrcode.png'
    $config | New-OTPSecret
    Uses configuration from a QR code to generate a new OTP secret.
.EXAMPLE
    'JBSWY3DPEHPK3PXP' | New-OTPSecret
    Uses an existing Base32 encoded seed through pipeline by value.
.EXAMPLE
    @{ Seed = 'JBSWY3DPEHPK3PXP' } | New-OTPSecret
    Uses an existing Base32 encoded seed through pipeline by property name.
.EXAMPLE
    @{ Type = 'TOTP'; Length = 10; Label = 'test' } | New-OTPSecret
    Generates a new seed with specified properties through pipeline by property name.
.EXAMPLE
    New-OTPSecret -SaveQRCode 'C:\temp\qrcode.png' -ShowQRCode
    Generates a new seed and saves it as a QR code, then displays it.
    All other settings use defaults.
.EXAMPLE
    New-OTPSecret -SaveQRCode 'C:\temp\qrcode.png' -WhatIf
    Shows what would happen if the command were to run, including the path where the QR code would be saved.
.NOTES
    The function uses the cryptographically secure RNGCryptoServiceProvider
    for random number generation. The output is compatible with standard
    OTP implementations and follows RFC 4226 and RFC 6238 specifications.

    The cmdlet supports the -WhatIf parameter to preview operations without
    actually performing them. This is particularly useful when saving QR codes
    to see where files would be created or overwritten.

    This version of the cmdlet was created using "Educated Prompting" by using Claude 3.5 Sonnect (by Anthropic) and Anysphere (cursor.sh).
.LINK
    https://tools.ietf.org/html/rfc4648
    https://tools.ietf.org/html/rfc4226
    https://tools.ietf.org/html/rfc6238
    https://github.com/thorstenbutz/otp
#>
function New-OTPSecret {
    [CmdletBinding(DefaultParameterSetName = 'Generate', SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet('TOTP', 'HOTP')]
        [string]$Type = 'TOTP',

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Label = 'otp:module',

        ## Length of the random seed in bytes before Base32 encoding.
        ## Range 10-32 bytes (80-256 bits) based on security best practices:
        ## - 10 bytes (80 bits) is the minimum recommended for basic security
        ## - 32 bytes (256 bits) is a practical maximum for compatibility
        ## Note: While RFC 4226/6238 don't specify exact lengths, most authenticator
        ## apps expect seeds within this range. Larger seeds don't provide additional
        ## security with HMAC-SHA1 (160-bit output) but may cause compatibility issues.
        [Parameter(ParameterSetName = 'Generate', ValueFromPipelineByPropertyName)]
        [ValidateRange(10, 32)]
        [int]$Length = 10,

        [Parameter(ParameterSetName = 'UseSeed', ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [string]$Seed,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet('SHA1', 'SHA256', 'SHA512')]
        [string]$Algorithm = 'SHA1',

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateRange(6, 8)]
        [int]$Digits = 6,

        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateRange(15, 90)]
        [int]$Period = 30,

        [Parameter(ValueFromPipelineByPropertyName)]
        [long]$Counter,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Tag,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Issuer,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$IncludePadding,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$SaveQRCode,

        [Parameter(ValueFromPipelineByPropertyName)]
        [switch]$ShowQRCode
    )

    begin {
        ## Add ZXing assembly for QR code generation
        $zxingPath = Join-Path -Path $PSScriptRoot -ChildPath '..\lib\zxing.dll'
        if (-not (Test-Path -Path $zxingPath)) {
            throw 'Required ZXing.Net library not found at: ' + $zxingPath
        }
        Add-Type -Path $zxingPath
        Add-Type -AssemblyName System.Drawing
    }
    
    process {
        try {
            ## Validate HOTP counter
            if ($Type -eq 'HOTP' -and -not $Counter) {
                throw 'Counter parameter is required when Type is HOTP'
            }

            if ($Seed) {
                ## Clean up the seed by removing any padding and converting to uppercase
                $Seed = $Seed.ToUpper() -replace '=+$'
                if (-not ($Seed -match '^[A-Z2-7]+$')) {
                    throw 'Invalid seed format. Must be Base32 encoded (A-Z, 2-7)'
                }
                
                Write-Verbose -Message ('Processing existing seed: ' + $Seed)
                Write-Verbose -Message ('Seed length: ' + $Seed.Length + ' characters')
                
                $output = [ordered]@{
                    PSTypeName = 'OTP.Configuration'
                    Type      = $Type
                    Label     = $Label
                    Seed      = $Seed
                    Characters = $Seed.Length
                    Length    = [Math]::Ceiling($Seed.Length * 5 / 8)
                    Algorithm = $Algorithm
                    Digits    = $Digits
                    Period    = $Period
                    Counter   = if ($Type -eq 'HOTP') { $Counter } else { $null }
                    Tag       = $Tag
                    Issuer    = $Issuer
                }

                Write-Verbose -Message ('Calculated byte length: ' + $output.Length)
                
                ## Use New-OTPAuthUri to generate the URI
                $uriParams = @{
                    Type = $Type
                    Account = $Label
                    Seed = $Seed
                    Algorithm = $Algorithm
                    Digits = $Digits
                }
                
                if ($Issuer) { $uriParams['Issuer'] = $Issuer }
                if ($Period -ne 30) { $uriParams['Period'] = $Period }
                if ($Type -eq 'HOTP' -and $Counter -ne 0) { $uriParams['Counter'] = $Counter }
                
                $uriResult = New-OTPAuthUri @uriParams
                $output['URI'] = $uriResult.Uri

                ## Generate QR code if requested
                if ($SaveQRCode) {
                    if ($ShowQRCode -and -not $SaveQRCode) {
                        Write-Warning -Message 'ShowQRCode can only be used with SaveQRCode'
                        [PSCustomObject]$output
                    }

                    try {
                        $qrParams = @{
                            Uri = $uriResult.Uri
                            OutFile = $SaveQRCode
                            Show = $ShowQRCode
                        }
                        
                        ## Pass through the Confirm parameter if it was specified
                        if ($PSBoundParameters.ContainsKey('Confirm')) {
                            $qrParams['Confirm'] = $PSBoundParameters['Confirm']
                        }
                        
                        if ($PSCmdlet.ShouldProcess($SaveQRCode, 'Generate QR code')) {
                            $qrResult = New-OTPQRCode @qrParams
                            if ($qrResult) {
                                $output['QRCodePath'] = $qrResult.FullName
                            }
                        }
                    }
                    catch {
                        Write-Error -Message ('Failed to generate QR code: ' + $_)
                        Write-Error -Message ('Error details: ' + $_.Exception.Message)
                        if ($_.Exception.InnerException) {
                            Write-Error -Message ('Inner exception: ' + $_.Exception.InnerException.Message)
                        }
                    }
                }

                [PSCustomObject]$output
            }
            else {
                ## Generate a new random seed
                Write-Verbose -Message ('Generating new random seed with length: ' + $Length + ' bytes')
                
                ## Generate random bytes using RNGCryptoServiceProvider
                $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
                $bytes = [byte[]]::new($Length)
                
                try {
                    $rng.GetBytes($bytes)
                }
                finally {
                    $rng.Dispose()
                }
                
                $seed = [OtpNet.Base32Encoding]::ToString($bytes)
                if (-not $IncludePadding) {
                    $seed = $seed -replace '=+$'
                }
                
                Write-Verbose -Message ('Generated seed: ' + $seed)
                Write-Verbose -Message ('Seed length: ' + $seed.Length + ' characters')
                
                $output = [ordered]@{
                    PSTypeName = 'OTP.Configuration'
                    Type      = $Type
                    Label     = $Label
                    Seed      = $seed
                    Characters = $seed.Length
                    Length    = $Length
                    Algorithm = $Algorithm
                    Digits    = $Digits
                    Period    = $Period
                    Counter   = if ($Type -eq 'HOTP') { $Counter } else { $null }
                    Tag       = $Tag
                    Issuer    = $Issuer
                }

                Write-Verbose -Message ('Calculated byte length: ' + $output.Length)
                
                ## Use New-OTPAuthUri to generate the URI
                $uriParams = @{
                    Type = $Type
                    Account = $Label
                    Seed = $seed
                    Algorithm = $Algorithm
                    Digits = $Digits
                }
                
                if ($Issuer) { $uriParams['Issuer'] = $Issuer }
                if ($Period -ne 30) { $uriParams['Period'] = $Period }
                if ($Type -eq 'HOTP' -and $Counter -ne 0) { $uriParams['Counter'] = $Counter }
                
                $uriResult = New-OTPAuthUri @uriParams
                $output['URI'] = $uriResult.Uri

                ## Generate QR code if requested
                if ($SaveQRCode) {
                    if ($ShowQRCode -and -not $SaveQRCode) {
                        Write-Warning -Message 'ShowQRCode can only be used with SaveQRCode'
                        [PSCustomObject]$output
                    }

                    try {
                        $qrParams = @{
                            Uri = $uriResult.Uri
                            OutFile = $SaveQRCode
                            Show = $ShowQRCode
                        }
                        
                        ## Pass through the Confirm parameter if it was specified
                        if ($PSBoundParameters.ContainsKey('Confirm')) {
                            $qrParams['Confirm'] = $PSBoundParameters['Confirm']
                        }
                        
                        if ($PSCmdlet.ShouldProcess($SaveQRCode, 'Generate QR code')) {
                            $qrResult = New-OTPQRCode @qrParams
                            if ($qrResult) {
                                $output['QRCodePath'] = $qrResult.FullName
                            }
                        }
                    }
                    catch {
                        Write-Error -Message ('Failed to generate QR code: ' + $_)
                        Write-Error -Message ('Error details: ' + $_.Exception.Message)
                        if ($_.Exception.InnerException) {
                            Write-Error -Message ('Inner exception: ' + $_.Exception.InnerException.Message)
                        }
                    }
                }

                [PSCustomObject]$output
            }
        }
        catch {
            Write-Error -Message ('An error occurred: ' + $_)
            Write-Error -Message ('Error details: ' + $_.Exception.Message)
            if ($_.Exception.InnerException) {
                Write-Error -Message ('Inner exception: ' + $_.Exception.InnerException.Message)
            }
        }
    }
    
    end {
        if ($rng) {
            $rng.Dispose()
        }
    }
} 
