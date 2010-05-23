##Requires -Version 2.0
####################################################################################################
if(!(Test-Path Variable::PowerBootsPath)) {
   New-Variable PowerBootsPath $PSScriptRoot -Description "The root folder for PowerBoots" -Force -Option Constant,ReadOnly,AllScope -Scope Global
}
$ParameterHashCache = @{}
$DependencyProperties = @{}
if(Test-Path $PowerBootsPath\DependencyPropertyCache.clixml) {
   $DependencyProperties = [System.Windows.Markup.XamlReader]::Parse( (gc $PowerBootsPath\DependencyPropertyCache.xml) )
}
$LoadedAssemblies = @(); 

$null = [Reflection.Assembly]::Load( "PresentationFramework, Version=3.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" )

## Dotsource these rather than autoloading because we're guaranteed to need them
. "$PowerBootsPath\Core\Add-BootsFunction.ps1"
. "$PowerBootsPath\Core\Set-DependencyProperty.ps1"
. "$PowerBootsPath\Core\Set-PowerBootsProperties.ps1"
. "$PowerBootsPath\Core\UtilityFunctions.ps1"
. "$PowerBootsPath\Core\ContentProperties.ps1"

## Dotsource this because calling it from inside AutoLoad messes with the -Scope value
. "$PowerBootsPath\Core\Export-NamedControl.ps1"

## Autoload these for public consumption if needed
AutoLoad "$PowerBootsPath\Core\New-BootsImage.ps1" New-BootsImage PowerBoots
## TODO: This would be a great function to add, if we could make it ADD instead of SET.
# AutoLoad "$PowerBootsPath\New Functions\Add-ChildControl.ps1" Add-ChildControl PowerBoots

## Add-EventHandler is deprecated because the compiled Register-BootsEvent is a better way
#. "$PowerBootsPath\New Functions\Add-EventHandler.ps1"
## TODO: Can Register-BootsEvent be an actual PSEvent and still execute on the thread the way I need it to?

## Select-ChildControl (aka: Get-ChildControl) is deprecated because Export-NamedControls is a better way
#. "$PowerBootsPath\New Functions\Select-ChildControl.ps1"
## I don't need this one, 'cause I've integrated it into the core! ;)
# . "$PowerBootsPath\New Functions\ConvertTo-DataTemplate.ps1"

## TODO: I'm not really sure how these fit in yet
# "$PowerBootsPath\Core\ConvertTo-GridLength.ps1"
# "$PowerBootsPath\Extras\Enable-Multitouch.ps1"
# "$PowerBootsPath\Extras\Export-Application.ps1"

# This is #Requires -STA
$IsSTA = [System.Threading.Thread]::CurrentThread.ApartmentState -eq "STA"

## In case they delete the "Deprecated" folder (like I would)...
if(Test-Path "$PowerBootsPath\Deprecated\Out-BootsWindow.ps1") {
   if( !$IsSTA ) { 
      function Out-BootsWindow {
         Write-Error "Out-BootsWindow disabled in MTA mode. Use New-BootsWindow instead. (You must run PowerShell with -STA switch to enable Out-BootsWindow)"
      }
   } else { # Requires -STA
      AutoLoad "$PowerBootsPath\Deprecated\Out-BootsWindow.ps1" Out-BootsWindow PowerBoots
   }
}

## Thanks to Autoload, I'm not altering the path ...
## Put the scripts into the path
#  [string[]]$path = ${Env:Path}.Split(";")
#  if($path -notcontains "$PowerBootsPath\Types_Generated\") {
   #  ## Note: Functions in "Types_StaticOverrides" override regular functions
   #  $path += "$PowerBootsPath\Types_StaticOverrides\","$PowerBootsPath\Types_Generated\"
   #  ${Env:Path} = [string]::Join(";", $path)
#  }


## Autoload all the functions ....
if(!(Get-ChildItem "$PowerBootsPath\Types_Generated\New-*.ps1" -ErrorAction SilentlyContinue)) {
   & "$PowerBootsPath\Core\Reset-DefaultBoots.ps1"
}

