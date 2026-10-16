$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$root=Split-Path -Parent $PSScriptRoot
$fontCollection=[System.Drawing.Text.PrivateFontCollection]::new()
$fontCollection.AddFontFile('C:\Users\sandt\AppData\Local\Roblox\Versions\version-76e1a02649ad4f35\content\fonts\LuckiestGuy-Regular.ttf')
$family=$fontCollection.Families[0]
$ns='http://www.w3.org/2000/svg'
$culture=[System.Globalization.CultureInfo]::InvariantCulture
function Fmt([double]$value){$value.ToString('0.###',$culture)}
$manifest=Get-Content -Raw -LiteralPath (Join-Path $root 'Maps\AssetManifest.json') | ConvertFrom-Json
foreach($asset in $manifest.assets){
 $inputPath=Join-Path $root $asset.svg
 [xml]$doc=Get-Content -Raw -LiteralPath $inputPath
 $manager=[System.Xml.XmlNamespaceManager]::new($doc.NameTable);$manager.AddNamespace('s',$ns)
 foreach($meta in @($doc.SelectNodes('//s:metadata',$manager))){[void]$meta.ParentNode.RemoveChild($meta)}
 if($asset.category -eq 'OptionalLabels'){
  $face=$doc.SelectNodes('//s:rect',$manager) | Where-Object {$_.GetAttribute('id').EndsWith('-Face')} | Select-Object -First 1
  $cx=[double]$face.GetAttribute('x')+[double]$face.GetAttribute('width')/2
  $cy=[double]$face.GetAttribute('y')+[double]$face.GetAttribute('height')/2
  $texts=@($doc.SelectNodes('//s:text',$manager));$records=@();$minY=[double]::PositiveInfinity;$maxY=[double]::NegativeInfinity
  foreach($text in $texts){
   $size=[single]$text.GetAttribute('font-size')
   $glyphPath=[System.Drawing.Drawing2D.GraphicsPath]::new()
   $glyphPath.AddString($text.InnerText,$family,0,$size,[System.Drawing.PointF]::new(0,0),[System.Drawing.StringFormat]::GenericTypographic)
   $bounds=$glyphPath.GetBounds()
   if($bounds.Width -le 0){throw 'Empty outlined label'}
   $baseline=[double]$text.GetAttribute('y')
   $dy=$baseline-$size*.75-$bounds.Y
   $minY=[Math]::Min($minY,$bounds.Y+$dy);$maxY=[Math]::Max($maxY,$bounds.Bottom+$dy)
   $records+=@{Text=$text;Path=$glyphPath;DX=$cx-($bounds.X+$bounds.Width/2);DY=$dy}
  }
  $blockShift=$cy-($minY+$maxY)/2
  foreach($record in $records){
   $glyphPath=$record.Path;$matrix=[System.Drawing.Drawing2D.Matrix]::new();$matrix.Translate([single]$record.DX,[single]($record.DY+$blockShift));$glyphPath.Transform($matrix);$matrix.Dispose()
   $points=$glyphPath.PathPoints;$types=$glyphPath.PathTypes;$parts=[System.Collections.Generic.List[string]]::new();$i=0
   while($i -lt $points.Length){
    $type=$types[$i] -band 7
    if($type -eq 0){$parts.Add('M'+(Fmt $points[$i].X)+' '+(Fmt $points[$i].Y))}
    elseif($type -eq 1){$parts.Add('L'+(Fmt $points[$i].X)+' '+(Fmt $points[$i].Y))}
    elseif($type -eq 3){$parts.Add('C'+(Fmt $points[$i].X)+' '+(Fmt $points[$i].Y)+' '+(Fmt $points[$i+1].X)+' '+(Fmt $points[$i+1].Y)+' '+(Fmt $points[$i+2].X)+' '+(Fmt $points[$i+2].Y));$i+=2}
    else{throw 'Unexpected glyph curve type'}
    if(($types[$i] -band 128) -ne 0){$parts.Add('Z')};$i++
   }
   $path=$doc.CreateElement('path',$ns);$path.SetAttribute('d',($parts -join ' '));$path.SetAttribute('id','Label-'+($record.Text.InnerText -replace '[^A-Za-z0-9]','-'));$path.SetAttribute('data-label',$record.Text.InnerText)
   foreach($attribute in @('fill','stroke','stroke-width','stroke-linejoin','paint-order')){$path.SetAttribute($attribute,$record.Text.GetAttribute($attribute))}
   [void]$record.Text.ParentNode.ReplaceChild($path,$record.Text);$glyphPath.Dispose()
  }
 }
 $relative=$asset.svg -replace '^Editable/','Figma-DragDrop/'
 $destination=Join-Path $root $relative
 [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $destination));$doc.Save($destination)
 $asset | Add-Member -NotePropertyName figma -NotePropertyValue $relative -Force
}
$fontCollection.Dispose()
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $root 'Maps\AssetManifest.json') -Encoding utf8
Write-Output ('Prepared '+$manifest.assets.Count+' direct-import SVGs; no live text or font dependencies.')
