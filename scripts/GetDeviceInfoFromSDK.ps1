$loc = "D:\Users\$($env:USERNAME))\AppData\Roaming\Garmin\ConnectIQ\Devices"

$jsonfiles = Get-ChildItem -Path $loc -Filter "compiler.json" -Recurse

$devices = @()

foreach($j in $jsonfiles){

    $json = Get-Content $($j.fullname)
    $jsonobject = $json | ConvertFrom-Json

    $device = [pscustomobject]@{
        deviceFamily = $($jsonobject.deviceFamily)
        deviceGroup = $($jsonobject.deviceGroup)
        deviceId = $($jsonobject.deviceId)
        worldWidePartNumber = $($jsonobject.worldWidePartNumber)
        resolutionH = "$($jsonobject.resolution.height)"
        resolutionW = $($jsonobject.resolution.width)
        resolution = "$($jsonobject.resolution.height)x$($jsonobject.resolution.width)"
        launcherIconH = $($jsonobject.launcherIcon.height)
        launcherIconW = $($jsonobject.launcherIcon.width)
        launcherIcon = "$($jsonobject.launcherIcon.height)x$($jsonobject.launcherIcon.width)"
        connectiq = $($jsonobject.partNumbers[0].connectIQVersion)
    }
    $devices += $device
}

#return $devices


#Jungle lines for launcher icon https://developer.garmin.com/connect-iq/reference-guides/jungle-reference/
$lines = $devices | Group-Object launcherIcon | Sort-Object count | %{
        $name = $_.name
        $($_.group) | %{
            ("$($_.deviceid)" + '.resourcePath = $(' + $($_.deviceid) + '.resourcePath);resources_' + $($name))
        }
    }


$lines