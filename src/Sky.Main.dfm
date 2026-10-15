object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Sky Assinatura Digital - PDF'
  ClientHeight = 790
  ClientWidth = 1080
  Color = clBtnFace
  Constraints.MinHeight = 600
  Constraints.MinWidth = 850
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -13
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 17
  object FPaint: TPaintBox
    Left = 0
    Top = 120
    Width = 1080
    Height = 645
    Align = alClient
    OnMouseDown = PlaceSignature
    OnPaint = PaintPage
  end
  object FStatus: TLabel
    Left = 0
    Top = 765
    Width = 1080
    Height = 25
    Align = alBottom
    AutoSize = False
    Caption = 'Abra um PDF e clique na pagina para posicionar a assinatura.'
    Layout = tlCenter
  end
  object ToolbarPanel: TPanel
    Left = 0
    Top = 0
    Width = 1080
    Height = 50
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ExplicitWidth = 1078
    object OpenButton: TButton
      Left = 10
      Top = 10
      Width = 100
      Height = 30
      Caption = 'Abrir PDF'
      TabOrder = 0
      OnClick = OpenClick
    end
    object CertificateButton: TButton
      Left = 120
      Top = 10
      Width = 110
      Height = 30
      Caption = 'Certificado'
      TabOrder = 1
      OnClick = CertClick
    end
    object PreviousButton: TButton
      Left = 240
      Top = 10
      Width = 85
      Height = 30
      Caption = 'Anterior'
      TabOrder = 2
      OnClick = PreviousClick
    end
    object NextButton: TButton
      Left = 335
      Top = 10
      Width = 85
      Height = 30
      Caption = 'Proxima'
      TabOrder = 3
      OnClick = NextClick
    end
    object SignButton: TButton
      Left = 430
      Top = 10
      Width = 140
      Height = 30
      Caption = 'Assinar e salvar'
      TabOrder = 4
      OnClick = SignClick
    end
  end
  object OptionsPanel: TPanel
    Left = 0
    Top = 50
    Width = 1080
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 1
    ExplicitWidth = 1078
    DesignSize = (
      1080
      70)
    object SizeLabel: TLabel
      Left = 10
      Top = 10
      Width = 118
      Height = 17
      Caption = 'Largura / altura (pt):'
    end
    object FCertLabel: TLabel
      Left = 10
      Top = 40
      Width = 1060
      Height = 20
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'Certificado: nenhum selecionado'
      ParentShowHint = False
      ShowHint = True
    end
    object FWidthEdit: TEdit
      Left = 155
      Top = 7
      Width = 60
      Height = 25
      TabOrder = 0
      Text = '220'
      OnChange = SizeChanged
    end
    object FHeightEdit: TEdit
      Left = 225
      Top = 7
      Width = 60
      Height = 25
      TabOrder = 1
      Text = '60'
      OnChange = SizeChanged
    end
  end
end
