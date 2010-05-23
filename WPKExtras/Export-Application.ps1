function Export-Application
{
    <#
    .Synopsis
        Exports a PowerShell script into an executable
    .Description
        Embeds the specified script code into an execuable such that the executable can be run as a simple application which invokes the powershell script.
        This is merely a packaging convenience, as essentially the same effect can be achieved by running PowerShell with the -EncodedCommand parameter.
    .Example
        # Creates an .exe at the current path that runs digitalclock.ps1
        $clock = Get-Command $env:UserProfile\Documents\WindowsPowerShell\Modules\WPK\Examples\DigitalClock.ps1
        $clock | Export-Application 
    .Parameter Command
        The Command to turn into an application.
        The command should either be a function or an external script
    .Parameter Name
        The name of the .EXE to produce.  By default, the name will be the command name with an .EXE extension instead of a .PS1 extension
    .Parameter ReferencedAssemblies
        Additional Assemblies to Reference when compiling.
    .Parameter OutputPath
        If set, will output the executable into this path.
        By default, executables are outputted to the current directory.
    .Parameter TopModule
        The top level module to import.
        By default, this is the module that is exporting Export-Application
    #>
    param(
    [Parameter(ValueFromPipeline=$true)]
    [Management.Automation.CommandInfo]
    $Command,    
    [string]
    $Name,    
    [Reflection.Assembly[]]
    $ReferencedAssemblies = @(),
    [String]$OutputPath,
    [switch]$DoNotEmbed,
    [string]$TopModule = $myInvocation.MyCommand.ModuleName 
    ) 

    process {       
        $optimize = $true
        Set-StrictMode -Off
        if (-not $name) {
            $name = $command.Name
            if ($name -like "*.ps1") {
                $name = $name.Substring(0, $name.LastIndexOf("."))
            }
        }
        
        $referencedAssemblies+= [PSObject].Assembly
        $referencedAssemblies+= [Windows.Window].Assembly
        $referencedAssemblies+= [System.Windows.Threading.DispatcherFrame].Assembly
        $referencedAssemblies+= [System.Windows.Media.Brush].Assembly
        
        if (-not $outputPath)  {
            $outputPath = "$name.exe"
        }
        
        $initializeChunk = ""
        foreach ($r in $referencedAssemblies) {
            if ($r -notlike "*System.Management.Automation*") {
                $initializeChunk += "
          #      [Reflection.Assembly]::LoadFrom('$($r.Location)')
                "
            }
        }
        
        if ($optimize) {
            $iss = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
            $builtInCommandNames = $iss.Commands | 
                Where-Object { $_.ImplementingType } | 
                Select-Object -ExpandProperty Name         

            $aliases = @{}
            $outputChunk = "" 
            $command | 
                Get-ReferencedCommand | 
                ForEach-Object {
                    if ($_ -is [Management.Automation.AliasInfo]) {
                        $aliases.($_.Name) = $_.ResolvedCommand
                        $_.ResolvedCommand
                    }
                    $_        
                } | Foreach-Object {
                    if ($_ -is [Management.Automation.CmdletInfo]) {
                        if ($builtInCommandNames -notcontains $_.Name) {
                            $outputChunk+= "
                            Import-Module '$($_.ImplementingType.Assembly.Location)'
                            "
                        }
                    }
                    $_        
                } | ForEach-Object {
                    if ($_ -is [Management.Automation.FunctionInfo]) {
                        $outputChunk += "function $($_.Name) {
                            $($_.Definition)
                        }
                        "
                    }
                }
                
                $outputChunk += $aliases.GetEnumerator() | ForEach-Object {
                    "
                    Set-Alias $($_.Key) $($_.Value)
                    "
                }                
            $initializeChunk += $outputChunk
        } else {
            $initializeChunk += "
            Import-Module '$topModule'
            "
        }
        if (-not $DoNotEmbed) {
            if ($command.ScriptContents) {
                $base64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command.ScriptContents))
            } else {
                if ($command.Definition) {
                    $base64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command.Definition))
                }
            }
            $argsSection = @"
                sb.Append(System.Text.Encoding.Unicode.GetString(Convert.FromBase64String("$base64")));
