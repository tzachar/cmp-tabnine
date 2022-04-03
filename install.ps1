$version = iwr https://update.tabnine.com/bundles/version -UseBasicParsing
$version = $version.content

if([environment]::Is64bitOperatingSystem){
	$platform = 'x86_64-pc-windows-gnu'
}
else{
	$platform = 'i686-pc-windows-gnu'
}

$path = "$version/$platform"

iwr "https://update.tabnine.com/bundles/$path/TabNine.zip" -OutFile TabNine.zip

if(!(Test-Path ./binaries)){
	mkdir binaries
}

if(!(Test-Path "./binaries/$path")){
	mkdir "binaries/$path"
}

expand-archive Tabnine.zip -destinationpath "./binaries/$path" -force
Remove-Item -Recurse "./TabNine.zip"
