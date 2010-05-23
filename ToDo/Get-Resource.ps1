function Get-Resource {
<#
.Synopsis
  Finds a Resource in a visual control or the controls parents
.Description
  Retrieves a resource stored in the Resources property of a UIElement.
  If the UIElement does not contain the resource, the parent will be checked.
  If no more parents exist, then nothing will be returned.
.Parameter Visual
  The UI element to start looking for resources.
.Parameter Name
  The name of the resource to find
.Example
  New-Grid -Rows '1*', 'Auto' {
      New-ListBox -On_Loaded {
          Set-Resource "List" $this -1
      }
      New-Button -Row 1 "_Add" -On_Click {
          $list = Get-Resource "List"
          $list.ItemsSource += @(Get-Random)
      } 
  } -Show
#>
param(
   [String[]]$Name = @("*")
,
   # Every framework-level element (FrameworkElement  or FrameworkContentElement) has a Resources  property
   $Element
)
begin { if(!($Element -as [System.WIndows.IFrameworkInputElement])){ $Element = $this } }
process {
   while ($Element -as [System.WIndows.IFrameworkInputElement]) {
      foreach ($key in $item.Resources.Keys) {
         foreach ($pattern in $Name) {
            if ($key -match $pattern) {
               write-output $item.Resources.$key
            }
         }
      }
      $Element = $Element.Parent
   }
}
}