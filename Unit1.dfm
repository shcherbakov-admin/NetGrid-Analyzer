object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = ' NetGrid Analyzer (v1.0)'
  ClientHeight = 611
  ClientWidth = 712
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poMainFormCenter
  OnCreate = FormCreate
  TextHeight = 15
  object btnCalculate: TSpeedButton
    Left = 8
    Top = 489
    Width = 697
    Height = 24
    Caption = #1056#1072#1089#1089#1095#1080#1090#1072#1090#1100
    OnClick = btnCalculateClick
  end
  object btnSave: TSpeedButton
    Left = 8
    Top = 549
    Width = 697
    Height = 24
    Caption = #1057#1086#1093#1088#1072#1085#1080#1090#1100
    OnClick = btnSaveClick
  end
  object btnCancel: TSpeedButton
    Left = 8
    Top = 519
    Width = 697
    Height = 24
    Caption = #1057#1073#1088#1086#1089
    OnClick = btnCancelClick
  end
  object Label1: TLabel
    Left = 8
    Top = 5
    Width = 179
    Height = 15
    Caption = #1048#1089#1093#1086#1076#1085#1099#1081' IP  c  '#1073#1072#1079#1086#1074#1086#1081'  '#1084#1072#1089#1082#1086#1081
  end
  object Label2: TLabel
    Left = 100
    Top = 27
    Width = 5
    Height = 15
    Caption = '/'
  end
  object Label3: TLabel
    Left = 261
    Top = 5
    Width = 82
    Height = 15
    Caption = #1062#1077#1083#1077#1074#1072#1103' '#1084#1072#1089#1082#1072
  end
  object Label4: TLabel
    Left = 194
    Top = 27
    Width = 61
    Height = 15
    Caption = #1087#1088#1080#1084#1077#1085#1080#1090#1100
  end
  object Label5: TLabel
    Left = 430
    Top = 5
    Width = 162
    Height = 15
    Caption = #1041#1077#1079#1086#1087#1072#1089#1085#1086#1089#1090#1100' '#1073#1091#1092#1077#1088#1072' '#1087#1072#1084#1103#1090#1080
  end
  object reResult: TRichEdit
    Left = 8
    Top = 54
    Width = 697
    Height = 424
    Font.Charset = RUSSIAN_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
    StyleElements = [seBorder]
  end
  object seCIDR: TSpinEdit
    Left = 108
    Top = 24
    Width = 81
    Height = 24
    MaxValue = 32
    MinValue = 0
    TabOrder = 1
    Value = 24
  end
  object edtSubnetCIDR: TEdit
    Left = 261
    Top = 24
    Width = 81
    Height = 23
    TabOrder = 2
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 588
    Width = 712
    Height = 23
    Panels = <>
  end
  object edtIP: TEdit
    Left = 7
    Top = 24
    Width = 90
    Height = 23
    TabOrder = 4
  end
  object chkLimit: TCheckBox
    Left = 429
    Top = 26
    Width = 201
    Height = 17
    Caption = #1054#1075#1088#1072#1085#1080#1095#1080#1090#1100' '#1074#1099#1074#1086#1076' '#1087#1086#1076#1089#1077#1090#1077#1081' '#1076#1086':'
    TabOrder = 5
    OnClick = chkLimitClick
  end
  object seLimitValue: TSpinEdit
    Left = 631
    Top = 24
    Width = 74
    Height = 24
    MaxValue = 0
    MinValue = 0
    TabOrder = 6
    Value = 0
  end
  object SaveDialog1: TSaveDialog
    Left = 664
    Top = 72
  end
  object Timer1: TTimer
    Left = 592
    Top = 72
  end
end
