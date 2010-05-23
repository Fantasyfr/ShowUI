function ConvertTo-DataTemplate
{
<#
  .Synopsis
      Converts the UIElement to a data template
  .Description
      Converts the UIElement to a data template by stripping its resources, 
      outputting the control as XAML, and enclosing within <DateTemplate> tags
  .Example
      New-Image | ConvertTo-DataTemplate @{"Source" = "MySource"} -outputXaml            
  .Example
      New-ListBox -ItemsSource { Get-Process } -ItemTemplate {
         New-StackPanel -Orientation Horizontal -Children {
            New-Label -Name ProcessName -FontSize 14 
            New-Label -Name Id -FontSize 8
         } | ConvertTo-DataTemplate -binding @{
            "ProcessName.Content" = "ProcessName"
            "Id.Content" = "Id"
         }    
      } -show            
  .Parameter control
      The UIElement to turn into a data
  .Parameter binding
      A dictionary of UIElements
  .Parameter outputXaml
      If set, will output the Xaml for the data template rather than the object
#>
PARAM(
   [Parameter(ValueFromPipeline=$true, Position=0)]
   $control
,
   [Parameter(Position=1)]
   [Hashtable]$binding
,
   [switch]$AsXaml
)
        
   process
   {
      if($control -is [ScriptBlock]) {
         $control = &$control
      } elseif($control -isnot [Windows.UIElement]) {
         throw "Control must be a UIElement or a PowerBoots ScriptBlock"
      }
      
      $control | Get-ChildControl | ForEach-Object {
         if ($_.Resources) {
            foreach ($kv in @($_.Resources.GetEnumerator())) {
               $null = $_.Resources.Remove($kv.Key)
            }
         }
      }
      $xaml = [Windows.Markup.XamlWriter]::Save($control)
      $xml = [xml]$xaml       
        
      if ($binding) {
         $binding.GetEnumerator() | ForEach-Object {
            $value = $_.Value
            if ($_.Key -like "*.*" ) {
               $chunks = $_.Key.Split(".")
               $targetName = $chunks[0]
               $bind = $chunks[1]
               $xml | Select-Xml "//*" | 
                     Where-Object { $_.Node.Name -eq $targetName } | 
                     ForEach-Object { $_.Node.SetAttribute($bind, "{Binding $value}") }
            } else {
               $property = $_.Key
               $value = $_.Value
               $xml | Select-Xml "." | ForEach-Object { @($_.Node.GetEnumerator())[0].SetAttribute($property, "{Binding $value}") }
            }
         }
      }
        
        
      $xaml = @"
<DataTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'>
   $($xml.OuterXml)
</DataTemplate>
"@
      if ($AsXaml) {
         $strWrite = New-Object IO.StringWriter
         [xml]$newXml = $xaml
         $newXml.Save($strWrite)
         return "$strWrite"
      } else {        
         [Windows.Markup.XamlReader]::Parse($xaml)
      }
   }
}