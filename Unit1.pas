//--1 Часть (Подключение модулей, определение типов, процедур и функций)--------

unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Samples.Spin, Vcl.StdCtrls, Vcl.Buttons, Vcl.ComCtrls,
  System.Math, Winapi.RichEdit, Vcl.ExtCtrls, Winapi.CommCtrl, System.UITypes, System.IniFiles;

type
  TForm1 = class(TForm)
    edtIP: TEdit;
    seCIDR: TSpinEdit;
    edtSubnetCIDR: TEdit;
    btnCalculate: TSpeedButton;
    reResult: TRichEdit;
    btnSave: TSpeedButton;
    SaveDialog1: TSaveDialog;
    StatusBar1: TStatusBar;
    Timer1: TTimer;
    chkLimit: TCheckBox;
    seLimitValue: TSpinEdit;
    btnCancel: TSpeedButton;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    procedure btnCalculateClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnSaveClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure chkLimitClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure seLimitValueChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure seCIDRChange(Sender: TObject);
    procedure FormClick(Sender: TObject); // НАШЕ НОВОЕ СОБЫТИЕ: Клик по пустому месту формы
  private
    { Private declarations }
    FProgressBar: TProgressBar;
    FCancelCalculation: Boolean;
    FInWarningMode: Boolean;
    procedure edtIPKeyPress(Sender: TObject; var Key: Char);
    procedure edtIPExit(Sender: TObject);
    procedure edtSubnetCIDRKeyPress(Sender: TObject; var Key: Char);
    procedure edtSubnetCIDRExit(Sender: TObject);
    procedure UpdateProgressBarPosition;
    procedure InitAndLoadSettings;
    procedure SaveSettings;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses IPCalcEngine;

{$R *.dfm}

//--2 часть (События при создании и закрытии формы)-----------------------------

procedure TForm1.FormCreate(Sender: TObject);
var
  StatusPanel: TStatusPanel;
begin
  FInWarningMode := True;

  edtIP.Text := '192.168.0.1';
  edtIP.OnKeyPress := edtIPKeyPress;
  edtIP.OnExit := edtIPExit;

  seCIDR.MinValue := 0; seCIDR.MaxValue := 32; seCIDR.Value := 24;
  edtSubnetCIDR.OnKeyPress := edtSubnetCIDRKeyPress;
  edtSubnetCIDR.OnExit := edtSubnetCIDRExit;
  edtSubnetCIDR.Text := '26';

  chkLimit.Caption := 'Ограничить вывод подсетей до:';
  seLimitValue.MinValue := 1;
  seLimitValue.MaxValue := 1000000;

  btnCalculate.Enabled := True;
  btnCancel.Enabled := False;
  btnSave.Enabled := False;
  btnCancel.Caption := 'Стоп / Сброс';
  FCancelCalculation := False;

  reResult.StyleElements := [];
  reResult.Color := clWindow; reResult.Font.Color := clWindowText;

  StatusBar1.Panels.Clear;
  StatusPanel := StatusBar1.Panels.Add; StatusPanel.Width := 230; StatusPanel.Text := '   A.Shcherbakov by Gemini 2026';
  StatusPanel := StatusBar1.Panels.Add; StatusPanel.Width := StatusBar1.ClientWidth - 330; StatusPanel.Text := ' Готово.';
  StatusPanel := StatusBar1.Panels.Add; StatusPanel.Width := 100; StatusPanel.Text := FormatDateTime('               hh:nn:ss', Now);

  FProgressBar := TProgressBar.Create(Self);
  FProgressBar.Parent := StatusBar1; FProgressBar.Visible := False; FProgressBar.Smooth := True;
  UpdateProgressBarPosition;

  Timer1.Interval := 1000; Timer1.OnTimer := Timer1Timer; Timer1.Enabled := True;
  btnSave.OnClick := btnSaveClick;

  seCIDR.OnChange := seCIDRChange;

  // ИСПРАВЛЕНИЕ: Привязываем клик по форме к процедуре
  Self.OnClick := FormClick;

  InitAndLoadSettings;

  FInWarningMode := False;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  SaveSettings;
end;

