   M S B A M L   `   `   `  ����  EloteWindows%    EloteWindows.Views.PromptDialog   5   	   R NNHotkey.Wpf, Version=2.0.0.0, Culture=neutral, PublicKeyToken=a76ffb086700b11cW SPresentationCore, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35\ XPresentationFramework, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35e aSystem.Windows.Controls.Ribbon, Version=6.0.2.0, Culture=neutral, PublicKeyToken=b77a5c561934e089R NWindowsBase, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35^ ZWindowsFormsIntegration, Version=6.0.2.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35J 9http://schemas.microsoft.com/winfx/2006/xaml/presentation       5   	   R NSystem.Xaml, Version=6.0.2.0, Culture=neutral, PublicKeyToken=b77a5c561934e089:x,http://schemas.microsoft.com/winfx/2006/xaml     5   	     � Title$  Prompt Dialog��5   	   $	��300��5   	   $	��400��6    � WindowStartupLocation$ CenterOwner=�5   	    � 
ResizeMode$ NoResize=�5   	    � ShowInTaskbar$ False��5   	   .��5	      � $��15q�6    � RowDefinitions 5
   
   �� 5      $
��Auto �6   �� 5      $
��Auto �6   �� 5      $
��Auto �6   �� 5      $��* �6   �� 5      $
��Auto �6   .+�5   
   �� -   5         ��Name$ TitleTextBlock��5   !   $��0��6   $��Create/Edit Prompt��69   $��Medium"�5      $��0,0,0,15q�6&   �� 5   
   $��1��6   $��Prompt Name:��6!   $��0,0,0,5q�65   �� 5   
   -   5         ��Name$ PromptNameTextBox��5      $��2��6   $��0,0,0,15q�6:   �� 5   
   $��3��6   $��Prompt Text:��6!   $��0,0,0,5q�65   $	��Top=�6F   �� 5   
   -   5        $ PromptTextTextBox��5      $��3��6   $��0,25,0,0q�6:    �� TextWrapping$
 Wrap=�5       �� AcceptsReturn$
 True��6$   $��Stretch=�69   �� 5   
   $��4��6   	 �� Orientation$	 
Horizontal=�6"   $��Right=�6;   $��0,15,0,0q�6W   .+�5      �� -   5        $��Cancel��5      $��80��6&   $��0,0,10,0q�61   6C   �� 5      -   5        $
��Save��5      $��80��6$   6/   5      5       5!      