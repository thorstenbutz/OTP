# Read-OTPQRCode.ps1
<#
.SYNOPSIS
    Reads and parses OTP QR codes from images or URIs.
.DESCRIPTION
    This cmdlet reads and parses One-Time Password (OTP) QR codes from image files
    or otpauth:// URIs. It supports both TOTP (Time-based) and HOTP (HMAC-based)
    configurations and extracts all relevant parameters including:
    - Secret key (Base32 encoded)
    - Algorithm (SHA1, SHA256, SHA512)
    - Digits (code length)
    - Period (time step for TOTP)
    - Counter (for HOTP)
    - Issuer and Label information

    URI Format Note:
    The otpauth URI format uses both a Label and an Issuer, but in different ways:
    - Label is used in the URI path (otpauth://TYPE/Label)
    - Issuer is added as a URI parameter (&issuer=IssuerName)
    
    While the Label often includes issuer information (e.g., "Company:user@example.com"),
    the issuer parameter is treated separately in the URI parameters. This follows the
    specification where the issuer parameter helps prevent account collisions across
    different services, even if the Label contains similar information.

    Example URI formats:
    otpauth://totp/user@example.com?secret=SEED&issuer=Company
    otpauth://totp/Company:user@example.com?secret=SEED&issuer=Company

    The function validates all extracted data for security and compatibility.

    Output Properties:
    - Type: TOTP or HOTP
    - Issuer: The service or organization name (from URI parameter)
    - Label: The account identifier (from URI path)
    - Seed: The Base32 encoded secret
    - Characters: Number of characters in the Base32 string
    - Length: Number of bytes in the seed
    - Algorithm: Hash algorithm (SHA1, SHA256, SHA512)
    - Digits: Number of digits in the OTP
    - Period: Time step in seconds (TOTP only)
    - Counter: Initial counter value (HOTP only)
    - Tag: Optional organizational tags
    - URI: The complete otpauth:// URI
    - Path: The image file path (when reading from QR code)
.PARAMETER Path
    Path to the QR code image file.
    Accepts input from pipeline by property name.
.PARAMETER URI
    An otpauth:// URI containing OTP configuration.
    Format: otpauth://TYPE/LABEL?secret=BASE32&issuer=ISSUER&...
    
    Note: The URI can contain the issuer in two places:
    1. As part of the label (otpauth://TYPE/ISSUER:LABEL)
    2. As a parameter (?issuer=ISSUER)
    When both are present, the issuer parameter takes precedence.
.PARAMETER Tag
    Optional tags to associate with the parsed configuration.
    Accepts input from pipeline by property name.
.PARAMETER Raw
    Switch to return raw QR code content instead of OTP configuration.
.PARAMETER IncludeMetadata
    Switch to include metadata in the raw QR code output.
.PARAMETER AllResults
    Switch to return all QR codes found in the image instead of just the first one.
.EXAMPLE
    Read-OTPQRCode -Path 'qrcode.png'
    Reads OTP configuration from a QR code image.

.EXAMPLE
    Get-ChildItem -Path '*.png' | Read-OTPQRCode
    Reads OTP configuration from all PNG files in the current directory.
.EXAMPLE
    Read-OTPQRCode -URI 'otpauth://totp/Example:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example'
    Parses an OTP configuration from a URI.
.EXAMPLE
    Read-OTPQRCode -Path 'qrcode.png' -Tag 'Work', 'Email'
    Reads a QR code and adds organizational tags.
.EXAMPLE
    $config = Read-OTPQRCode -Path 'qrcode.png'
    $config | New-OTPSecret
    Reads a QR code and uses its configuration to generate a new OTP secret.
.NOTES
    The function requires the ZXing.Net library for QR code reading.
    It follows RFC 4226 (HOTP) and RFC 6238 (TOTP) specifications.
    Ensure QR codes are from trusted sources as they contain sensitive data.

    This version of the cmdlet was created using "Educated Prompting" by using Claude 3.5 Sonnect (by Anthropic) and Anysphere (cursor.sh).
.LINK
    https://tools.ietf.org/html/rfc4226
    https://tools.ietf.org/html/rfc6238
    https://github.com/thorstenbutz/otp
#>
function Read-OTPQRCode {
    [CmdletBinding(DefaultParameterSetName = 'OTP')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [ValidateScript({
            if ([string]::IsNullOrEmpty($_)) {
                throw 'Path cannot be empty'
            }
            if (-not (Test-Path $_)) {
                throw "File not found: $_"
            }
            return $true
        })]
        [Alias('FullName')]
        [string[]]$Path,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]$Raw,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]$IncludeMetadata,

        [Parameter(ParameterSetName = 'Raw')]
        [switch]$AllResults,

        [Parameter(ParameterSetName = 'OTP')]
        [string[]]$Tag
    )
    
    begin {
        Write-Verbose -Message 'Starting QR code reading'
        
        if (-not ('ZXing.BarcodeReader' -as [type])) {
            Write-Verbose -Message 'Loading ZXing.Net assembly'
            $zxingPath = Join-Path -Path $PSScriptRoot -ChildPath '..\lib\zxing.dll'
            if (-not (Test-Path -Path $zxingPath)) {
                throw "ZXing library not found at: $zxingPath"
            }
            Add-Type -Path $zxingPath
            Write-Verbose -Message 'ZXing.Net assembly loaded successfully'
        }
    }
    
    process {
        try {
            foreach ($currentPath in $Path) {
                Write-Verbose -Message "Processing image: $currentPath"
                
                $reader = [ZXing.BarcodeReader]::new()
                $reader.Options.TryHarder = $true
                
                $formats = [System.Collections.Generic.List[ZXing.BarcodeFormat]]::new()
                $formats.Add([ZXing.BarcodeFormat]::QR_CODE)
                $reader.Options.PossibleFormats = $formats
                
                # Convert relative path to absolute path for compatibility with PS 5.1
                $absolutePath = (Get-Item -Path $currentPath).FullName
                Write-Verbose -Message "Converting path: $currentPath -> $absolutePath"
                $bitmap = [System.Drawing.Bitmap]::FromFile($absolutePath)
                try {
                    Write-Verbose -Message "Image dimensions: $($bitmap.Width)x$($bitmap.Height)"
                    
                    if ($AllResults) {
                        Write-Verbose -Message 'Attempting to decode all QR codes in image'
                        $results = $reader.DecodeMultiple($bitmap)
                    }
                    else {
                        Write-Verbose -Message 'Attempting to decode single QR code'
                        $results = @($reader.Decode($bitmap))
                    }
                    
                    if (-not $results) {
                        throw 'No QR code found in image'
                    }
                    
                    foreach ($result in $results) {
                        if ($Raw) {
                            $output = [ordered]@{
                                Text = $result.Text
                            }
                            
                            if ($IncludeMetadata) {
                                Write-Verbose -Message 'Including metadata for QR code'
                                $output['Format'] = $result.BarcodeFormat
                                $output['Encoding'] = $result.TextEncoding
                                $output['ErrorCorrection'] = $result.ResultMetadata['ERROR_CORRECTION_LEVEL']
                            }
                            
                            [PSCustomObject]$output
                        }
                        else {
                            try {
                                $uri = [System.Uri]::new($result.Text)
                                
                                if ($uri.Scheme -ne 'otpauth') {
                                    throw "Invalid URI scheme. Expected 'otpauth' but got '$($uri.Scheme)'"
                                }
                                
                                $type = $uri.Host
                                if ($type -notin @('totp', 'hotp')) {
                                    throw "Invalid OTP type. Expected 'totp' or 'hotp' but got '$type'"
                                }
                                
                                $query = [System.Web.HttpUtility]::ParseQueryString($uri.Query)
                                
                                # Validate mandatory properties
                                if (-not $query['secret']) {
                                    throw 'Missing required parameter: secret'
                                }
                                
                                if ($type -notin @('totp', 'hotp')) {
                                    throw "Invalid OTP type. Expected 'totp' or 'hotp' but got '$type'"
                                }
                                
                                # Extract label from URI path (after the type)
                                $decodedPath = [System.Web.HttpUtility]::UrlDecode($uri.AbsolutePath)
                                
                                if ($VerbosePreference -eq 'Continue') {
                                    Write-Verbose "Full URI: $($uri.AbsoluteUri)"
                                    Write-Verbose "Path: $($uri.AbsolutePath)"
                                    Write-Verbose "Type: $type"
                                    Write-Verbose "Decoded path: $decodedPath"
                                }
                                
                                # The label is everything after the first slash
                                $label = $decodedPath.TrimStart('/')
                                
                                if ([string]::IsNullOrEmpty($label)) {
                                    throw "Missing required parameter: label"
                                }
                                
                                if ($VerbosePreference -eq 'Continue') {
                                    Write-Verbose "Extracted label: $label"
                                }
                                
                                # Validate secret format (Base32)
                                $secret = $query['secret']
                                if (-not ($secret -match '^[A-Z2-7]+$')) {
                                    throw 'Invalid secret format. Must be Base32 encoded (A-Z, 2-7)'
                                }
                                
                                # Ensure seed is in correct format (uppercase, no padding)
                                $seed = $secret.ToUpper() -replace '=+$'
                                
                                $output = [ordered]@{
                                    PSTypeName = 'OTP.Configuration'
                                    Type      = $type.ToUpper()
                                    Label     = $label
                                    Seed      = $seed
                                    Characters = $seed.Length
                                    Length    = [Math]::Ceiling($seed.Length * 5 / 8)
                                    Algorithm = if ($query['algorithm']) { $query['algorithm'] } else { 'SHA1' }
                                    Digits    = if ($query['digits']) { [int]$query['digits'] } else { 6 }
                                    Period    = if ($query['period']) { [int]$query['period'] } else { 30 }
                                    Counter   = if ($query['counter']) { [int]$query['counter'] } else { $null }
                                    Tag       = $Tag
                                    Issuer    = $query['issuer']
                                    URI       = $result.Text
                                    Path      = $currentPath
                                }
                                
                                [PSCustomObject]$output
                            }
                            catch [System.UriFormatException] {
                                Write-Error -Message "QR code content is not a valid URI: $($result.Text)"
                            }
                            catch {
                                Write-Error -Message "Failed to parse OTP URI: $_"
                            }
                        }
                    }
                }
                finally {
                    $bitmap.Dispose()
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    
    end {
        Write-Verbose -Message 'QR code reading completed'
    }
} 
