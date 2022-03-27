$ErrorActionPreference = [string]"Stop"

# Have global to have recursive info about file being found
$hasFileInSourceDir = $false

$DestDirForPhotos = [string]"$env:OneDrive\Pictures"

function Test-DestPath($destPath) {
    if(! (Test-Path $destPath))
    {
        throw "Cesta $destPath neexistuje."
    }
}

function Get-DeviceDirectory($deviceName)
{
  $o = New-Object -com Shell.Application
  $rootComputerDirectory = $o.NameSpace(0x11)
  $deviceDirectory = $rootComputerDirectory.Items() | Where-Object {$_.Name -eq $deviceName}
    
  if($deviceDirectory -eq $null)
  {
    throw "Nenalezena složka pro '$deviceName'."
  }

  if($deviceDirectory.Count -gt 1)
  {
    throw "Nalezeno vícero '$deviceName'."
  }
  
  return $deviceDirectory;
}

function Get-SubFolder($parentDir, $subPath)
{
  $result = $parentDir
  foreach($pathSegment in ($subPath -split "\\"))
  {
    $result = $result.GetFolder.Items() | Where-Object {$_.Name -eq $pathSegment}
    if($result -eq $null)
    {
      throw "Nenalezena podsložka '$subPath'"
    }
  }
  return $result;
}

function Add-Dir($baseDir, $makeDir)
{
    $fullPathDir = Join-Path -Path $baseDir -ChildPath $makeDir
    Write-Host "'$baseDir'"
    Write-Host "'$makeDir'"
    Write-Host "'$fullPathDir'"
    if(! (Test-Path $baseDir))
    {
        throw "Cesta '$baseDir' neexistuje."
    }

    if(! (Test-Path -Path $fullPathDir))
    {
        Write-Host "Vytvářím podsložku '$makeDir'."
       $fullPathDir = New-Item -Path $fullPathDir -Type Directory
    }
    else
    {
        Write-Host "Cesta $fullPathDir už existuje."
    }

    return $fullPathDir.ToString()

}

function Get-FullPathOfDeviceDir($deviceDir)
{
 $fullDirPath = ""
 $directory = $deviceDir.GetFolder
 while($directory -ne $null)
 {
   $fullDirPath =  -join($directory.Title, '\', $fullDirPath)
   $directory = $directory.ParentFolder;
 }
 return $fullDirPath.ToString()
}

function Move-DeviceSource-Files($deviceDir, $destDirPath)
{
 $destDirShell = (new-object -com Shell.Application).NameSpace($destDirPath)
 $fullDeviceDirPath = Get-FullPathOfDeviceDir $deviceDir

 
 Write-Host "Přesunuji soubory z: '" $fullDeviceDirPath "' do '" $destDirPath "'"
 
 $movedCount = 0
 
 foreach ($item in $deviceDir.GetFolder.Items())
  {
   if($item.IsFolder)
   {
      Write-Host $item.Name " je složka, vnořuji se"
      Move-DeviceSource-Files -deviceDir $item -destDirPath $destDirPath
   }
   else
   {
     $movedCount++;
     Write-Host ("Přesunuji #{0}: {1}{2}" -f $movedCount, $fullDeviceDirPath, $item.Name)
     $destDirShell.MoveHere($item)
   }
  }
  Write-Host "Přesunuto $movedCount souborů z '$fullDeviceDirPath'"
}


function Get-FullPathOfDeviceDir($deviceDir)
{
 $fullDirPath = ""
 $directory = $deviceDir.GetFolder
 while($directory -ne $null)
 {
   $fullDirPath =  -join($directory.Title, '\', $fullDirPath)
   $directory = $directory.ParentFolder;
 }
 return $fullDirPath
}

function Test-DeviceSource-HasFiles($deviceDir)
{
 foreach ($item in $deviceDir.GetFolder.Items())
  {
   if($hasFileInSourceDir -eq $true)
   {
      return $hasFileInSourceDir
   }

   if($item.IsFolder)
   {
      Test-DeviceSource-HasFiles $item
   }
   else
   {
     $hasFileInSourceDir = $true
     return $hasFileInSourceDir
   }
  }
  return $hasFileInSourceDir
}


function Pause () {
    Read-Host -Prompt "Stiskněte Enter pro ukončení programu."
}

function Get-LatestBatchFolderName($destDir) {
     $max = -1
     foreach ($item in Get-ChildItem -Path $destDir -Directory)
      {
       $itemNumber = $item.baseName -as [int]
       if($itemNumber -ne "" -and $itemNumber -gt $max)
       {
           $max = $itemNumber
       }
      }
     
     if($max -eq -1)
     {
        return $null
     }
     return $max
}

function Script-Start($device = $args[0]) {
    if($device -eq "")
    {
        throw "Musíte specifikovat přístroj, ze kterého přetáhnout soubory."
    }
    Test-DestPath $DestDirForPhotos
    $deviceRootDir = Get-DeviceDirectory($device)

    $SrcDirForPhotos = (Get-SubFolder $deviceRootDir "$device\DCIM\100NIKON")

    # We check if we have some files otherwise we can return early
    if(! (Test-DeviceSource-HasFiles $SrcDirForPhotos)) {
        return
    }

    $DestDirForPhotos = (Add-Dir -baseDir $DestDirForPhotos -makeDir (date -Format 'yyyy-MM-dd'))

    $BatchFolderName = Get-LatestBatchFolderName $DestDirForPhotos
    
    if($BatchFolderName -eq $null)
    {
        $BatchFolderName = "001"
        $DestDirForPhotos = Add-Dir -baseDir $DestDirForPhotos -makeDir $BatchFolderName
    }
    else
    {
        $BatchFolderName = ($BatchFolderName -as [string]).PadLeft(3, '0')
        $tmpDestDir = (Join-Path -Path $DestDirForPhotos -ChildPath $BatchFolderName)
        #Unhandled Exception as this folder should be counted up and have 3 positions
        Test-DestPath $tmpDestDir
        if ((Get-ChildItem -Path $tmpDestDir -File | Measure-Object).Count -gt 0)
        {
            $BatchFolderName = ((($BatchFolderName -as [int]) + 1) -as [string]).PadLeft(3, '0')
            $DestDirForPhotos = Add-Dir -baseDir $DestDirForPhotos -makeDir $BatchFolderName
        }
        else
        {
            $DestDirForPhotos = $tmpDestDir
        }
    }

    Move-DeviceSource-Files -deviceDir $SrcDirForPhotos -destDirPath $DestDirForPhotos
}

Try
{
    Script-Start
}
Finally
{
    Pause
}