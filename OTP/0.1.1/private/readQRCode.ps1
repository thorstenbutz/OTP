function Test-QRCodeReading {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory,
                   ValueFromPipeline,
                   ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if ([string]::IsNullOrEmpty($_)) {
                throw "Path cannot be empty"
            }
            if (-not (Test-Path $_)) {
                throw "File not found: $_"
            }
            return $true
        })]
        [Alias('FullName')]
        [string]$Path,

        [Parameter()]
        [switch]$IncludeMetadata,

        [Parameter()]
        [switch]$AllResults
    )
    
    begin {
        Write-Verbose "Starting QR code reading test"
        
        # Load ZXing.Net assembly if not already loaded
        if (-not ('ZXing.BarcodeReader' -as [type])) {
            Write-Verbose "Loading ZXing.Net assembly"
            $zxingPath = Join-Path $PSScriptRoot '..\lib\zxing.dll'
            if (-not (Test-Path $zxingPath)) {
                throw "ZXing library not found at: $zxingPath"
            }
            Add-Type -Path $zxingPath
            Write-Verbose "ZXing.Net assembly loaded successfully"
        }
    }
    
    process {
        try {
            Write-Verbose "Processing image: $Path"
            
            # Create reader with options
            $reader = [ZXing.BarcodeReader]::new()
            $reader.Options.TryHarder = $true
            
            # Set QR code as the only format to look for
            $formats = [System.Collections.Generic.List[ZXing.BarcodeFormat]]::new()
            $formats.Add([ZXing.BarcodeFormat]::QR_CODE)
            $reader.Options.PossibleFormats = $formats
            
            # Read image file
            $bitmap = [System.Drawing.Bitmap]::FromFile($Path)
            try {
                Write-Verbose "Image dimensions: $($bitmap.Width)x$($bitmap.Height)"
                
                # Try to decode the QR code
                if ($AllResults) {
                    Write-Verbose "Attempting to decode all QR codes in image"
                    $results = $reader.DecodeMultiple($bitmap)
                }
                else {
                    Write-Verbose "Attempting to decode single QR code"
                    $results = @($reader.Decode($bitmap))
                }
                
                if (-not $results) {
                    throw "No QR code found in image"
                }
                
                # Process each result
                foreach ($result in $results) {
                    $output = [ordered]@{
                        Text = $result.Text
                    }
                    
                    if ($IncludeMetadata) {
                        Write-Verbose "Including metadata for QR code"
                        $output['Format'] = $result.BarcodeFormat
                        $output['Encoding'] = $result.TextEncoding
                        $output['ErrorCorrection'] = $result.ResultMetadata['ERROR_CORRECTION_LEVEL']
                    }
                    
                    [PSCustomObject]$output
                }
            }
            finally {
                $bitmap.Dispose()
            }
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    
    end {
        Write-Verbose "QR code reading test completed"
    }
}


