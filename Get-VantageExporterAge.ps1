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

    # Dictionary to hold out-of-compliance file details grouped by server
    $outOfComplianceFilesByServer = @{}

    # Iterate through each remote path specified in the config
    foreach ($remotePath in $config.RemotePaths) {
        # Extract server name and base path from the remote path
        $serverName = ($remotePath -split '\\')[2]
        $basePath = $remotePath -replace "\\\\$serverName", ""

        # Get all files in the directory
        $files = Get-ChildItem -Path $remotePath -Recurse -File -ErrorAction SilentlyContinue

        # Check each file's creation date
        foreach ($file in $files) {
            $fileCreationTime = [datetime]$file.CreationTime
            $fileAgeMinutes = ($currentTime - $fileCreationTime).TotalMinutes
            Write-Host "Checking file: $($file.FullName) - Age in minutes: $fileAgeMinutes"

            # Check if the file is older than the threshold
            if ($fileAgeMinutes -gt $thresholdMinutes) {
                Write-Host "File $($file.FullName) is out of compliance."

                # Create the file path relative to the remote server
                $relativePath = ($file.FullName -replace "^\\\\$serverName\\", "")

                # Replace any $ signs with : for drive letter replacement
                $relativePath = $relativePath -replace '\$', ':'

                # Check if the dictionary already has an entry for the server, otherwise initialize an empty list
                if (-not $outOfComplianceFilesByServer.ContainsKey($serverName)) {
                    $outOfComplianceFilesByServer[$serverName] = @()
                }

                # Append the current file to the server's list
                $outOfComplianceFilesByServer[$serverName] += [PSCustomObject]@{
                    FullDirectory = $relativePath
                    CreationDate  = $file.CreationTime
                    FileSize      = [math]::Round($file.Length / 1MB, 2)
                }

            } else {
                Write-Host "File $($file.FullName) is within the compliance threshold."
            }
        }
    }

    # Send email if there are files out of compliance
    if ($outOfComplianceFilesByServer.Count -gt 0) {
        # Construct the HTML body
        $body = "<html><body>"
        $body += "<h2>$($config.ComplianceMessage)</h2>"

        foreach ($serverName in $outOfComplianceFilesByServer.Keys) {
            $body += "<h3>Server: $serverName</h3>"

            # Get the first object's properties for table headers
            $properties = $outOfComplianceFilesByServer[$serverName][0].PSObject.Properties | ForEach-Object { $_.Name }

            # Create table header
            $body += "<table border='1' cellspacing='0' cellpadding='5'><tr>"
            foreach ($property in $properties) {
                $body += "<th>$property</th>"
            }
            $body += "</tr>"

            # Create table rows
            foreach ($file in $outOfComplianceFilesByServer[$serverName]) {
                $body += "<tr>"
                foreach ($property in $properties) {
                    $body += "<td>$($file.$property)</td>"
                }
                $body += "</tr>"
            }

            $body += "</table><br/>"
        }

        $body += "</body></html>"

        # Prepare the log file attachment path
        $logFilePath = (Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath "Log.Log")

        # Send the email
        $emailParams = @{
            From       = $config.EmailFrom
            To         = $config.EmailTo
            Subject    = $config.EmailSubject
            Body       = $body
            BodyAsHtml = $true
            SmtpServer = $config.SMTPServer
        }

        if (Test-Path $logFilePath) {
            $emailParams.Add("Attachments", $logFilePath)
        }

        Send-MailMessage @emailParams
    } else {
        Write-Host "No files were found to be out of compliance."
    }
}

# Example usage for running as a scheduled task
$ConfigPath = "$psscriptRoot\config.json"
Check-FileCompliance -ConfigPath $ConfigPath
