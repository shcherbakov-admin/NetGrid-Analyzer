program NetGridSuite;

uses
  Vcl.Forms,
  Unit1 in 'Unit1.pas' {Form1},
  IPCalcEngine in 'IPCalcEngine.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Golden Graphite');
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
