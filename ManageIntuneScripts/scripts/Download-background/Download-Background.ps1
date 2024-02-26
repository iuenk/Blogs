$url = '<SAS URL>'
$Destination = 'C:\Windows\Web\Wallpaper\Theme1\ucorp-background.jpg'

Invoke-WebRequest -Uri $url -OutFile $Destination