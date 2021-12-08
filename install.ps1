$version = iwr https://update.tabnine.com/bundles/version
$version = $version.content

if([environment]::Is64bitOperatingSystem){
	$platform = 'x86_64-pc-windows-gnu'
}
else{
	$platform = 'i686-pc-windows-gnu'
}

$path = "$version/$platform"

iwr "https://update.tabnine.com/bundles/$path/TabNine.zip" -OutFile TabNine.zip

$tabnine_path = "$env:LOCALAPPDATA/nvim-data/binaries/$path"

if(!(Test-Path "./binaries/$path")){
	mkdir -p $tabnine_path
}

expand-archive Tabnine.zip -destinationpath $tabnine_path -force
Remove-Item -Recurse "./TabNine.zip"