foreach($script in Get-ChildItem "$PowerBootsPath\Types_Generated\New-*.ps1", "$PowerBootsPath\Types_StaticOverrides\New-*.ps1" -ErrorAction 0) {
   $TypeName = $script.Name -replace 'New-(.*).ps1','$1'
   
   Set-Alias -Name "$($TypeName.Split('.')[-1])" "New-$TypeName"        -EA "SilentlyContinue" -EV +ErrorList
   AutoLoad $Script.FullName "New-$TypeName" PowerBoots
   # Write-Host -fore yellow $(Get-Command "New-$TypeName" | Out-String)
}

## Extra aliases....
$errorList = @()
## We don't need this work around for the "Grid" alias anymore
## but we preserve compatability by still generating GridPanel (which is what the class ought to be anyway?)
Set-Alias -Name GridPanel  -Value "New-System.Windows.Controls.Grid"   -EA "SilentlyContinue" -EV +ErrorList
if($ErrorList.Count) { Write-Warning """GridPanel"" alias not created, you must use New-System.Windows.Controls.Grid" }

$errorList = @()
Set-Alias -Name Boots      -Value "New-BootsWindow"         -EA "SilentlyContinue" -EV +ErrorList
if($ErrorList.Count) { Write-Warning "Boots alias not created, you must use the full New-BootsWindow function name!" }

$errorList = @()
Set-Alias -Name BootsImage -Value "Out-BootsImage"          -EA "SilentlyContinue" -EV +ErrorList
if($ErrorList.Count) { Write-Warning "BootsImage alias not created, you must use the full Out-BootsImage function name!" }

Set-Alias -Name obi    -Value "Out-BootsImage"          -EA "SilentlyContinue"
Set-Alias -Name sdp    -Value "Set-DependencyProperty"  -EA "SilentlyContinue"
Set-Alias -Name gbw    -Value "Get-BootsWindow"         -EA "SilentlyContinue"
Set-Alias -Name rbw    -Value "Remove-BootsWindow"      -EA "SilentlyContinue"
                                                    
$BootsFunctions = @("Add-BootsFunction", "Set-DependencyProperty", "New-*") +
                  @("Get-BootsModule", "Get-BootsAssemblies", "Get-Parameter", "Get-BootsParam" ) + 
                  @("Get-BootsContentProperty", "Add-BootsContentProperty", "Remove-BootsContentProperty") +
                  @("Get-BootsHelp", "Get-BootsCommand", "Out-BootsWindow", "New-BootsImage") +
                  @("Select-BootsElement","Select-ChildControl", "Add-ChildControl", "Add-EventHandler" ) +
                  @("ConvertTo-GridLength", "Enable-MultiTouch", "Export-Application") + 
                  @("Autoloaded", "Export-NamedControl")
Export-ModuleMember -Function $BootsFunctions -Alias * -Variable IsSTA, PowerBootsPath
## Post CTP3 we have to export the submodule separately:
Export-ModuleMember -Cmdlet (Get-Command -Module PoshWpf)


# SIG # Begin signature block
# MIIRDAYJKoZIhvcNAQcCoIIQ/TCCEPkCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU1jLI/jDf4yu8avrcS4S7vVhx
# 4eaggg5CMIIHBjCCBO6gAwIBAgIBFTANBgkqhkiG9w0BAQUFADB9MQswCQYDVQQG
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
# AQQBgjcCAQsxDjAMBgorBgEEAYI3AgEWMCMGCSqGSIb3DQEJBDEWBBTfwkU0iCIn
# WJnRuiE86CUC6ZWMfzANBgkqhkiG9w0BAQEFAASCAQCft1y2J8GgfFPsW94xiIck
# eEJDnRUIsggaPijJ3Dypts52LnT+1TJ9N8ksFBPDWiNdKI8UtaRuDbTJROUhMuzU
# QPYOUVID0aO0AfuhUbIyyfJMfP7ZZWVsvaCm7c8lSCZ7DuD2dwrU27h8gy9gnV+v
# ioiDeAuCS7OHYoEw1QZ4ZJRV80loWlXZD+B7d+kC7699/BcFB5TvBm49rMOwY53a
# QHe+x2zCB9ZgY/ynEGXwdAsGV2b4N2ZTUTe1zU8KpN4HhVQc9CZ6N8CN6MTiSWrH
# SWQOL253CarwxlAJw3TIRYpp83XPOufRcJU+KpXKAr0xi1e4j7Hl1RSMkswCPiG2
# SIG # End signature block
