(******************************************,
**           ~W~A~N~D~E~R~                **
** ��������� ����� ������������� ����     **
**   ����������� �������� ����� aka       **
**       BreakMeThunder :)                **
**           Compiler: Borland Delphi 7.0 **
'******************************************)
program wander;

uses
  Forms,
  {$IF COMPILERVERSION < 18}
  PNGExtra in 'PNGImage\PNGExtra.pas',
  PNGImage in 'PNGImage\PNGImage.pas',
  PNGLang in 'PNGImage\PNGLang.pas',
  ZLibPas in 'PNGImage\ZLibPas.pas',
  {$IFEND}
  main in 'main.pas' {MainForm},
  cons in 'cons.pas',
  msg in 'msg.pas',
  utils in 'utils.pas',
  player in 'player.pas',
  map in 'map.pas',
  tile in 'tile.pas',
  monsters in 'monsters.pas',
  flags in 'flags.pas',
  items in 'items.pas',
  help in 'help.pas',
  ability in 'ability.pas',
  mapeditor in 'mapeditor.pas' {MainEdForm},
  conf in 'conf.pas',
  sutils in 'sutils.pas',
  wlog in 'wlog.pas',
  vars in 'vars.pas',
  mbox in 'mbox.pas',
  liquid in 'liquid.pas',
  intro in 'intro.pas';

{$R *.res}

begin
  Randomize;
  {$IF COMPILERVERSION >= 18}
  ReportMemoryLeaksOnShutdown := True;
  {$IFEND}
  Application.Initialize;
  Application.Title := 'WANDER';
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TMainEdForm, MainEdForm);
  Application.Run;
end.