procedure TForm1.FormClick(Sender: TObject);
begin
  // ИСПРАВЛЕНИЕ: Если пользователь кликнул по форме, принудительно забираем фокус у Edit,
  // что автоматически вызовет шлагбаум проверки edtIPExit
  if Self.ActiveControl = edtIP then
    Self.ActiveControl := nil;
end;

procedure TForm1.chkLimitClick(Sender: TObject);
var
  WarnMsg: string;
  CurrentInputValue: Integer;
begin
  if FInWarningMode then Exit;

  if chkLimit.Checked then
  begin
    CurrentInputValue := StrToIntDef(Trim(seLimitValue.Text), seLimitValue.Value);

    if CurrentInputValue >= 8000 then
    begin
      FInWarningMode := True;
      try
        WarnMsg := Format(
          'ВНИМАНИЕ!' + sLineBreak + sLineBreak +
          '• Зафиксирована попытка установить лимит в %s подсетей.' + sLineBreak +
          '• Нагрузка на буфер компонента вывода сильно возрастёт.' + sLineBreak +
          '• Программа может временно перестать отвечать на запросы.' + sLineBreak + sLineBreak +
          'Вы действительно хотите обойти безопасное ограничение?',
          [FormatFloat('#,##0', CurrentInputValue)]
        );

        if MessageDlg(WarnMsg, mtWarning, [mbYes, mbNo], 0) <> mrYes then
        begin
          seLimitValue.Value := 256;
          chkLimit.Checked := False;
          seLimitValue.Enabled := True;
          SaveSettings;
          Exit;
        end;
      finally
        FInWarningMode := False;
      end;
    end;
  end;

  seLimitValue.Enabled := not chkLimit.Checked;

  if not FInWarningMode then
    SaveSettings;
end;

//3 Часть-----------------------------------------------------------------------

procedure TForm1.btnCancelClick(Sender: TObject);
begin
  FCancelCalculation := True;
  btnCancel.Enabled := False;
  if StatusBar1.Panels.Count > 1 then
    StatusBar1.Panels[1].Text := ' Останавливаю процесс...';
end;

procedure TForm1.UpdateProgressBarPosition;
var
  R: TRect;
begin
  if Assigned(FProgressBar) and (StatusBar1.Panels.Count > 1) then
  begin
    SendMessage(StatusBar1.Handle, SB_GETRECT, 1, LPARAM(@R));
    FProgressBar.Left := R.Left + 189;
    FProgressBar.Top := R.Top + 5;
    FProgressBar.Width := R.Right - R.Left - 200;
    FProgressBar.Height := (R.Bottom - R.Top) - 10;
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  if StatusBar1.Panels.Count > 2 then
    StatusBar1.Panels[2].Text := FormatDateTime('               hh:nn:ss', Now);
end;

procedure TForm1.seCIDRChange(Sender: TObject);
begin
  if FInWarningMode then Exit;

  // 1. ИСПРАВЛЕНИЕ UI-БАГА С ЛИДИРУЮЩИМ НУЛЕМ:
  // Библиотека VCL при изменении свойства Value сама автоматически стирает "024" и превращает в "24"
  if (seCIDR.Value > 0) and (seCIDR.Value <= 32) then
  begin
    FInWarningMode := True;
    try
      // Принудительно перезаписываем значение в себя, заставляя VCL сбросить лишний символ '0' с экрана
      seCIDR.Value := seCIDR.Value;
    finally
      FInWarningMode := False;
    end;
  end;

  // 2. ЖЕСТКИЙ КОНТРОЛЬ ГРАНИЦ СЕТЕВОГО ПРЕФИКСА [0..32]
  if seCIDR.Value > 32 then
  begin
    FInWarningMode := True;
    try seCIDR.Value := 32; finally FInWarningMode := False; end;
  end
  else if seCIDR.Value < 0 then
  begin
    FInWarningMode := True;
    try seCIDR.Value := 0; finally FInWarningMode := False; end;
  end;
end;




//--4 Часть (Инифайл для настроек ограничений при расчете сетей, предупреждение
// при снятии ограничений)------------------------------------------------------

