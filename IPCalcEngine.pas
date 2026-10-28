unit IPCalcEngine;

interface

uses
  System.SysUtils, System.Classes;

type
  TIPNetworkInfo = record
    IsValid: Boolean;
    ErrorMsg: string;
    IP: UInt32;
    Mask: UInt32;
    Network: UInt32;
    Broadcast: UInt32;
    Wildcard: UInt32;
    HostMin: UInt32;
    HostMax: UInt32;
    HostsCount: Int64;
    NetClass: Char;
    IsPrivate: Boolean;
    AddressStr: string;
    MaskStr: string;
    NetworkStr: string;
    BroadcastStr: string;
    HostMinStr: string;
    HostMaxStr: string;
    WildcardStr: string;
  end;

function IPStrToUInt32(const IPStr: string): UInt32;
function UInt32ToIPStr(IPAsUInt32: UInt32): string;
function UInt32ToBinStr(ValueUInt32: UInt32): string;
function CalculateNetworkData(const IPStr: string; CIDR: Byte): TIPNetworkInfo;

implementation

function IPStrToUInt32(const IPStr: string): UInt32;
var
  List: TStringList;
  i: Integer;
  ByteVal: Integer;
begin
  Result := 0;
  List := TStringList.Create;
  try
    List.Delimiter := '.';
    List.StrictDelimiter := True;
    List.DelimitedText := IPStr;
    if List.Count <> 4 then Exit;
    for i := 0 to 3 do
    begin
      ByteVal := StrToIntDef(List[i], -1);
      if (ByteVal < 0) or (ByteVal > 255) then begin Result := 0; Exit; end;
      Result := (Result shl 8) or UInt32(ByteVal);
    end;
  finally
    List.Free;
  end;
end;

function UInt32ToIPStr(IPAsUInt32: UInt32): string;
begin
  Result := Format('%d.%d.%d.%d', [
    (IPAsUInt32 shl  0) shr 24,
    (IPAsUInt32 shl  8) shr 24,
    (IPAsUInt32 shl 16) shr 24,
    (IPAsUInt32 shl 24) shr 24
  ]);
end;

function UInt32ToBinStr(ValueUInt32: UInt32): string;
var
  i: Integer;
begin
  Result := '';
  for i := 31 downto 0 do
  begin
    if (ValueUInt32 and (UInt32(1) shl i)) <> 0 then
      Result := Result + '1'
    else
      Result := Result + '0';
    if (i mod 8 = 0) and (i <> 0) then
      Result := Result + '.';
  end;
end;

function CalculateNetworkData(const IPStr: string; CIDR: Byte): TIPNetworkInfo;
var
  FirstOctet: Byte;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.IsValid := False;

  if (CIDR < 0) or (CIDR > 32) then
  begin
    Result.ErrorMsg := 'Маска CIDR должна быть в диапазоне от 0 до 32.';
    Exit;
  end;

  Result.IP := IPStrToUInt32(IPStr);
  if (Result.IP = 0) and (Trim(IPStr) <> '0.0.0.0') then
  begin
    Result.ErrorMsg := 'Некорректный синтаксис или формат IPv4 адреса.';
    Exit;
  end;

  Result.AddressStr := UInt32ToIPStr(Result.IP);

  if CIDR = 0 then
    Result.Mask := 0
  else
    Result.Mask := not ( (UInt32(1) shl (32 - CIDR)) - 1 );

  Result.Wildcard := not Result.Mask;
  Result.Network := Result.IP and Result.Mask;
  Result.Broadcast := Result.Network or Result.Wildcard;

  // ОПРЕДЕЛЕНИЕ КЛАССА СЕТИ И ПРИВАТНОСТИ (RFC 1918)
  FirstOctet := Byte(Result.IP shr 24);
  if (FirstOctet >= 1) and (FirstOctet <= 126) then Result.NetClass := 'A'
  else if (FirstOctet >= 128) and (FirstOctet <= 191) then Result.NetClass := 'B'
  else if (FirstOctet >= 192) and (FirstOctet <= 223) then Result.NetClass := 'C'
  else if (FirstOctet >= 224) and (FirstOctet <= 239) then Result.NetClass := 'D'
  else Result.NetClass := 'E';

  Result.IsPrivate := False;
  if (FirstOctet = 10) then Result.IsPrivate := True;
  if (FirstOctet = 172) and (Byte(Result.IP shr 16) >= 16) and (Byte(Result.IP shr 16) <= 31) then Result.IsPrivate := True;
  if (FirstOctet = 192) and (Byte(Result.IP shr 16) = 168) then Result.IsPrivate := True;

  // ТАКТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Логика для нестандартных масок /31 и /32 по мировым стандартам (RFC 3021)
  if CIDR = 32 then
  begin
    // Одиночный хост (Loopback / Point-to-Point Node)
    Result.HostMin := Result.IP;
    Result.HostMax := Result.IP;
    Result.HostsCount := 1;

    Result.NetworkStr := UInt32ToIPStr(Result.Network);
    Result.BroadcastStr := 'N/A (Single Host)'; // Исключаем дублирование строк
    Result.HostMinStr := UInt32ToIPStr(Result.HostMin);
    Result.HostMaxStr := UInt32ToIPStr(Result.HostMax);
  end
  else if CIDR = 31 then
  begin
    // Point-to-Point линки (RFC 3021) — Network и Broadcast используются как легальные хосты
    Result.HostMin := Result.Network;
    Result.HostMax := Result.Broadcast;
    Result.HostsCount := 2;

    Result.NetworkStr := 'N/A (PtP Link)';
    Result.BroadcastStr := 'N/A (PtP Link)';
    Result.HostMinStr := UInt32ToIPStr(Result.HostMin);
    Result.HostMaxStr := UInt32ToIPStr(Result.HostMax);
  end
  else
  begin
    // Классические сети (/0 ... /30) со стандартным выделением системных адресов
    Result.HostMin := Result.Network + 1;
    Result.HostMax := Result.Broadcast - 1;
    Result.HostsCount := Int64(Result.Broadcast) - Int64(Result.Network) - 1;
    if Result.HostsCount < 0 then Result.HostsCount := 0;

    Result.NetworkStr := UInt32ToIPStr(Result.Network);
    Result.BroadcastStr := UInt32ToIPStr(Result.Broadcast);
    Result.HostMinStr := UInt32ToIPStr(Result.HostMin);
    Result.HostMaxStr := UInt32ToIPStr(Result.HostMax);
  end;

  Result.MaskStr := UInt32ToIPStr(Result.Mask);
  Result.WildcardStr := UInt32ToIPStr(Result.Wildcard);
  Result.IsValid := True;
end;

end.


