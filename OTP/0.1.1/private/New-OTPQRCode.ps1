# New-OTPQRCode.ps1
<#
.SYNOPSIS
    Generates a QR code for OTP configuration.
.DESCRIPTION
    The New-OTPQRCode function generates a QR code image from an OTP configuration URI.
    It accepts input directly or through the pipeline from New-OTPSecret, allowing for easy
    creation of QR codes for TOTP/HOTP configurations. The generated QR code can be saved
    to a file, displayed directly, or both.

    Features:
    - Generates high-quality QR codes suitable for scanning
    - Supports both file output and byte array return
    - Validates URI format before generation
    - Customizable QR code size
    - Configurable error correction
    - Clean disposal of resources
    - Option to display the QR code immediately

    The generated QR codes are compatible with common authenticator apps:
    - Google Authenticator
    - Microsoft Authenticator
    - Authy
    - And other RFC-compliant authenticators

.PARAMETER Uri
    The OTP configuration URI to encode in the QR code. Must start with 'otpauth://'.
    This parameter accepts pipeline input from New-OTPSecret and other functions that output
    OTP configuration URIs.
.PARAMETER Size
    The size of the QR code image in pixels. Must be between 100 and 1000.
    Default value is 300 pixels.
.PARAMETER OutFile
    Optional path where the QR code image will be saved.
    If not specified, the QR code will be displayed in the default image viewer.
.PARAMETER Show
    If specified, displays the QR code in the default image viewer.
    This can be used with or without the OutFile parameter.
.EXAMPLE
    PS> New-OTPSecret | New-OTPQRCode -Show
    Generates a new OTP secret and displays the QR code.
.EXAMPLE
    PS> New-OTPSecret -Length 32 -Tag "MyApp" | New-OTPQRCode -Size 400 -OutFile "myapp_qr.png" -Show
    Creates a 32-character OTP secret with a tag, generates a 400x400 pixel QR code, saves it to myapp_qr.png, and displays it.
.EXAMPLE
    PS> $uri = "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
    PS> New-OTPQRCode -Uri $uri -Size 500 -Show
    Creates a 500x500 pixel QR code from a manually specified OTP URI and displays it.
.NOTES
    The function validates that the URI starts with 'otpauth://' to ensure compatibility
    with OTP authenticator apps. When using pipeline input from New-OTPSecret, the URI
    is automatically formatted correctly.

    Best practices:
    - Use PNG format for best quality
    - Size of 300-400 pixels works well on most devices
    - Ensure adequate contrast in the display environment
    - Test scanning with various authenticator apps
.LINK
    https://github.com/thorstenbutz/otp
    https://github.com/google/google-authenticator/wiki/Key-Uri-Format
