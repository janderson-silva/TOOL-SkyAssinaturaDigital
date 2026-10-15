unit Sky.Main;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.Types,
  Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.Dialogs,
  Vcl.Graphics, Vcl.Imaging.pngimage, Sky.Pdf, Sky.Crypto;

type
  TMainForm = class(TForm)
    BrandMark: TPanel;
    TitleLabel: TLabel;
    SubtitleLabel: TLabel;
    WorkspacePanel: TPanel;
    ViewerPanel: TPanel;
    DocumentToolbar: TPanel;
    StatusPanel: TPanel;
    DocumentLabel: TLabel;
    PageLabel: TLabel;
    SettingsTitle: TLabel;
    CertificateTitle: TLabel;
    WidthLabel: TLabel;
    HeightLabel: TLabel;
    PlacementTitle: TLabel;
    PlacementHint: TLabel;
    SaveHint: TLabel;
    DividerShape: TShape;
    ToolbarPanel: TPanel;
    OptionsPanel: TPanel;
    OpenButton: TButton;
    CertificateButton: TButton;
    PreviousButton: TButton;
    NextButton: TButton;
    SignButton: TButton;
    SizeLabel: TLabel;
    FPaint: TPaintBox;
    FStatus: TLabel;
    FCertLabel: TLabel;
    FWidthEdit: TEdit;
    FHeightEdit: TEdit;
    procedure FormResize(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure CertClick(Sender: TObject);
    procedure PreviousClick(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure SignClick(Sender: TObject);
    procedure PaintPage(Sender: TObject);
    procedure PlaceSignature(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure SizeChanged(Sender: TObject);
  private
    FDocument: TPdfDocument;
    FCertificate: TWindowsCertificate;
    FBitmap: TBitmap;
    FFolder, FInput: string;
    FPage: Integer;
    FPageRect: TRect;
    FX, FY: Double;
    FPlaced, FLoaded: Boolean;
    procedure Render;
    function SignatureWidth: Double;
    function SignatureHeight: Double;
  end;

var MainForm: TMainForm;

implementation

uses System.IOUtils, System.Math;

{$R *.dfm}

procedure TMainForm.FormResize(Sender: TObject);
begin
  if Assigned(FPaint) then FPaint.Invalidate;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var G: TGUID;
begin
  FDocument := TPdfDocument.Create;
  FCertificate := TWindowsCertificate.Create;
  FBitmap := TBitmap.Create;
  CreateGUID(G);
  FFolder := TPath.Combine(TPath.GetTempPath, 'SkyAssinatura-' + GUIDToString(G));
  TDirectory.CreateDirectory(FFolder);
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FBitmap);
  FreeAndNil(FCertificate);
  FreeAndNil(FDocument);
  if FFolder <> '' then
  begin
    DeleteFile(PChar(TPath.Combine(FFolder, 'source.pdf')));
    DeleteFile(PChar(TPath.Combine(FFolder, 'page.png')));
    DeleteFile(PChar(TPath.Combine(FFolder, 'page.png.error')));
    RemoveDir(FFolder);
  end;
end;
function TMainForm.SignatureWidth: Double;
begin
  if not TryStrToFloat(FWidthEdit.Text, Result) or (Result < 80) then
    raise Exception.Create('Largura minima: 80 pontos.');
end;

function TMainForm.SignatureHeight: Double;
begin
  if not TryStrToFloat(FHeightEdit.Text, Result) or (Result < 45) then
    raise Exception.Create('Altura minima: 45 pontos.');
end;

procedure TMainForm.OpenClick(Sender: TObject);
var D: TOpenDialog;
begin
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'Documento PDF|*.pdf'; D.Options := [ofFileMustExist, ofPathMustExist];
    if not D.Execute then Exit;
    FLoaded := False; FPlaced := False; FBitmap.SetSize(0, 0); FPaint.Invalidate;
    DocumentLabel.Caption := 'Visualizacao do documento';
    DocumentLabel.Hint := '';
    PageLabel.Caption := 'Sem documento';
    FInput := D.FileName;
    TFile.Copy(FInput, TPath.Combine(FFolder, 'source.pdf'), True);
    FDocument.Load(TPath.Combine(FFolder, 'source.pdf'));
    FPage := 0;
    Render;
    FLoaded := True;
  finally D.Free; end;
end;

procedure TMainForm.CertClick(Sender: TObject);
begin
  FCertificate.Select(Handle);
  if FCertificate.Context <> nil then
    FCertLabel.Caption := FCertificate.Name
  else FCertLabel.Caption := 'Nenhum certificado selecionado';
  FCertLabel.Hint := FCertLabel.Caption;
end;

procedure TMainForm.Render;
var SI: TStartupInfo; PI: TProcessInformation; Command, Script, Output, ErrorFile: string;
    Code, WaitResult: DWORD; PNG: TPngImage;
begin
  Script := TPath.Combine(ExtractFilePath(Application.ExeName), 'scripts\Render-Pdf.ps1');
  if not TFile.Exists(Script) then raise Exception.Create('Script de visualizacao ausente: ' + Script);
  Output := TPath.Combine(FFolder, 'page.png'); ErrorFile := Output + '.error';
  DeleteFile(PChar(Output)); DeleteFile(PChar(ErrorFile));
  Command := '"' + TPath.Combine(GetEnvironmentVariable('SystemRoot'),
    'System32\WindowsPowerShell\v1.0\powershell.exe') +
    '" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + Script +
    '" -InputPdf "' + TPath.Combine(FFolder, 'source.pdf') + '" -OutputPng "' + Output +
    '" -Page ' + IntToStr(FPage);
  FillChar(SI, SizeOf(SI), 0); SI.cb := SizeOf(SI);
  FillChar(PI, SizeOf(PI), 0); UniqueString(Command);
  Screen.Cursor := crHourGlass;
  try
    if not CreateProcess(nil, PChar(Command), nil, nil, False, CREATE_NO_WINDOW,
      nil, nil, SI, PI) then RaiseLastOSError;
    try
      WaitResult := WaitForSingleObject(PI.hProcess, 60000);
      if WaitResult <> WAIT_OBJECT_0 then
      begin
        TerminateProcess(PI.hProcess, 1);
        WaitForSingleObject(PI.hProcess, 5000);
        raise Exception.Create('A visualizacao excedeu o tempo limite.');
      end;
      if not GetExitCodeProcess(PI.hProcess, Code) then RaiseLastOSError;
      if (Code <> 0) or not TFile.Exists(Output) then
      begin
        if TFile.Exists(ErrorFile) then raise Exception.Create(TFile.ReadAllText(ErrorFile));
        raise Exception.Create('Nao foi possivel renderizar o PDF pelo Windows.');
      end;
    finally CloseHandle(PI.hThread); CloseHandle(PI.hProcess); end;
    PNG := TPngImage.Create;
    try PNG.LoadFromFile(Output); FBitmap.Assign(PNG); finally PNG.Free; end;
    FPlaced := False; FPaint.Invalidate;
    DocumentLabel.Caption := TPath.GetFileName(FInput);
    DocumentLabel.Hint := FInput;
    PageLabel.Caption := Format('%d de %d', [FPage+1, FDocument.PageCount]);
    FStatus.Caption := Format('Pagina %d de %d. Clique para posicionar o canto superior esquerdo.',
      [FPage+1, FDocument.PageCount]);
  finally Screen.Cursor := crDefault; end;
end;

procedure TMainForm.PreviousClick(Sender: TObject);
begin
  if FLoaded and (FPage > 0) then
  begin FLoaded := False; Dec(FPage); Render; FLoaded := True; end;
end;

procedure TMainForm.NextClick(Sender: TObject);
begin
  if FLoaded and (FPage+1 < FDocument.PageCount) then
  begin FLoaded := False; Inc(FPage); Render; FLoaded := True; end;
end;

procedure TMainForm.SizeChanged(Sender: TObject);
begin FPlaced := False; if Assigned(FPaint) then FPaint.Invalidate; end;

procedure TMainForm.PaintPage(Sender: TObject);
var Scale: Double; W, H, X, Y, Gap: Integer; Pg: TPdfPage; R: TRect;
begin
  FPaint.Canvas.Brush.Style := bsSolid;
  FPaint.Canvas.Brush.Color := $00E8E2DD;
  FPaint.Canvas.FillRect(FPaint.ClientRect);
  if not Assigned(FBitmap) then Exit;
  if (FBitmap.Width = 0) or (FBitmap.Height = 0) then
  begin
    FPaint.Canvas.Brush.Style := bsClear;
    FPaint.Canvas.Font.Assign(Font);
    FPaint.Canvas.Font.Color := $007C6F63;
    FPaint.Canvas.Font.Style := [fsBold];
    R := FPaint.ClientRect;
    DrawText(FPaint.Canvas.Handle, 'Abra um PDF para comecar', -1, R,
      DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    FPaint.Canvas.Brush.Style := bsSolid;
    Exit;
  end;
  Gap := MulDiv(24, PixelsPerInch, 96);
  Scale := Min((FPaint.Width-2*Gap)/FBitmap.Width, (FPaint.Height-2*Gap)/FBitmap.Height);
  if Scale <= 0 then Exit;
  W := Round(FBitmap.Width*Scale); H := Round(FBitmap.Height*Scale);
  X := (FPaint.Width-W) div 2; Y := (FPaint.Height-H) div 2;
  FPageRect := Rect(X, Y, X+W, Y+H);
  FPaint.Canvas.Brush.Color := $00CEC5BD;
  R := FPageRect;
  OffsetRect(R, MulDiv(3, PixelsPerInch, 96), MulDiv(4, PixelsPerInch, 96));
  FPaint.Canvas.FillRect(R);
  FPaint.Canvas.StretchDraw(FPageRect, FBitmap);
  if not FPlaced then Exit;
  Pg := FDocument.Page(FPage);
  R := Rect(X+Round(FX/Pg.Width*W), Y+Round((Pg.Height-FY-SignatureHeight)/Pg.Height*H),
    X+Round((FX+SignatureWidth)/Pg.Width*W), Y+Round((Pg.Height-FY)/Pg.Height*H));
  FPaint.Canvas.Brush.Style := bsClear; FPaint.Canvas.Pen.Color := $00D66920;
  FPaint.Canvas.Pen.Width := 2; FPaint.Canvas.Rectangle(R);
  FPaint.Canvas.Font.Assign(Font);
  FPaint.Canvas.Font.Color := $00D66920;
  FPaint.Canvas.TextOut(R.Left+5, R.Top+5, 'Assinatura digital');
  FPaint.Canvas.Pen.Width := 1; FPaint.Canvas.Brush.Style := bsSolid;
end;

procedure TMainForm.PlaceSignature(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var Pg: TPdfPage; W, H: Double;
begin
  if not FLoaded or (Button <> mbLeft) or not PtInRect(FPageRect, Point(X, Y)) then Exit;
  Pg := FDocument.Page(FPage); W := SignatureWidth; H := SignatureHeight;
  if (W > Pg.Width) or (H > Pg.Height) then raise Exception.Create('Bloco maior que a pagina.');
  FX := EnsureRange((X-FPageRect.Left)/FPageRect.Width*Pg.Width, 0.0, Pg.Width-W);
  FY := EnsureRange(Pg.Height-(Y-FPageRect.Top)/FPageRect.Height*Pg.Height-H, 0.0, Pg.Height-H);
  FPlaced := True; FPaint.Invalidate;
end;

procedure TMainForm.SignClick(Sender: TObject);
var D: TSaveDialog;
begin
  if not FLoaded then raise Exception.Create('Abra um PDF.');
  if FCertificate.Context = nil then raise Exception.Create('Selecione o certificado.');
  if not FPlaced then raise Exception.Create('Clique na pagina para posicionar a assinatura.');
  D := TSaveDialog.Create(Self);
  try
    D.Filter := 'Documento PDF|*.pdf'; D.DefaultExt := 'pdf';
    D.FileName := TPath.GetFileNameWithoutExtension(FInput) + '-assinado.pdf';
    if not D.Execute then Exit;
    if TFile.Exists(D.FileName) then raise Exception.Create('Escolha um nome novo. O arquivo ja existe.');
    Screen.Cursor := crHourGlass;
    try
      FDocument.Sign(D.FileName, FPage, FX, FY, SignatureWidth, SignatureHeight, FCertificate);
    finally Screen.Cursor := crDefault; end;
    ShowMessage('PDF salvo: ' + D.FileName + sLineBreak +
      'Confira a assinatura em um leitor de PDF com validacao criptografica.');
  finally D.Free; end;
end;

end.
