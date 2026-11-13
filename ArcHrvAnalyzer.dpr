program ArcHrvAnalyzer;

uses
  Vcl.Forms,
  uMainForm in 'uMainForm.pas' {MainForm},
  uArcHrvEngine in 'uArcHrvEngine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'WeCardio 7.0 (.arc) Holter HRV Analiz Sistemi';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
