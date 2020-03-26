function Get-IcingaPowerShellModuleArchive()
{
    param(
        [string]$DownloadUrl = '',
        [string]$ModuleName  = '',
        [string]$Repository  = '',
        [string]$GitHubUser  = 'Icinga',
        [bool]$Stable        = $FALSE,
        [bool]$Snapshot      = $FALSE,
        [bool]$DryRun        = $FALSE
    );

    $ProgressPreference = "SilentlyContinue";
    $Tag                = 'master';
    [bool]$SkipRepo     = $FALSE;

    if ($Stable -Or $Snapshot) {
        $SkipRepo = $TRUE;
    }

    # Fix TLS errors while connecting to GitHub with old PowerShell versions
    [Net.ServicePointManager]::SecurityProtocol = "tls12, tls11";

    if ([string]::IsNullOrEmpty($DownloadUrl)) {
        if ($SkipRepo -Or (Get-IcingaAgentInstallerAnswerInput -Prompt ([string]::Format('Do you provide a custom repository for "{0}"?', $ModuleName)) -Default 'n').result -eq 1) {
            if ($Stable -eq $FALSE -And $Snapshot -eq $FALSE) {
                $branch = (Get-IcingaAgentInstallerAnswerInput -Prompt 'Which version to you want to install? (snapshot/stable)' -Default 'v' -DefaultInput 'stable').answer;
            } elseif ($Stable) {
                $branch = 'stable';
            } else {
                $branch = 'snapshot'
            }
            if ($branch.ToLower() -eq 'snapshot') {
                $DownloadUrl   = [string]::Format('https://github.com/{0}/{1}/archive/master.zip', $GitHubUser, $Repository);
            } else {
                try {
                    $LatestRelease = (Invoke-WebRequest -Uri ([string]::Format('https://github.com/{0}/{1}/releases/latest', $GitHubUser, $Repository)) -UseBasicParsing).BaseResponse.ResponseUri.AbsoluteUri;
                    $DownloadUrl   = $LatestRelease.Replace('/releases/tag/', '/archive/');
                    $Tag           = $DownloadUrl.Split('/')[-1];
                } catch {
                    Write-Host 'Failed to fetch latest release from GitHub. Either the module or the GitHub account do not exist';
                }

                $DownloadUrl   = [string]::Format('{0}/{1}.zip', $DownloadUrl, $Tag);

                $CurrentVersion = Get-IcingaPowerShellModuleVersion $Repository;

                if ($null -ne $CurrentVersion -And $CurrentVersion -eq $Tag) {
                    Write-Host ([string]::Format('Your "{0}" is already up-to-date', $ModuleName));
                    return @{
                        'DownloadUrl' = $DownloadUrl;
                        'Version'     = $Tag;
                        'Directory'   = '';
                        'Archive'     = '';
                        'ModuleRoot'  = (Get-IcingaFrameworkRootPath);
                        'Installed'   = $FALSE;
                    };
                }
            }
        } else {
            $DownloadUrl = (Get-IcingaAgentInstallerAnswerInput -Prompt ([string]::Format('Please enter the full Url to your "{0}" Zip-Archive', $ModuleName)) -Default 'v').answer;
        }
    }

    if ($DryRun) {
        return @{
            'DownloadUrl' = $DownloadUrl;
            'Version'     = $Tag;
            'Directory'   = '';
            'Archive'     = '';
            'ModuleRoot'  = (Get-IcingaFrameworkRootPath);
            'Installed'   = $FALSE;
        };
    }

    try {
        $DownloadDirectory   = New-IcingaTemporaryDirectory;
        $DownloadDestination = (Join-Path -Path $DownloadDirectory -ChildPath ([string]::Format('{0}.zip', $Repository)));
        Write-Host ([string]::Format('Downloading "{0}" into "{1}"', $ModuleName, $DownloadDirectory));

        Invoke-WebRequest -UseBasicParsing -Uri $DownloadUrl -OutFile $DownloadDestination;
    } catch {
        Write-Host ([string]::Format('Failed to download "{0}" into "{1}". Starting cleanup process', $ModuleName, $DownloadDirectory));
        Start-Sleep -Seconds 2;
        Remove-Item -Path $DownloadDirectory -Recurse -Force;

        Write-Host 'Starting to re-run the download wizard';

        return Get-IcingaPowerShellModuleArchive -ModuleName $ModuleName -Repository $Repository;
    }

    return @{
        'DownloadUrl' = $DownloadUrl;
        'Version'     = $Tag;
        'Directory'   = $DownloadDirectory;
        'Archive'     = $DownloadDestination;
        'ModuleRoot'  = (Get-IcingaFrameworkRootPath);
        'Installed'   = $TRUE;
    };
}
