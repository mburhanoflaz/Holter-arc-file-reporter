object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 
    '(*.arc) Holter HRV Analiz ve Raporlama Sistemi - Dr.M.Burhan Ofl' +
    'az- NEU MTF Pediatrik Kardiyoloji BD - Konya / TURKiYE (mburhano' +
    'flaz@gmail.com)'
  ClientHeight = 736
  ClientWidth = 1174
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object pnlTop: TPanel
    Left = 0
    Top = 0
    Width = 1174
    Height = 56
    Align = alTop
    BevelOuter = bvNone
    Color = 15790320
    ParentBackground = False
    TabOrder = 0
    object lblStartHour: TLabel
      Left = 456
      Top = 20
      Width = 97
      Height = 15
      Caption = 'Tak'#305'l'#305#351' Saati (0-23):'
    end
    object btnOpenArc: TButton
      Left = 12
      Top = 13
      Width = 135
      Height = 30
      Caption = '1. .ARC Dosyas'#305' Se'#231'...'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 0
      OnClick = btnOpenArcClick
    end
    object edtFilePath: TEdit
      Left = 155
      Top = 16
      Width = 285
      Height = 23
      ReadOnly = True
      TabOrder = 1
      TextHint = 'Hen'#252'z dosya se'#231'ilmedi...'
    end
    object edtStartHour: TEdit
      Left = 553
      Top = 16
      Width = 42
      Height = 23
      Alignment = taCenter
      TabOrder = 2
      Text = '10'
    end
    object btnAnalyze: TButton
      Left = 605
      Top = 13
      Width = 125
      Height = 30
      Caption = '2. Analizi Ba'#351'lat'
      Enabled = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
      TabOrder = 3
      OnClick = btnAnalyzeClick
    end
    object btnExtractFiles: TButton
      Left = 742
      Top = 13
      Width = 195
      Height = 30
      Caption = '.ARC '#304#231'eri'#287'ini Klas'#246're '#199#305'kar...'
      Enabled = False
      TabOrder = 4
      OnClick = btnExtractFilesClick
    end
    object btnSaveRtf: TButton
      Left = 949
      Top = 13
      Width = 160
      Height = 30
      Caption = 'Raporu .RTF Kaydet...'
      Enabled = False
      TabOrder = 5
      OnClick = btnSaveRtfClick
    end
  end
  object pgMain: TPageControl
    Left = 0
    Top = 56
    Width = 1174
    Height = 657
    ActivePage = tsSummary
    Align = alClient
    TabOrder = 1
    object tsSummary: TTabSheet
      Caption = 'HRV '#214'zet & Frekans Analizi'
      object sgSummary: TStringGrid
        Left = 0
        Top = 0
        Width = 1166
        Height = 627
        Align = alClient
        ColCount = 4
        DefaultColWidth = 260
        DefaultRowHeight = 26
        RowCount = 27
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
        TabOrder = 0
        RowHeights = (
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26
          26)
      end
    end
    object tsCharts: TTabSheet
      Caption = 'HRV Grafikleri (Takogram / Otonom / Poincar'#233')'
      ImageIndex = 1
      object pbHrvCharts: TPaintBox
        Left = 0
        Top = 0
        Width = 1166
        Height = 627
        Align = alClient
        OnPaint = pbHrvChartsPaint
        ExplicitWidth = 1172
        ExplicitHeight = 651
      end
    end
    object tsHourly: TTabSheet
      Caption = '24 Saatlik Detay Tablosu'
      ImageIndex = 2
      object sgHourly: TStringGrid
        Left = 0
        Top = 0
        Width = 1166
        Height = 627
        Align = alClient
        ColCount = 13
        DefaultColWidth = 88
        RowCount = 25
        Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goRowSelect]
        TabOrder = 0
      end
    end
    object tsEcg: TTabSheet
      Caption = '3-Kanall'#305' Ham EKG '#214'nizleme'
      ImageIndex = 3
      object pbEcg: TPaintBox
        Left = 0
        Top = 40
        Width = 1166
        Height = 587
        Align = alClient
        OnPaint = pbEcgPaint
        ExplicitWidth = 1172
        ExplicitHeight = 611
      end
      object pnlEcgCtrl: TPanel
        Left = 0
        Top = 0
        Width = 1166
        Height = 40
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblEcgHour: TLabel
          Left = 16
          Top = 12
          Width = 146
          Height = 15
          Caption = 'G'#246'r'#252'nt'#252'lenecek Saat (0-23):'
        end
        object lblEcgTimeInfo: TLabel
          Left = 580
          Top = 12
          Width = 117
          Height = 15
          Caption = '1. Saat (10 sn pencere)'
        end
        object tbEcgHour: TTrackBar
          Left = 148
          Top = 6
          Width = 420
          Height = 28
          Max = 23
          Position = 1
          TabOrder = 0
          OnChange = tbEcgHourChange
        end
      end
    end
    object tsRtfReport: TTabSheet
      Caption = 'Klinik Rapor (RTF '#199#305'kt'#305's'#305')'
      ImageIndex = 4
      object reReport: TRichEdit
        Left = 0
        Top = 0
        Width = 1166
        Height = 627
        Align = alClient
        Font.Charset = TURKISH_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Consolas'
        Font.Style = []
        ParentFont = False
        ScrollBars = ssBoth
        TabOrder = 0
      end
    end
  end
  object sbStatus: TStatusBar
    Left = 0
    Top = 713
    Width = 1174
    Height = 23
    Panels = <
      item
        Text = 'Haz'#305'r. Bir .arc Holter kayd'#305' se'#231'in.'
        Width = 800
      end
      item
        Text = '(arc file)'
        Width = 380
      end>
  end
  object dlgOpenArc: TOpenDialog
    Filter = 'WeCardio Holter Dosyas'#305' (*.arc)|*.arc|T'#252'm Dosyalar (*.*)|*.*'
    Title = 'Holter Hasta Kayd'#305' (.arc) Se'#231'in'
    Left = 1040
    Top = 88
  end
  object dlgSaveRtf: TSaveDialog
    DefaultExt = 'rtf'
    Filter = 'Zengin Metin Belgesi (*.rtf)|*.rtf'
    Title = 'HRV Klinik Raporunu Kaydet'
    Left = 1104
    Top = 88
  end
end
