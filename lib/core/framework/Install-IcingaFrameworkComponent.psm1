function Install-IcingaFrameworkComponent()
{
    param(
        [string]$Name,
        [string]$GitHubUser = 'Icinga',
        [string]$Url,
        [switch]$Stable     = $FALSE,
        [switch]$Snapshot   = $FALSE,
        [switch]$DryRun     = $FALSE
    );

    if ([string]::IsNullOrEmpty($Name)) {
        throw 'Please specify a component name to install from a GitHub/Local space';
    }

    $TextInfo       = (Get-Culture).TextInfo;
    $ComponentName  = $TextInfo.ToTitleCase($Name);
    $RepositoryName = [string]::Format('icinga-powershell-{0}', $Name);
    $Archive        = Get-IcingaPowerShellModuleArchive `
                        -DownloadUrl $Url `
                        -GitHubUser $GitHubUser `
                        -ModuleName (
                            [string]::Format(
                                'Icinga Component {0}', $ComponentName
                            )
                        ) `
                        -Repository $RepositoryName `
                        -Stable $Stable `
                        -Snapshot $Snapshot `
                        -DryRun $DryRun;

    if ($Archive.Installed -eq $FALSE -Or $DryRun) {
        return @{
            'RepoUrl' = $Archive.DownloadUrl
        };
    }

    Write-Host ([string]::Format('Installing module into "{0}"', ($Archive.Directory)));
    Expand-IcingaZipArchive -Path $Archive.Archive -Destination $Archive.Directory | Out-Null;

    $FolderContent = Get-ChildItem -Path $Archive.Directory;
    $ModuleContent = $Archive.Directory;

    foreach ($entry in $FolderContent) {
        if ($entry -like ([string]::Format('{0}*', $RepositoryName))) {
            $ModuleContent = Join-Path -Path $ModuleContent -ChildPath $entry;
            break;
        }
    }

    Write-Host ([string]::Format('Using content of folder "{0}" for updates', $ModuleContent));

    $PluginDirectory = (Join-Path -Path $Archive.ModuleRoot -ChildPath $RepositoryName);

    if ((Test-Path $PluginDirectory) -eq $FALSE) {
        Write-Host ([string]::Format('{0} Module Directory "{1}" is not present. Creating Directory', $ComponentName, $PluginDirectory));
        New-Item -Path $PluginDirectory -ItemType Directory | Out-Null;
    }

    Write-Host ([string]::Format('Copying files to {0}', $ComponentName));
    Copy-ItemSecure -Path (Join-Path -Path $ModuleContent -ChildPath '/*') -Destination $PluginDirectory -Recurse -Force | Out-Null;

    Write-Host 'Cleaning temporary content';
    Start-Sleep -Seconds 1;
    Remove-ItemSecure -Path $Archive.Directory -Recurse -Force | Out-Null;

    Unblock-IcingaPowerShellFiles -Path $PluginDirectory;

    # In case the plugins are not installed before, load the framework again to
    # include the plugins
    Use-Icinga;

    # Unload the module if it was loaded before
    Remove-Module $RepositoryName -Force -ErrorAction SilentlyContinue;
    # Now import the module
    Import-Module $RepositoryName;

    Write-Host ([string]::Format('Icinga component {0} update has been completed. Please start a new PowerShell to apply it', $ComponentName));

    return @{
        'RepoUrl' = $Archive.DownloadUrl
    };
}