procedure TForm1.InitAndLoadSettings;
var
  Ini: TIniFile;
  IniPath: string;
begin
  IniPath := ExtractFilePath(ParamStr(0)) + 'config.ini';
  Ini := TIniFile.Create(IniPath);
  try
    FInWarningMode := True;

    chkLimit.Checked := Ini.ReadBool('Safety', 'LimitEnabled', True);
    seLimitValue.Value := Ini.ReadInteger('Safety', 'LimitValue', 256);

    if not FileExists(IniPath) then
    begin
      Ini.WriteBool('Safety', 'LimitEnabled', True);
      Ini.WriteInteger('Safety', 'LimitValue', 256);
      Ini.UpdateFile;
    end;

    seLimitValue.Enabled := not chkLimit.Checked;
  finally
    FInWarningMode := False;
    Ini.Free;
  end;
end;

procedure TForm1.SaveSettings;
var
  Ini: TIniFile;
  IniPath: string;
  ActualValue: Integer;
begin
  IniPath := ExtractFilePath(ParamStr(0)) + 'config.ini';
  Ini := TIniFile.Create(IniPath);
  try
    ActualValue := StrToIntDef(Trim(seLimitValue.Text), seLimitValue.Value);
    if ActualValue < 1 then ActualValue := 256;

    Ini.WriteBool('Safety', 'LimitEnabled', chkLimit.Checked);
    Ini.WriteInteger('Safety', 'LimitValue', ActualValue);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure TForm1.seLimitValueChange(Sender: TObject);
begin
  if not FInWarningMode then
    SaveSettings;
end;




//--5 Часть (Ввод IP запятые и точки прилюбых раскладках вводятся как
// точки-разделители октетов, вывод отчета)-------------------------------------

procedure TForm1.edtIPKeyPress(Sender: TObject; var Key: Char);
var
  TextStr: string; List: TStringList; CurrentOctet: string;
begin
  if Key = #8 then Exit;

  if (Key = ',') or (Key = '.') or (Key = '/') or (Key = 'ю') or (Key = 'Ю') or (Key = 'б') or (Key = 'Б') then
    Key := '.';

  if not CharInSet(Key, ['0'..'9', '.']) then begin Key := #0; Exit; end;
  TextStr := edtIP.Text; Insert(Key, TextStr, edtIP.SelStart + 1);
  List := TStringList.Create;
  try
    List.Delimiter := '.'; List.StrictDelimiter := True; List.DelimitedText := TextStr;
    if List.Count > 4 then begin Key := #0; Exit; end;
    if List.Count > 0 then begin
      CurrentOctet := List[List.Count - 1];
      if (Key <> '.') and (Length(CurrentOctet) > 3) then begin Key := #0; Exit; end;
      if (Key <> '.') and (StrToIntDef(List[List.Count - 1], 0) > 255) then begin Key := #0; Exit; end;
    end;
  finally List.Free; end;
end;

procedure TForm1.edtIPExit(Sender: TObject);
var
  List: TStringList; i, Val: Integer;
begin
  if Trim(edtIP.Text) = '' then Exit;

  List := TStringList.Create;
  try
    List.Delimiter := '.'; List.StrictDelimiter := True; List.DelimitedText := edtIP.Text;

    if List.Count <> 4 then begin
      ShowMessage('КРИТИЧЕСКАЯ ОШИБКА!'+ sLineBreak + sLineBreak + '• IPv4-адрес должен состоять строго из 4 октетов (пример: 192.168.0.1).' + sLineBreak);
      edtIP.Text := '';
      edtIP.SetFocus;
      Exit;
    end;

    for i := 0 to 3 do begin
      Val := StrToIntDef(List[i], -1);
      if (Val < 0) or (Val > 255) then begin
        ShowMessage('КРИТИЧЕСКАЯ ОШИБКА!'+ sLineBreak + sLineBreak + '• Значение каждого октета IPv4-адреса должно находиться в диапазоне от 0 до 255.'+ sLineBreak);
        edtIP.Text := '';
        edtIP.SetFocus;
        Exit;
      end;
    end;
  finally List.Free; end;
end;