"@        
        } else {
            $argsSection = @'
                if (args.Length == 2) {
                    if (String.Compare(args[0],"-encoded", true) == 0) {
                        sb.Append(System.Text.Encoding.Unicode.GetString(Convert.FromBase64String(args[1])));
                    }
                } else {
                    foreach (string a in args) {
                        sb.Append(a);
                        sb.Append(" ");                
                    }            
                }
'@        
        }
        
        $initBase64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($initializeChunk))
        
      
        $applicationDefinition = @"
    
    using System;
    using System.Text;
    using System.Management.Automation;
    using System.Management.Automation.Runspaces;
        
    public static class $name {
        public static void Main(string[] args) {
            StringBuilder sb = new StringBuilder();

            $argsSection

            PowerShell psCmd = PowerShell.Create();
            Runspace rs = RunspaceFactory.CreateRunspace();
            rs.ApartmentState = System.Threading.ApartmentState.STA;
            rs.ThreadOptions = PSThreadOptions.ReuseThread;
            rs.Open();
            psCmd.Runspace =rs;
            psCmd.AddScript(Encoding.Unicode.GetString(Convert.FromBase64String("$initBase64")), false).Invoke();
            psCmd.Invoke();            
            psCmd.Commands.Clear();           
            psCmd.AddScript(sb.ToString());
            try {
                psCmd.Invoke();
            } catch (Exception ex) {
                System.Windows.MessageBox.Show(ex.Message, ex.GetType().FullName);                
                rs.Close();
                rs.Dispose();     
            }
            foreach (ErrorRecord err in psCmd.Streams.Error) {
                System.Windows.MessageBox.Show(err.ToString());
            }
            rs.Close();
            rs.Dispose();                        
        }
    }   
