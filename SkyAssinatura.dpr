program SkyAssinatura;

uses
  Vcl.Forms,
  Sky.Main in 'src\Sky.Main.pas' {MainForm},
  Sky.Crypto in 'src\Sky.Crypto.pas',
  Sky.Pdf in 'src\Sky.Pdf.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Sky Assinatura Digital';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