procedure TForm1.edtSubnetCIDRKeyPress(Sender: TObject; var Key: Char);
var
  CurrentText, FutureText: string; FutureVal: Integer;
begin
  if Key = #8 then Exit;
  if not CharInSet(Key, ['0'..'9']) then begin Key := #0; Exit; end;
  CurrentText := edtSubnetCIDR.Text;
  if edtSubnetCIDR.SelLength > 0 then Delete(CurrentText, edtSubnetCIDR.SelStart + 1, edtSubnetCIDR.SelLength);
  FutureText := CurrentText; Insert(Key, FutureText, edtSubnetCIDR.SelStart + 1);
  if TryStrToInt(FutureText, FutureVal) then begin if (FutureVal < 0) or (FutureVal > 32) then Key := #0; end else Key := #0;
end;

procedure TForm1.edtSubnetCIDRExit(Sender: TObject);
begin
  if Trim(edtSubnetCIDR.Text) = '' then edtSubnetCIDR.Text := IntToStr(seCIDR.Value);
end;

function CleanMaskIP(const MaskText: string): string;
var
  List: TStringList; V3, V2, V1, V0: Integer;
begin
  List := TStringList.Create;
  try
    List.Delimiter := '.'; List.StrictDelimiter := True; List.DelimitedText := Trim(MaskText);
    if List.Count = 4 then begin
      V3 := StrToIntDef(List[0], 0); V2 := StrToIntDef(List[1], 0);
      V1 := StrToIntDef(List[2], 0); V0 := StrToIntDef(List[3], 0);
      Result := IntToStr(V3) + '.' + IntToStr(V2) + '.' + IntToStr(V1) + '.' + IntToStr(V0);
    end else Result := '192.168.0.1';
  finally List.Free; end;
end;



//6 Часть ----------------------------------------------------------------------

 procedure TForm1.btnCalculateClick(Sender: TObject);
var
  BaseInfo, SubnetInfo, SuperInfo: TIPNetworkInfo;
  BaseCIDR, SubCIDR: Byte;
  PrivateText, CleanSubnetText, CleanedIP: string;
  CurrentSubnetNet, EndSubnetNet, SubnetStep: UInt32;
  SubnetCounter: Integer; TempCIDR: Integer;
  TotalSubnets, TotalHostsAll: Int64;
  WarningMsg: string; ActualMaxLimit: Int64;

  procedure PrintSeparatorLine;
  begin
    reResult.SelAttributes.Color := clWindowText; reResult.SelAttributes.Style := [];
    reResult.SelText := '====================================================================================' + sLineBreak;
  end;

  procedure PrintCenter(const TextStr: string; IsBold: Boolean = False);
  var SpacesCount: Integer;
  begin
    if IsBold then reResult.SelAttributes.Style := [fsBold] else reResult.SelAttributes.Style := [];
    reResult.SelAttributes.Color := clWindowText; SpacesCount := (84 - Length(TextStr)) div 2;
    if SpacesCount > 0 then reResult.SelText := StringOfChar(' ', SpacesCount) + TextStr + sLineBreak else reResult.SelText := TextStr + sLineBreak;
    reResult.SelAttributes.Style := [];
  end;

  procedure RenderRow(const LabelText, NormalIPStr: string; ValueUInt32: UInt32; DummyB, DummyS: Byte; const TailText: string; IsHostsCountRow: Boolean = False);
  var FullBinSource: string; k, RealBitCounter, TargetSpaceBit: Integer; FormatStruct: CHARFORMAT2; LeftPart: string; RequiredSpaces: Integer;
  begin
    FillChar(FormatStruct, SizeOf(FormatStruct), 0); FormatStruct.cbSize := SizeOf(FormatStruct); FormatStruct.dwMask := CFM_COLOR;
    reResult.SelAttributes.Color := clWindowText; reResult.SelAttributes.Style := [];
    LeftPart := Format('%-16s %-18s', [LabelText, NormalIPStr]); reResult.SelText := LeftPart;
    RequiredSpaces := 40 - Length(LeftPart); if RequiredSpaces > 0 then reResult.SelText := StringOfChar(' ', RequiredSpaces);

    if IsHostsCountRow then begin
      if TailText <> '' then begin reResult.SelAttributes.Color := clGray; reResult.SelText := TailText; end;
      reResult.SelText := sLineBreak; Exit;
    end;

    FullBinSource := UInt32ToBinStr(ValueUInt32).Replace(' ', '');
    if SubCIDR < BaseCIDR then TargetSpaceBit := BaseCIDR else TargetSpaceBit := SubCIDR; RealBitCounter := 0;
    for k := 1 to Length(FullBinSource) do begin
      if FullBinSource[k] = '.' then begin
        FormatStruct.crTextColor := ColorToRGB(clGray); SendMessage(reResult.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@FormatStruct)); reResult.SelText := '.'; Continue;
      end;
      Inc(RealBitCounter);
      if SubCIDR >= BaseCIDR then begin
        if RealBitCounter <= BaseCIDR then FormatStruct.crTextColor := ColorToRGB(clWindowText)
        else if (RealBitCounter > BaseCIDR) and (RealBitCounter <= SubCIDR) then FormatStruct.crTextColor := ColorToRGB(clRed)
        else FormatStruct.crTextColor := ColorToRGB(clBlue);
      end else begin
        if RealBitCounter <= SubCIDR then FormatStruct.crTextColor := ColorToRGB(clWindowText)
        else if (RealBitCounter > SubCIDR) and (RealBitCounter <= BaseCIDR) then FormatStruct.crTextColor := ColorToRGB(clGreen)
        else FormatStruct.crTextColor := ColorToRGB(clBlue);
      end;
      SendMessage(reResult.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@FormatStruct)); reResult.SelText := FullBinSource[k];
      if (RealBitCounter = TargetSpaceBit) and (TargetSpaceBit < 32) then reResult.SelText := ' ';
    end;
    if TailText <> '' then begin
      FormatStruct.crTextColor := ColorToRGB(clGray); SendMessage(reResult.Handle, EM_SETCHARFORMAT, SCF_SELECTION, LPARAM(@FormatStruct)); reResult.SelText := '   ' + TailText;
    end;
    reResult.SelText := sLineBreak;
  end;