"@   
        Write-Verbose $applicationDefinition
        Add-Type $applicationDefinition -IgnoreWarnings -ReferencedAssemblies $referencedAssemblies `
            -OutputAssembly $outputPath -OutputType WindowsApplication
    }
}
# SIG # Begin signature block
# MIIRDAYJKoZIhvcNAQcCoIIQ/TCCEPkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUjq8rTjxcQDRDjTmQ3wRhr6hd
# MZmggg5CMIIHBjCCBO6gAwIBAgIBFTANBgkqhkiG9w0BAQUFADB9MQswCQYDVQQG
# EwJJTDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERp
# Z2l0YWwgQ2VydGlmaWNhdGUgU2lnbmluZzEpMCcGA1UEAxMgU3RhcnRDb20gQ2Vy
# dGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMDcxMDI0MjIwMTQ1WhcNMTIxMDI0MjIw
# MTQ1WjCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0YXJ0Q29tIEx0ZC4xKzAp
# BgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRlIFNpZ25pbmcxODA2BgNV
# BAMTL1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJbnRlcm1lZGlhdGUgT2JqZWN0
# IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyiOLIjUemqAbPJ1J
# 0D8MlzgWKbr4fYlbRVjvhHDtfhFN6RQxq0PjTQxRgWzwFQNKJCdU5ftKoM5N4YSj
# Id6ZNavcSa6/McVnhDAQm+8H3HWoD030NVOxbjgD/Ih3HaV3/z9159nnvyxQEckR
# ZfpJB2Kfk6aHqW3JnSvRe+XVZSufDVCe/vtxGSEwKCaNrsLc9pboUoYIC3oyzWoU
# TZ65+c0H4paR8c8eK/mC914mBo6N0dQ512/bkSdaeY9YaQpGtW/h/W/FkbQRT3sC
# pttLVlIjnkuY4r9+zvqhToPjxcfDYEf+XD8VGkAqle8Aa8hQ+M1qGdQjAye8OzbV
# uUOw7wIDAQABo4ICfzCCAnswDAYDVR0TBAUwAwEB/zALBgNVHQ8EBAMCAQYwHQYD
# VR0OBBYEFNBOD0CZbLhLGW87KLjg44gHNKq3MIGoBgNVHSMEgaAwgZ2AFE4L7xqk
# QFulF2mHMMo0aEPQQa7yoYGBpH8wfTELMAkGA1UEBhMCSUwxFjAUBgNVBAoTDVN0
# YXJ0Q29tIEx0ZC4xKzApBgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmljYXRl
# IFNpZ25pbmcxKTAnBgNVBAMTIFN0YXJ0Q29tIENlcnRpZmljYXRpb24gQXV0aG9y
# aXR5ggEBMAkGA1UdEgQCMAAwPQYIKwYBBQUHAQEEMTAvMC0GCCsGAQUFBzAChiFo
# dHRwOi8vd3d3LnN0YXJ0c3NsLmNvbS9zZnNjYS5jcnQwYAYDVR0fBFkwVzAsoCqg
# KIYmaHR0cDovL2NlcnQuc3RhcnRjb20ub3JnL3Nmc2NhLWNybC5jcmwwJ6AloCOG
# IWh0dHA6Ly9jcmwuc3RhcnRzc2wuY29tL3Nmc2NhLmNybDCBggYDVR0gBHsweTB3
# BgsrBgEEAYG1NwEBBTBoMC8GCCsGAQUFBwIBFiNodHRwOi8vY2VydC5zdGFydGNv
# bS5vcmcvcG9saWN5LnBkZjA1BggrBgEFBQcCARYpaHR0cDovL2NlcnQuc3RhcnRj
# b20ub3JnL2ludGVybWVkaWF0ZS5wZGYwEQYJYIZIAYb4QgEBBAQDAgABMFAGCWCG
# SAGG+EIBDQRDFkFTdGFydENvbSBDbGFzcyAyIFByaW1hcnkgSW50ZXJtZWRpYXRl
# IE9iamVjdCBTaWduaW5nIENlcnRpZmljYXRlczANBgkqhkiG9w0BAQUFAAOCAgEA
# UKLQmPRwQHAAtm7slo01fXugNxp/gTJY3+aIhhs8Gog+IwIsT75Q1kLsnnfUQfbF
# pl/UrlB02FQSOZ+4Dn2S9l7ewXQhIXwtuwKiQg3NdD9tuA8Ohu3eY1cPl7eOaY4Q
# qvqSj8+Ol7f0Zp6qTGiRZxCv/aNPIbp0v3rD9GdhGtPvKLRS0CqKgsH2nweovk4h
# fXjRQjp5N5PnfBW1X2DCSTqmjweWhlleQ2KDg93W61Tw6M6yGJAGG3GnzbwadF9B
# UW88WcRsnOWHIu1473bNKBnf1OKxxAQ1/3WwJGZWJ5UxhCpA+wr+l+NbHP5x5XZ5
# 8xhhxu7WQ7rwIDj8d/lGU9A6EaeXv3NwwcbIo/aou5v9y94+leAYqr8bbBNAFTX1
# pTxQJylfsKrkB8EOIx+Zrlwa0WE32AgxaKhWAGho/Ph7d6UXUSn5bw2+usvhdkW4
# npUoxAk3RhT3+nupi1fic4NG7iQG84PZ2bbS5YxOmaIIsIAxclf25FwssWjieMwV
# 0k91nlzUFB1HQMuE6TurAakS7tnIKTJ+ZWJBDduUbcD1094X38OvMO/++H5S45Ki
# 3r/13YTm0AWGOvMFkEAF8LbuEyecKTaJMTiNRfBGMgnqGBfqiOnzxxRVNOw2hSQp
# 0B+C9Ij/q375z3iAIYCbKUd/5SSELcmlLl+BuNknXE0wggc0MIIGHKADAgECAgFR
# MA0GCSqGSIb3DQEBBQUAMIGMMQswCQYDVQQGEwJJTDEWMBQGA1UEChMNU3RhcnRD
# b20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERpZ2l0YWwgQ2VydGlmaWNhdGUgU2ln
# bmluZzE4MDYGA1UEAxMvU3RhcnRDb20gQ2xhc3MgMiBQcmltYXJ5IEludGVybWVk
# aWF0ZSBPYmplY3QgQ0EwHhcNMDkxMTExMDAwMDAxWhcNMTExMTExMDYyODQzWjCB
# qDELMAkGA1UEBhMCVVMxETAPBgNVBAgTCE5ldyBZb3JrMRcwFQYDVQQHEw5XZXN0
# IEhlbnJpZXR0YTEtMCsGA1UECxMkU3RhcnRDb20gVmVyaWZpZWQgQ2VydGlmaWNh
# dGUgTWVtYmVyMRUwEwYDVQQDEwxKb2VsIEJlbm5ldHQxJzAlBgkqhkiG9w0BCQEW
# GEpheWt1bEBIdWRkbGVkTWFzc2VzLm9yZzCCASIwDQYJKoZIhvcNAQEBBQADggEP
# ADCCAQoCggEBAMfjItJjMWVaQTECvnV/swHQP0FTYUvRizKzUubGNDNaj7v2dAWC
# rAA+XE0lt9JBNFtCCcweDzphbWU/AAY0sEPuKobV5UGOLJvW/DcHAWdNB/wRrrUD
# dpcsapQ0IxxKqpRTrbu5UGt442+6hJReGTnHzQbX8FoGMjt7sLrHc3a4wTH3nMc0
# U/TznE13azfdtPOfrGzhyBFJw2H1g5Ag2cmWkwsQrOBU+kFbD4UjxIyus/Z9UQT2
# R7bI2R4L/vWM3UiNj4M8LIuN6UaIrh5SA8q/UvDumvMzjkxGHNpPZsAPaOS+RNmU
# Go6X83jijjbL39PJtMX+doCjS/lnclws5lUCAwEAAaOCA4EwggN9MAkGA1UdEwQC
# MAAwDgYDVR0PAQH/BAQDAgeAMDoGA1UdJQEB/wQwMC4GCCsGAQUFBwMDBgorBgEE
# AYI3AgEVBgorBgEEAYI3AgEWBgorBgEEAYI3CgMNMB0GA1UdDgQWBBR5tWPGCLNQ
# yCXI5fY5ViayKj6xATCBqAYDVR0jBIGgMIGdgBTQTg9AmWy4SxlvOyi44OOIBzSq
# t6GBgaR/MH0xCzAJBgNVBAYTAklMMRYwFAYDVQQKEw1TdGFydENvbSBMdGQuMSsw
# KQYDVQQLEyJTZWN1cmUgRGlnaXRhbCBDZXJ0aWZpY2F0ZSBTaWduaW5nMSkwJwYD
# VQQDEyBTdGFydENvbSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eYIBFTCCAUIGA1Ud
# IASCATkwggE1MIIBMQYLKwYBBAGBtTcBAgEwggEgMC4GCCsGAQUFBwIBFiJodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS9wb2xpY3kucGRmMDQGCCsGAQUFBwIBFihodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS9pbnRlcm1lZGlhdGUucGRmMIG3BggrBgEFBQcC
# AjCBqjAUFg1TdGFydENvbSBMdGQuMAMCAQEagZFMaW1pdGVkIExpYWJpbGl0eSwg
# c2VlIHNlY3Rpb24gKkxlZ2FsIExpbWl0YXRpb25zKiBvZiB0aGUgU3RhcnRDb20g
# Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkgUG9saWN5IGF2YWlsYWJsZSBhdCBodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS9wb2xpY3kucGRmMGMGA1UdHwRcMFowK6ApoCeG
# JWh0dHA6Ly93d3cuc3RhcnRzc2wuY29tL2NydGMyLWNybC5jcmwwK6ApoCeGJWh0
# dHA6Ly9jcmwuc3RhcnRzc2wuY29tL2NydGMyLWNybC5jcmwwgYkGCCsGAQUFBwEB
# BH0wezA3BggrBgEFBQcwAYYraHR0cDovL29jc3Auc3RhcnRzc2wuY29tL3N1Yi9j
# bGFzczIvY29kZS9jYTBABggrBgEFBQcwAoY0aHR0cDovL3d3dy5zdGFydHNzbC5j
# b20vY2VydHMvc3ViLmNsYXNzMi5jb2RlLmNhLmNydDAjBgNVHRIEHDAahhhodHRw
# Oi8vd3d3LnN0YXJ0c3NsLmNvbS8wDQYJKoZIhvcNAQEFBQADggEBACY+J88ZYr5A
# 6lYz/L4OGILS7b6VQQYn2w9Wl0OEQEwlTq3bMYinNoExqCxXhFCHOi58X6r8wdHb
# E6mU8h40vNYBI9KpvLjAn6Dy1nQEwfvAfYAL8WMwyZykPYIS/y2Dq3SB2XvzFy27
# zpIdla8qIShuNlX22FQL6/FKBriy96jcdGEYF9rbsuWku04NqSLjNM47wCAzLs/n
# FXpdcBL1R6QEK4MRhcEL9Ho4hGbVvmJES64IY+P3xlV2vlEJkk3etB/FpNDOQf8j
# RTXrrBUYFvOCv20uHsRpc3kFduXt3HRV2QnAlRpG26YpZN4xvgqSGXUeqRceef7D
# dm4iTdHK5tIxggI0MIICMAIBATCBkjCBjDELMAkGA1UEBhMCSUwxFjAUBgNVBAoT
# DVN0YXJ0Q29tIEx0ZC4xKzApBgNVBAsTIlNlY3VyZSBEaWdpdGFsIENlcnRpZmlj
# YXRlIFNpZ25pbmcxODA2BgNVBAMTL1N0YXJ0Q29tIENsYXNzIDIgUHJpbWFyeSBJ
# bnRlcm1lZGlhdGUgT2JqZWN0IENBAgFRMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3
# AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisG
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEWMCMGCSqGSIb3DQEJBDEWBBRi7SdbzIEg
# jIwSreWzNKv0ImbERzANBgkqhkiG9w0BAQEFAASCAQCAUsot/30QUEMt29WbT1HQ
# +oqvx5/6FNzmcHtSTvE3f4aQI22MbOj8IYjCodlxBdyW+Eb+nYI+fV1KPmb6twht
# Zw1WCXSrHZbI9oykiNGWxuXmDYwQy6L6/hfbWdlIv/1JeWt9VBHgnTL+tz30ZPpk
# v6C4EtQ5KaFT+DOBdhbTI2tOiC+BE3e08oI1G2ll4cbdtKulCE1QVwKlPxhi73D9
# FYlFimD29rtkhTMwzt+ik7HD9pjLJiRdaHSUNPJFdoWac8FW0U9vWA2Z5mEson3p
# BoYE+mdaANudIOkHPwjm1v85r4MGBRkB2pXDKAW6C7A0wGdyIIBjjQtjSILrUb/B
# SIG # End signature block
