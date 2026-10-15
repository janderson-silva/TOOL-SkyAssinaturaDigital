object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Sky Assinatura Digital'
  ClientHeight = 800
  ClientWidth = 1240
  Color = 15921906
  Constraints.MinHeight = 820
  Constraints.MinWidth = 1080
  Font.Charset = DEFAULT_CHARSET
  Font.Color = 3748140
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  WindowState = wsMaximized
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnResize = FormResize
  TextHeight = 17
  object ToolbarPanel: TPanel
    Left = 0
    Top = 0
    Width = 1240
    Height = 88
    Align = alTop
    BevelOuter = bvNone
    Color = clWhite
    ParentBackground = False
    TabOrder = 0
    DesignSize = (
      1240
      88)
    object TitleLabel: TLabel
      Left = 82
      Top = 18
      Width = 236
      Height = 31
      Caption = 'Sky Assinatura Digital'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 3748140
      Font.Height = -23
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object SubtitleLabel: TLabel
      Left = 83
      Top = 51
      Width = 185
      Height = 17
      Caption = 'Seu documento. Sua assinatura.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 8156016
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object BrandMark: TPanel
      Left = 24
      Top = 22
      Width = 44
      Height = 44
      BevelOuter = bvNone
      Caption = 'S'
      Color = 14051616
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -25
      Font.Name = 'Segoe UI'
      Font.Style = [fsBold]
      ParentBackground = False
      ParentFont = False
      TabOrder = 1
    end
    object OpenButton: TButton
      Left = 1056
      Top = 24
      Width = 160
      Height = 40
      Anchors = [akTop, akRight]
      Caption = 'Abrir PDF...'
      TabOrder = 0
      OnClick = OpenClick
    end
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 762
    Width = 1240
    Height = 38
    Align = alBottom
    BevelOuter = bvNone
    Color = clWhite
    Padding.Left = 24
    Padding.Right = 24
    ParentBackground = False
    TabOrder = 2
    object FStatus: TLabel
      Left = 24
      Top = 0
      Width = 1192
      Height = 38
      Align = alClient
      AutoSize = False
      Caption = 'Comece abrindo um documento PDF.'
      EllipsisPosition = epEndEllipsis
      Font.Charset = DEFAULT_CHARSET
      Font.Color = 8156016
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      Layout = tlCenter
    end
  end
  object WorkspacePanel: TPanel
    Left = 0
    Top = 88
    Width = 1240
    Height = 674
    Align = alClient
    BevelOuter = bvNone
    Color = 15921906
    Padding.Left = 20
    Padding.Top = 20
    Padding.Right = 20
    Padding.Bottom = 20
    ParentBackground = False
    TabOrder = 1
    object OptionsPanel: TPanel
      Left = 920
      Top = 20
      Width = 300
      Height = 634
      Align = alRight
      BevelOuter = bvNone
      Color = clWhite
      ParentBackground = False
      TabOrder = 1
      DesignSize = (
        300
        634)
      object SettingsTitle: TLabel
        Left = 24
        Top = 24
        Width = 137
        Height = 28
        Caption = 'Sua assinatura'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 3748140
        Font.Height = -20
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object CertificateTitle: TLabel
        Left = 24
        Top = 78
        Width = 113
        Height = 13
        Caption = 'CERTIFICADO DIGITAL'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8156016
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object FCertLabel: TLabel
        Left = 24
        Top = 106
        Width = 252
        Height = 68
        AutoSize = False
        Caption = 'Nenhum certificado selecionado'
        ParentShowHint = False
        ShowHint = True
        WordWrap = True
      end
      object DividerShape: TShape
        Left = 24
        Top = 246
        Width = 252
        Height = 1
        Brush.Color = 15130848
        Pen.Style = psClear
      end
      object SizeLabel: TLabel
        Left = 24
        Top = 270
        Width = 147
        Height = 13
        Caption = 'TAMANHO DA ASSINATURA'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8156016
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object WidthLabel: TLabel
        Left = 24
        Top = 300
        Width = 69
        Height = 17
        Caption = 'Largura (pt)'
      end
      object HeightLabel: TLabel
        Left = 160
        Top = 300
        Width = 58
        Height = 17
        Caption = 'Altura (pt)'
      end
      object PlacementTitle: TLabel
        Left = 24
        Top = 390
        Width = 185
        Height = 17
        Caption = 'Escolha o local no documento'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 14051616
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
      end
      object PlacementHint: TLabel
        Left = 24
        Top = 420
        Width = 252
        Height = 65
        AutoSize = False
        Caption = 
          'Clique na pagina para posicionar a assinatura. Para mudar o loca' +
          'l, clique novamente.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8156016
        Font.Height = -13
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        WordWrap = True
      end
      object SaveHint: TLabel
        Left = 24
        Top = 586
        Width = 252
        Height = 18
        Alignment = taCenter
        Anchors = [akLeft, akRight, akBottom]
        AutoSize = False
        Caption = 'O original permanece preservado.'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = 8156016
        Font.Height = -11
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object CertificateButton: TButton
        Left = 24
        Top = 186
        Width = 252
        Height = 36
        Caption = 'Selecionar certificado...'
        TabOrder = 0
        OnClick = CertClick
      end
      object WidthDecreaseButton: TButton
        Left = 24
        Top = 326
        Width = 26
        Height = 32
        Hint = 'Diminuir largura em 10 pontos (minimo: 80 pt)'
        Caption = '-'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
        OnClick = AdjustSizeClick
      end
      object WidthIncreaseButton: TButton
        Left = 114
        Top = 326
        Width = 26
        Height = 32
        Hint = 'Aumentar largura em 10 pontos'
        Caption = '+'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        OnClick = AdjustSizeClick
      end
      object HeightDecreaseButton: TButton
        Left = 160
        Top = 326
        Width = 26
        Height = 32
        Hint = 'Diminuir altura em 10 pontos (minimo: 45 pt)'
        Caption = '-'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
        OnClick = AdjustSizeClick
      end
      object HeightIncreaseButton: TButton
        Left = 250
        Top = 326
        Width = 26
        Height = 32
        Hint = 'Aumentar altura em 10 pontos'
        Caption = '+'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
        OnClick = AdjustSizeClick
      end
      object FWidthEdit: TEdit
        Left = 54
        Top = 326
        Width = 56
        Height = 32
        AutoSize = False
        TabOrder = 2
        Text = '220'
        OnChange = SizeChanged
      end
      object FHeightEdit: TEdit
        Left = 190
        Top = 326
        Width = 56
        Height = 32
        AutoSize = False
        TabOrder = 5
        Text = '60'
        OnChange = SizeChanged
      end
      object SignButton: TButton
        Left = 24
        Top = 528
        Width = 252
        Height = 44
        Anchors = [akLeft, akRight, akBottom]
        Caption = 'Assinar e salvar PDF'
        Default = True
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -14
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 7
        OnClick = SignClick
      end
    end
    object ViewerPanel: TPanel
      Left = 20
      Top = 20
      Width = 900
      Height = 634
      Align = alClient
      BevelOuter = bvNone
      Color = 15921906
      Padding.Right = 20
      ParentBackground = False
      TabOrder = 0
      object FPaint: TPaintBox
        Left = 0
        Top = 58
        Width = 880
        Height = 576
        Align = alClient
        OnMouseDown = PlaceSignature
        OnPaint = PaintPage
      end
      object DocumentToolbar: TPanel
        Left = 0
        Top = 0
        Width = 880
        Height = 58
        Align = alTop
        BevelOuter = bvNone
        Color = clWhite
        ParentBackground = False
        TabOrder = 0
        DesignSize = (
          880
          58)
        object DocumentLabel: TLabel
          Left = 18
          Top = 19
          Width = 456
          Height = 22
          Anchors = [akLeft, akTop, akRight]
          AutoSize = False
          Caption = 'Visualizacao do documento'
          EllipsisPosition = epPathEllipsis
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 3748140
          Font.Height = -14
          Font.Name = 'Segoe UI'
          Font.Style = [fsBold]
          ParentFont = False
          ParentShowHint = False
          ShowHint = True
        end
        object PageLabel: TLabel
          Left = 578
          Top = 20
          Width = 106
          Height = 18
          Alignment = taCenter
          Anchors = [akTop, akRight]
          AutoSize = False
          Caption = 'Sem documento'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = 8156016
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object PreviousButton: TButton
          Left = 488
          Top = 12
          Width = 86
          Height = 34
          Anchors = [akTop, akRight]
          Caption = 'Anterior'
          TabOrder = 0
          OnClick = PreviousClick
        end
        object NextButton: TButton
          Left = 688
          Top = 12
          Width = 86
          Height = 34
          Anchors = [akTop, akRight]
          Caption = 'Proxima'
          TabOrder = 1
          OnClick = NextClick
        end
      end
    end
  end
end