//--7 Часть (Предупреждение о переполнении, и вывод)----------------------------

begin
  // ЖЕСТКОЕ ИСПРАВЛЕНИЕ №1: Перед расчётом принудительно пинаем валидатор edtIPExit.
  edtIPExit(edtIP);

  // Проверка на пустоту или обрезки строк в поле IP-адреса
  if (Trim(edtIP.Text) = '') or (edtIP.Text = '...') or (Length(edtIP.Text) < 7) or (Pos('.', edtIP.Text) = 0) then
  begin
    ShowMessage('КРИТИЧЕСКАЯ ОШИБКА!' + sLineBreak + sLineBreak + 'Поле ввода IP-адреса пустое или содержит некорректные данные. Расчет заблокирован.' + sLineBreak + sLineBreak +'• IPv4-адрес должен состоять строго из 4 октетов (пример: 192.168.0.1).' + sLineBreak +'• Значение каждого октета IPv4-адреса должно находиться в диапазоне от 0 до 255.'+ sLineBreak);
    edtIP.Text := '192.168.0.1';
    edtIP.SetFocus;
    Exit;
  end;

  // ЖЕСТКАЯ ЗАЩИТА №2: Блокируем пустое текстовое поле маски TSpinEdit, если по нему кликнули сразу
  if Trim(seCIDR.Text) = '' then
  begin
    ShowMessage('КРИТИЧЕСКАЯ ОШИБКА!' + sLineBreak + sLineBreak + '• Поле базовой маски (CIDR) не может быть пустым для генерации отчета.' + sLineBreak);
    FInWarningMode := True;
    try seCIDR.Value := 0; finally FInWarningMode := False; end;
    seCIDR.SetFocus;
    Exit;
  end;

  TempCIDR := seCIDR.Value; if (TempCIDR < 0) or (TempCIDR > 32) then TempCIDR := 24; BaseCIDR := Byte(TempCIDR);
  CleanSubnetText := Trim(edtSubnetCIDR.Text); if CleanSubnetText = '' then SubCIDR := BaseCIDR else SubCIDR := StrToIntDef(CleanSubnetText, BaseCIDR); if SubCIDR > 32 then SubCIDR := 32;
  TotalSubnets := 0; if SubCIDR > BaseCIDR then TotalSubnets := Round(Power(2, SubCIDR - BaseCIDR));

  if (SubCIDR > BaseCIDR) and (TotalSubnets > 8192) then begin
    WarningMsg := Format(
      'ВНИМАНИЕ!' + sLineBreak + sLineBreak +
      '• Применяя к базовой маске /%d маску /%d, Вы заставляете программу сгенерировать %s подсетей!' + sLineBreak +
      '• Нагрузка на буфер компонента вывода сильно возрастёт.' + sLineBreak +
      '• Программа может временно перестать отвечать на запросы.' + sLineBreak + sLineBreak +
      'Вы действительно хотите обойти безопасное ограничение?',
      [BaseCIDR, SubCIDR, FormatFloat('#,##0', TotalSubnets)]
    );

    if MessageDlg(WarningMsg, mtWarning, [mbYes, mbNo], 0) <> mrYes then begin
      if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := ' Расчет отменен.';
      Exit;
    end;
  end;

  FCancelCalculation := False; btnCalculate.Enabled := False; btnCancel.Enabled := True; btnSave.Enabled := False;
  reResult.Lines.BeginUpdate;
  try
    reResult.Clear;
    if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := ' Расчет параметров сети...';
    Application.ProcessMessages;

    CleanedIP := CleanMaskIP(edtIP.Text); BaseInfo := CalculateNetworkData(CleanedIP, BaseCIDR);
    if not BaseInfo.IsValid then begin
      reResult.SelAttributes.Color := clRed; reResult.SelAttributes.Style := [fsBold]; reResult.Lines.Add(BaseInfo.ErrorMsg);
      if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := ' Ошибка вычислений.';
      Exit;
    end;
    if BaseInfo.IsPrivate then PrivateText := '(Private Internet RFC 1918)' else PrivateText := '';

    PrintSeparatorLine; PrintCenter('ОТЧЕТ ПО СЕТЕВЫМ ВЫЧИСЛЕНИЯМ', True); PrintSeparatorLine;
    reResult.SelText := sLineBreak;
    PrintCenter(Format('К исходному IP-адресу с базовой маской: %s/%d применяем маску: %s', [CleanedIP, BaseCIDR, Trim(edtSubnetCIDR.Text)]), True);
    reResult.SelText := sLineBreak;
    PrintSeparatorLine; PrintCenter('БАЗОВЫЙ РАСЧЕТ СЕТИ', True); PrintSeparatorLine; reResult.SelText := sLineBreak;

    RenderRow('  Address:', BaseInfo.AddressStr, BaseInfo.IP, BaseCIDR, SubCIDR, '');
    RenderRow('  Netmask:', Format('%s=%d', [BaseInfo.MaskStr, BaseCIDR]), BaseInfo.Mask, BaseCIDR, SubCIDR, '');
    RenderRow('  Wildcard:', BaseInfo.WildcardStr, BaseInfo.Wildcard, BaseCIDR, SubCIDR, '');
    reResult.SelText := sLineBreak; reResult.SelAttributes.Style := []; reResult.SelAttributes.Color := clWindowText; reResult.SelText := '  отсюда:' + sLineBreak + sLineBreak;
    RenderRow('  Network:', Format('%s/%d', [BaseInfo.NetworkStr, BaseCIDR]), BaseInfo.Network, BaseCIDR, SubCIDR, 'Class ' + BaseInfo.NetClass);
    RenderRow('  Broadcast:', BaseInfo.BroadcastStr, BaseInfo.Broadcast, BaseCIDR, SubCIDR, '');
    RenderRow('  HostMin:', BaseInfo.HostMinStr, BaseInfo.HostMin, BaseCIDR, SubCIDR, '');
    RenderRow('  HostMax:', BaseInfo.HostMaxStr, BaseInfo.HostMax, BaseCIDR, SubCIDR, '');
    RenderRow('  Hosts/Net:', IntToStr(BaseInfo.HostsCount), 0, BaseCIDR, SubCIDR, PrivateText, True);

    if SubCIDR < BaseCIDR then begin
      if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := ' Построение отчета суперсети...';
      Application.ProcessMessages;
      reResult.SelText := sLineBreak; PrintSeparatorLine; PrintCenter(Format('РАСЧЕТ СУПЕРСЕТИ (SUPERNET) ДЛЯ МАСКИ /%d', [SubCIDR]), True); PrintSeparatorLine; reResult.SelText := sLineBreak;
      SuperInfo := CalculateNetworkData(BaseInfo.AddressStr, SubCIDR);
      RenderRow('  Supernet mask:', Format('%s=%d', [SuperInfo.MaskStr, SubCIDR]), SuperInfo.Mask, BaseCIDR, SubCIDR, '');
      RenderRow('  Wildcard:', SuperInfo.WildcardStr, SuperInfo.Wildcard, BaseCIDR, SubCIDR, '');
      reResult.SelText := sLineBreak;
      RenderRow('  Network:', Format('%s/%d', [SuperInfo.NetworkStr, SubCIDR]), SuperInfo.Network, BaseCIDR, SubCIDR, 'Class ' + SuperInfo.NetClass);
      RenderRow('  Broadcast:', SuperInfo.BroadcastStr, SuperInfo.Broadcast, BaseCIDR, SubCIDR, '');
      reResult.SelText := sLineBreak;
      RenderRow('  HostMin:', SuperInfo.HostMinStr, SuperInfo.HostMin, BaseCIDR, SubCIDR, '');
      RenderRow('  HostMax:', SuperInfo.HostMaxStr, SuperInfo.HostMax, BaseCIDR, SubCIDR, '');
      RenderRow('  Hosts/Net:', IntToStr(SuperInfo.HostsCount), 0, BaseCIDR, SubCIDR, '', True);
    end;

    if SubCIDR > BaseCIDR then begin
      reResult.Lines.Add(''); PrintSeparatorLine; PrintCenter('РАСЧЕТ ВЫДЕЛЕННЫХ ПОДСЕТЕЙ', True); PrintSeparatorLine;
      CurrentSubnetNet := BaseInfo.Network; EndSubnetNet := BaseInfo.Broadcast;
      SubnetStep := UInt32(1) shl (32 - SubCIDR); SubnetCounter := 0;
      SubnetInfo := CalculateNetworkData(UInt32ToIPStr(CurrentSubnetNet), SubCIDR); TotalHostsAll := TotalSubnets * SubnetInfo.HostsCount;

      reResult.SelText := sLineBreak;
      RenderRow('  Sub. Netmask:', Format('%s=%d', [SubnetInfo.MaskStr, SubCIDR]), SubnetInfo.Mask, BaseCIDR, SubCIDR, '');
      RenderRow('  Wildcard:', SubnetInfo.WildcardStr, SubnetInfo.Wildcard, BaseCIDR, SubCIDR, ''); reResult.SelText := sLineBreak;

      if chkLimit.Checked then ActualMaxLimit := seLimitValue.Value else ActualMaxLimit := TotalSubnets;
      FProgressBar.Min := 0; if TotalSubnets > ActualMaxLimit then FProgressBar.Max := ActualMaxLimit else FProgressBar.Max := TotalSubnets;
      FProgressBar.Position := 0; FProgressBar.Visible := True; UpdateProgressBarPosition;

      while CurrentSubnetNet < EndSubnetNet do begin
        if FCancelCalculation then begin
          reResult.SelText := sLineBreak; reResult.SelAttributes.Color := RGB(255, 128, 0); reResult.SelAttributes.Style := [fsBold];
          reResult.SelText := '⚠️ ГЕНЕРАЦИЯ ОТЧЕТА ПРЕРВАНА ПОЛЬЗОВАТЕЛЕМ!' + sLineBreak; Break;
        end;
        Inc(SubnetCounter);
        if (SubnetCounter mod 10 = 0) or (SubnetCounter <= FProgressBar.Max) then begin
          if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := Format(' Расчет подсети %d...', [SubnetCounter]);
          if SubnetCounter <= FProgressBar.Max then FProgressBar.Position := SubnetCounter; Application.ProcessMessages;
        end;
        if SubnetCounter > ActualMaxLimit then begin
          reResult.SelText := sLineBreak; reResult.SelAttributes.Color := clRed; reResult.SelAttributes.Style := [fsBold];
          reResult.SelText := Format('... Вывод ограничен настройками безопасности буфера.' + sLineBreak + '... Отображены первые %s подсетей из %s.', [FormatFloat('#,##0', ActualMaxLimit), FormatFloat('#,##0', TotalSubnets)]) + sLineBreak + sLineBreak; Break;
        end;
        SubnetInfo := CalculateNetworkData(UInt32ToIPStr(CurrentSubnetNet), SubCIDR);
        reResult.SelAttributes.Color := clRed; reResult.SelAttributes.Style := [fsBold];
        reResult.SelText := Format('--- ПОДСЕТЬ №%d (%s/%d) ---', [SubnetCounter, SubnetInfo.NetworkStr, SubCIDR]) + sLineBreak;
        reResult.SelAttributes.Style := []; reResult.SelText := sLineBreak;
        RenderRow('  Network:', SubnetInfo.NetworkStr, SubnetInfo.Network, BaseCIDR, SubCIDR, 'Class ' + SubnetInfo.NetClass);
        RenderRow('  Broadcast:', SubnetInfo.BroadcastStr, SubnetInfo.Broadcast, BaseCIDR, SubCIDR, '');
        RenderRow('  HostMin:', SubnetInfo.HostMinStr, SubnetInfo.HostMin, BaseCIDR, SubCIDR, '');
        RenderRow('  HostMax:', SubnetInfo.HostMaxStr, SubnetInfo.HostMax, BaseCIDR, SubCIDR, '');
        RenderRow('  Hosts/Net:', IntToStr(SubnetInfo.HostsCount), 0, BaseCIDR, SubCIDR, PrivateText, True); reResult.SelText := sLineBreak;
        if $FFFFFFFF - CurrentSubnetNet < SubnetStep then Break; CurrentSubnetNet := CurrentSubnetNet + SubnetStep;
      end;
      PrintSeparatorLine; reResult.SelAttributes.Color := clWindowText; reResult.SelAttributes.Style := [fsBold];
      reResult.SelText := '  Подсетей:  ' + FormatFloat('#,##0', TotalSubnets) + sLineBreak;
      reResult.SelAttributes.Color := clWindowText; reResult.SelAttributes.Style := [fsBold];
      reResult.SelText := '  Хостов:    ' + FormatFloat('#,##0', TotalHostsAll) + sLineBreak; PrintSeparatorLine; reResult.SelAttributes.Style := [];
    end;

    if FCancelCalculation then begin
      if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := ' Расчет прерван.';
    end else begin
      if StatusBar1.Panels.Count > 1 then StatusBar1.Panels[1].Text := ' Готово.';
 btnSave.Enabled := True;
end;
FProgressBar.Visible := False;
finally
btnCalculate.Enabled := True; btnCancel.Enabled := False; reResult.Lines.EndUpdate;
reResult.SelStart := 0; reResult.SelLength := 0; SendMessage(reResult.Handle, EM_SCROLLCARET, 0, 0);
end;
end;
procedure TForm1.btnSaveClick(Sender: TObject);
begin
if reResult.Lines.Count = 0 then begin ShowMessage('Сначала выполните расчет сети!'); Exit; end;
SaveDialog1.Filter := 'Документ RTF (.rtf)|.rtf|Документ Word (.doc)|.doc';
SaveDialog1.DefaultExt := 'rtf'; SaveDialog1.Title := 'Сохранить отчет';
SaveDialog1.FileName := 'Отчет от ' + FormatDateTime('dd.mm.yyyy_hh-nn-ss', Now);
if SaveDialog1.Execute then begin
try reResult.Lines.SaveToFile(SaveDialog1.FileName); ShowMessage('Отчет успешно сохранен!');
except on E: Exception do ShowMessage('Ошибка при сохранении файла: ' + E.Message); end;
end;
end;
end.
















