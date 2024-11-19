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
        # Extract server name from the remote path
        $serverName = ($remotePath -split '\\')[2]

        # Get all files in the directory
        $files = Get-ChildItem -Path $remotePath -Recurse -File -ErrorAction SilentlyContinue

        # Check each file's creation date
        foreach ($file in $files) {
            $fileAgeMinutes = ($currentTime - $file.CreationTime).TotalMinutes
            if ($fileAgeMinutes -gt $thresholdMinutes) {
                $outOfComplianceFiles += [PSCustomObject]@{
                    ServerName    = $serverName
                    FullDirectory = $file.FullName
                    CreationDate  = $file.CreationTime
                    FileSize      = [math]::Round($file.Length / 1MB, 2)
                }
            }
        }
    }

    # Send email if there are files out of compliance
    if ($outOfComplianceFiles.Count -gt 0) {
        $body = "$($config.ComplianceMessage)`n`n"
        $body += $outOfComplianceFiles | Format-Table -AutoSize | Out-String

        # Prepare the email parameters
        $smtpServer = $config.SMTPServer
        $smtpPort = $config.SMTPPort
        $smtpUser = $config.SMTPUser
        $smtpPassword = $config.SMTPPassword
        $emailTo = $config.EmailTo
        $emailFrom = $config.EmailFrom
        $emailSubject = $config.EmailSubject

        # Send the email
        $smtpClient = New-Object System.Net.Mail.SmtpClient($smtpServer, $smtpPort)
        $smtpClient.EnableSsl = $true
        $smtpClient.Credentials = New-Object System.Net.NetworkCredential($smtpUser, $smtpPassword)

        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = $emailFrom
        $mailMessage.To.Add($emailTo)
        $mailMessage.Subject = $emailSubject
        $mailMessage.Body = $body

        $smtpClient.Send($mailMessage)
    }
}

# Example usage for running as a scheduled task
$ConfigPath = "C:\Path\To\config.json"
Check-FileCompliance -ConfigPath $ConfigPath