#>
function New-OTPQRCode {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Save')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('OTPUri')]
        [string]$Uri,

        [Parameter()]
        [ValidateRange(100, 1000)]
        [int]$Size = 300,

        [Parameter(ParameterSetName = 'Save')]
        [Parameter(ParameterSetName = 'Show', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutFile,

        [Parameter(ParameterSetName = 'Save')]
        [Parameter(ParameterSetName = 'Show', Mandatory)]
        [switch]$Show
    )

    begin {
        Add-Type -AssemblyName System.Drawing
        $zxingPath = Join-Path -Path $PSScriptRoot -ChildPath '..\lib\zxing.dll'
        if (-not (Test-Path -Path $zxingPath)) {
            throw "Required ZXing.Net library not found at: $zxingPath"
        }
        Add-Type -Path $zxingPath
    }

    process {
        try {
            if (-not $Uri.StartsWith('otpauth://')) {
                throw 'Invalid OTP URI format. URI must start with ''otpauth://'''
            }

            Write-Verbose -Message "Generating QR code with size: ${Size}x${Size} pixels"
            Write-Verbose -Message "URI length: $($Uri.Length) characters"

            $barcodeWriter = [ZXing.BarcodeWriter]::new()
            $barcodeWriter.Format = [ZXing.BarcodeFormat]::QR_CODE
            
            $options = [ZXing.QrCode.QrCodeEncodingOptions]::new()
            $options.Height = $Size
            $options.Width = $Size
            $options.Margin = 2
            $options.ErrorCorrection = [ZXing.QrCode.Internal.ErrorCorrectionLevel]::M
            $options.CharacterSet = 'UTF-8'
            $options.DisableECI = $true
            $barcodeWriter.Options = $options

            $qrBitmap = $barcodeWriter.Write($Uri)

            # Save to file if OutFile is specified
            if ($OutFile) {
                ## Resolve the full path, handling both absolute and relative paths
                Write-Verbose "Original OutFile path: $OutFile"
                
                # Convert to absolute path if relative
                if (-not [System.IO.Path]::IsPathRooted($OutFile)) {
                    $OutFile = Join-Path -Path (Get-Location).Path -ChildPath $OutFile
                    Write-Verbose "Converted to absolute path: $OutFile"
                }
                
                # Ensure directory exists
                $directory = [System.IO.Path]::GetDirectoryName($OutFile)
                if (-not [string]::IsNullOrEmpty($directory)) {
                    if (-not (Test-Path -Path $directory)) {
                        Write-Verbose "Creating directory: $directory"
                        New-Item -ItemType Directory -Path $directory -Force | Out-Null
                    }
                }
                
                Write-Verbose "Final OutFile path: $OutFile"

                ## Check if file exists and prompt for overwrite confirmation
                $fileExists = Test-Path -Path $OutFile
                
                if ($fileExists) {
                    ## Check if confirmation was explicitly disabled
                    $skipConfirmation = ($PSBoundParameters.ContainsKey('Confirm') -and $PSBoundParameters['Confirm'] -eq $false)
                    
                    if (-not $skipConfirmation) {
                        ## Prompt for overwrite confirmation
                        $shouldOverwrite = $PSCmdlet.ShouldContinue(
                            "The file '$OutFile' already exists. Do you want to overwrite it?",
                            'Confirm Overwrite'
                        )
                        
                        if (-not $shouldOverwrite) {
                            Write-Verbose -Message "File overwrite cancelled by user: $OutFile"
                            return
                        }
                    }
                    else {
                        Write-Verbose -Message "Skipping overwrite confirmation due to -Confirm:`$false"
                    }
                }
                
                ## Proceed with file operation using ShouldProcess
                $actionMessage = if ($fileExists) { 'Overwrite existing QR code image' } else { 'Save QR code image' }
                
                if ($PSCmdlet.ShouldProcess($OutFile, $actionMessage)) {
                    $directory = [System.IO.Path]::GetDirectoryName($OutFile)
                    if (-not [string]::IsNullOrEmpty($directory) -and -not (Test-Path -Path $directory)) {
                        New-Item -ItemType Directory -Path $directory -Force | Out-Null
                    }

                    $imageFormat = [System.Drawing.Imaging.ImageFormat]::Png
                    $encoderParams = [System.Drawing.Imaging.EncoderParameters]::new(1)
                    $encoderParams.Param[0] = [System.Drawing.Imaging.EncoderParameter]::new(
                        [System.Drawing.Imaging.Encoder]::Quality,
                        [long]100
                    )

                    Write-Verbose "Attempting to save QR code to: $OutFile"
                    try {
                        $qrBitmap.Save($OutFile, $imageFormat)
                        Write-Verbose "Successfully saved QR code"
                    }
                    catch {
                        Write-Error "Failed to save QR code: $_"
                        Write-Error "Full path: $OutFile"
                        throw
                    }
                    
                    $verboseMessage = if ($fileExists) { "QR code overwritten at: $OutFile" } else { "QR code saved to: $OutFile" }
                    Write-Verbose -Message $verboseMessage

                    $outputFile = Get-Item -Path $OutFile
                    
                    # Display the QR code if Show is specified
                    if ($Show) {
                        Start-Process -FilePath $OutFile
                        Write-Verbose -Message "QR code displayed from: $OutFile"
                    }
                    
                    # Return the output file
                    $outputFile
                }
            }
        }
        catch {
            Write-Error -ErrorRecord $_
        }
        finally {
            if ($qrBitmap) {
                $qrBitmap.Dispose()
            }
            if ($encoderParams) {
                $encoderParams.Dispose()
            }
        }
    }
} 