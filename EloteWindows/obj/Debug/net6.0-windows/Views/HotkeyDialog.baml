   M S B A M L   `   `   `  ����  EloteWindows%    EloteWindows.Views.HotkeyDialog   5   	   R NNHotkey.Wpf, Version=2.0.0.0, Culture=neutral, PublicKeyToken=a76ffb086700b11cW SPresentationCore, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35\ XPresentationFramework, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35e aSystem.Windows.Controls.Ribbon, Version=6.0.2.0, Culture=neutral, PublicKeyToken=b77a5c561934e089R NWindowsBase, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35^ ZWindowsFormsIntegration, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35J 9http://schemas.microsoft.com/winfx/2006/xaml/presentation       5   	   R NSystem.Xaml, Version=6.0.2.0, Culture=neutral, PublicKeyToken=b77a5c561934e089:x,http://schemas.microsoft.com/winfx/2006/xaml     5   	     � Title$  Set Keyboard Shortcut��5   	   $	��200��5   	   $	��350��6    � WindowStartupLocation$ CenterOwner=�5   	    � 
ResizeMode$ NoResize=�5   	    � ShowInTaskbar$ False��5   	   .��5	      � $��15q�6    � RowDefinitions 5
   
   �� 5      $
��Auto �6   �� 5      $
��Auto �6   �� 5      $��* �6   �� 5      $
��Auto �6   .+�5   
   �� -   5         ��Name$ ActionTextBlock��5   !   $��0��6   $��Set shortcut for {Action}��6:   $��Medium"�5      $��0,0,0,15q�6&   �� 5   
   $��1��6   $6��0Press the keys you want to use for the shortcut:��6!   $��0,0,0,5q�5      �� 5   
   $��2��6   $��1q�6   
������� �� Padding$ 5q�6J   $��0,0,0,15q�6V   ._�5      �� -   5        $ HotkeyDisplayTextBlock��5      $��Press keys now...��68   $��16(�5      $��Center=�6$   $��Center=�6A   5      �� 5   
   $��3��6    �� Orientation$ 
Horizontal=�6"   $��Right=�6;   .+�5      �� -   5        $��Cancel��5      $��80��6&   $��0,0,10,0q�61   6C   �� 5      -   5        $
��Save��5      $��80��6$   6/   5      5       5!      