function Assert-DesktopWritePath([string] $Path) {
    $full=[IO.Path]::GetFullPath($Path)
    foreach($protected in @('C:\bin\wabbajack\SkyrimVRMods','S:\SteamLibrary\steamapps\common\SkyrimVR',(Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games\Skyrim VR'))) {
        $root=[IO.Path]::GetFullPath($protected).TrimEnd('\')
        if($full.Equals($root,[StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) {throw "Refusing VR production write: $full"}
    }
    $cursor=$full
    while($cursor) {
        if(Test-Path -LiteralPath $cursor) {
            $item=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
            if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.LinkType -eq 'HardLink') {throw "Refusing linked desktop write: $cursor"}
        }
        $parent=Split-Path -Parent $cursor
        if($parent -eq $cursor) {break}
        $cursor=$parent
    }
}
