function Check-FileCompliance {
    param (
        [string]$ConfigPath
    )

    # Load JSON configuration
    $config = Get-Content -Path $ConfigPath | ConvertFrom-Json

    # Get the current date and time
    $currentTime = Get-Date

    # Threshold in minutes from the config
    $thresholdMinutes = $config.ThresholdMinutes

    # Array to hold out-of-compliance file details
    $outOfComplianceFiles = @()

    # Iterate through each remote path specified in the config
    foreach ($remotePath in $config.RemotePaths) {
        # Extract server name and base path from the remote path
        $serverName = ($remotePath -split '\\')[2]
        $basePath = $remotePath -replace "\\\\$serverName", ""

        # Get all files in the directory
        $files = Get-ChildItem -Path $remotePath -Recurse -File -ErrorAction SilentlyContinue

        # Check each file's creation date
        foreach ($file in $files) {
            $fileAgeMinutes = ($currentTime - $file.CreationTime).TotalMinutes
            if ($fileAgeMinutes -gt $thresholdMinutes) {
                # Create the file path relative to the remote server
                $relativePath = ($file.FullName -replace "^\\\\$serverName\\", "")

                $outOfComplianceFiles += [PSCustomObject]@{
                    ServerName    = $serverName
                    FullDirectory = $relativePath
                    CreationDate  = $file.CreationTime
                    FileSize      = [math]::Round($file.Length / 1MB, 2)
                }
            }
        }
    }

    # Send email if there are files out of compliance
    if ($outOfComplianceFiles.Count -gt 0) {
        # Construct the body of the email
        $body = "$($config.ComplianceMessage)`n`n"
        $body += $outOfComplianceFiles | Format-Table -AutoSize | Out-String

        # Prepare the log file attachment path
        $logFilePath = (Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "Log.Log")

        # Send the email
        $emailParams = @{
            From       = $config.EmailFrom
            To         = $config.EmailTo
            Subject    = $config.EmailSubject
            Body       = $body
            BodyAsHtml = $false
            SmtpServer = $config.SMTPServer
        }

        if (Test-Path $logFilePath) {
            $emailParams.Add("Attachments", $logFilePath)
        }

        Send-MailMessage @emailParams
    }
}

# Example usage for running as a scheduled task
$ConfigPath = "C:\Path\To\config.json"
Check-FileCompliance -ConfigPath $ConfigPath
