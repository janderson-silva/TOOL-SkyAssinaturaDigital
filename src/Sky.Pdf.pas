unit Sky.Pdf;

interface

uses System.SysUtils, System.Classes, System.Generics.Collections, Sky.Crypto;

type
  TPdfPage = record
    ObjectID: Integer;
    Left, Bottom, Width, Height: Double;
  end;
  TPdfDocument = class
  private
    FData: AnsiString;
    FObjects: TDictionary<Integer, AnsiString>;
    FOffsets: TDictionary<Integer, Integer>;
    FPages: TList<TPdfPage>;
    FRoot, FSize, FXref: Integer;
    procedure WalkPages(ID, Depth: Integer; Box, Crop: AnsiString);
    function Resolve(const S: AnsiString): AnsiString;
    function ReadObject(Offset: Integer; out ID, Position: Integer): AnsiString;
    function ReadStream(const Dictionary: AnsiString; Position: Integer): AnsiString;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const FileName: string);
    function PageCount: Integer;
    function Page(Index: Integer): TPdfPage;
    procedure Sign(const OutputFile: string; PageIndex: Integer;
      X, Y, Width, Height: Double; Certificate: TWindowsCertificate);
  end;

implementation

uses System.IOUtils, System.RegularExpressions, System.Math, System.ZLib, Winapi.Windows;

// Token reader preserves nested PDF dictionaries, arrays and literal strings.
// Supports traditional xref and PDF 1.5 xref/object streams. Structural streams
// can be unfiltered or FlateDecode; other page content remains untouched.
procedure SkipSpace(const S: AnsiString; var P: Integer);
begin
  while P <= Length(S) do
  begin
    if S[P] = '%' then
      while (P <= Length(S)) and not CharInSet(Char(S[P]), [#10, #13]) do Inc(P)
    else if S[P] <= ' ' then Inc(P)
    else Break;
  end;
end;

function Token(const S: AnsiString; var P: Integer): AnsiString;
var Start, Depth: Integer; C: AnsiChar;
begin
  SkipSpace(S, P);
  Start := P;
  if P > Length(S) then Exit('');
  C := S[P];
  Inc(P);
  if C = '(' then
  begin
    Depth := 1;
    while (P <= Length(S)) and (Depth > 0) do
    begin
      if S[P] = '\' then Inc(P)
      else if S[P] = '(' then Inc(Depth)
      else if S[P] = ')' then Dec(Depth);
      Inc(P);
    end;
    if Depth <> 0 then raise Exception.Create('String PDF incompleta.');
  end
  else if (C = '<') and (P <= Length(S)) and (S[P] = '<') then Inc(P)
  else if (C = '>') and (P <= Length(S)) and (S[P] = '>') then Inc(P)
  else if C = '<' then
  begin
    while (P <= Length(S)) and (S[P] <> '>') do Inc(P);
    Inc(P);
  end
  else if not CharInSet(Char(C), ['[', ']','>']) then
    while (P <= Length(S)) and (S[P] > ' ') and
      not CharInSet(Char(S[P]), ['/', '<', '>', '[', ']', '(', ')', '%']) do Inc(P);
  Result := Copy(S, Start, P - Start);
end;

function Value(const S: AnsiString; var P: Integer): AnsiString;
var Start, Save, Depth: Integer; T, T2: AnsiString;
begin
  SkipSpace(S, P); Start := P;
  T := Token(S, P);
  if (T = '<<') or (T = '[') then
  begin
    Depth := 1;
    while Depth > 0 do
    begin
      T2 := Token(S, P);
      if T2 = '' then raise Exception.Create('Estrutura PDF incompleta.');
      if (T2 = '<<') or (T2 = '[') then Inc(Depth);
      if (T2 = '>>') or (T2 = ']') then Dec(Depth);
    end;
  end
  else if TRegEx.IsMatch(string(T), '^\d+$') then
  begin
    Save := P;
    T2 := Token(S, P);
    if not TRegEx.IsMatch(string(T2), '^\d+$') or (Token(S, P) <> 'R') then P := Save;
  end;
  Result := Copy(S, Start, P - Start);
end;

function Entry(const S, Key: AnsiString): AnsiString;
var P: Integer; K, V: AnsiString;
begin
  Result := ''; P := 1;
  if Token(S, P) <> '<<' then raise Exception.Create('Dicionario PDF esperado.');
  while P <= Length(S) do
  begin
    K := Token(S, P);
    if K = '>>' then Exit;
    if (K = '') or (K[1] <> '/') then raise Exception.Create('Chave PDF invalida.');
    V := Value(S, P);
    if K = Key then Exit(V);
  end;
end;

function RefID(const S: AnsiString): Integer;
var M: TMatch;
begin
  M := TRegEx.Match(string(S), '^\s*(\d+)\s+0\s+R\s*$');
  if not M.Success then raise Exception.Create('Referencia PDF nao suportada.');
  Result := StrToInt(M.Groups[1].Value);
end;

function SetEntry(const Dictionary, Key, NewValue: AnsiString): AnsiString;
var P: Integer; K, V: AnsiString;
begin
  P := 1;
  if Token(Dictionary, P) <> '<<' then raise Exception.Create('Dicionario PDF esperado.');
  Result := '<<';
  while True do
  begin
    K := Token(Dictionary, P);
    if K = '>>' then Break;
    if (K = '') or (K[1] <> '/') then raise Exception.Create('Dicionario PDF incompleto.');
    V := Value(Dictionary, P);
    if K <> Key then Result := Result + ' ' + K + ' ' + V;
  end;
  Result := Result + ' ' + Key + ' ' + NewValue + ' >>';
end;

function AppendArray(const Existing, Item: AnsiString): AnsiString;
var S: AnsiString;
begin
  S := Trim(Existing);
  if (S = '') or (S = 'null') then S := '[]';
  if (Length(S) < 2) or (S[1] <> '[') or (S[Length(S)] <> ']') then
    raise Exception.Create('Array de campos/anotacoes PDF invalido.');
  Result := Copy(S, 1, Length(S)-1) + ' ' + Item + ']';
end;

function Num(N: Double): AnsiString;
var FS: TFormatSettings;
begin
  FS := TFormatSettings.Create; FS.DecimalSeparator := '.';
  Result := AnsiString(FloatToStrF(N, ffFixed, 15, 3, FS));
end;

function PdfText(const S: string): AnsiString;
var C: Char;
begin
  Result := '';
  for C in S do
    if Ord(C) < 32 then Result := Result + ' '
    else if Ord(C) > 126 then Result := Result + '?'
    else
    begin
      if CharInSet(C, ['(', ')', '\']) then Result := Result + '\';
      Result := Result + AnsiChar(C);
    end;
end;

constructor TPdfDocument.Create;
begin
  inherited;
  FObjects := TDictionary<Integer, AnsiString>.Create;
  FOffsets := TDictionary<Integer, Integer>.Create;
  FPages := TList<TPdfPage>.Create;
end;

destructor TPdfDocument.Destroy;
begin
  FPages.Free; FObjects.Free; FOffsets.Free; inherited;
end;

function IntegerArray(const S: AnsiString): TArray<Integer>;
var P, N: Integer; T: AnsiString;
begin
  Result := nil; P := 1;
  if Token(S, P) <> '[' then raise Exception.Create('Array PDF esperado.');
  while True do
  begin
    T := Token(S, P);
    if T = ']' then Break;
    if T = '' then raise Exception.Create('Array PDF incompleto.');
    N := Length(Result); SetLength(Result, N+1);
    Result[N] := StrToInt(string(T));
    if N > 1000000 then raise Exception.Create('Array PDF muito grande.');
  end;
end;

function Parameter(const Dictionary, Key: AnsiString; Default: Integer): Integer;
var V: AnsiString;
begin
  V := Entry(Dictionary, Key);
  if V = '' then Result := Default else Result := StrToInt(string(V));
end;

function TPdfDocument.Resolve(const S: AnsiString): AnsiString;
var Depth: Integer;
begin
  Result := S; Depth := 0;
  while TRegEx.IsMatch(string(Result), '^\s*\d+\s+0\s+R\s*$') do
  begin
    Inc(Depth);
    if Depth > 50 then raise Exception.Create('Referencia PDF circular.');
    Result := FObjects[RefID(Result)];
  end;
end;

function UndoPredictor(const Input: AnsiString; const Params: AnsiString): AnsiString;
var Predictor, Columns, Colors, Bits, RowBytes, BytesPerPixel, Rows,
    Row, Col, Src, Dst, Filter, A, B, C, V, Estimate, PA, PB, PC: Integer;
begin
  Result := Input;
  if (Params = '') or (Params = 'null') then Exit;
  Predictor := Parameter(Params, '/Predictor', 1);
  if Predictor = 1 then Exit;
  Columns := Parameter(Params, '/Columns', 1);
  Colors := Parameter(Params, '/Colors', 1);
  Bits := Parameter(Params, '/BitsPerComponent', 8);
  if (Columns <= 0) or (Columns > 1000000) or (Colors < 1) or (Colors > 32) or (Bits <> 8) then
    raise Exception.Create('Parametros de predictor nao suportados.');
  RowBytes := Columns * Colors; BytesPerPixel := Colors;
  if Predictor = 2 then
  begin
    if Length(Input) mod RowBytes <> 0 then raise Exception.Create('Predictor TIFF incompleto.');
    Rows := Length(Input) div RowBytes;
    for Row := 0 to Rows-1 do
      for Col := BytesPerPixel to RowBytes-1 do
      begin
        Dst := Row*RowBytes+Col+1;
        Result[Dst] := AnsiChar((Ord(Result[Dst])+Ord(Result[Dst-BytesPerPixel])) and $FF);
      end;
    Exit;
  end;
  if (Predictor < 10) or (Predictor > 15) then
    raise Exception.Create('Predictor PDF nao suportado.');
  if Length(Input) mod (RowBytes+1) <> 0 then raise Exception.Create('Predictor PNG incompleto.');
  Rows := Length(Input) div (RowBytes+1); SetLength(Result, Rows*RowBytes);
  for Row := 0 to Rows-1 do
  begin
    Src := Row*(RowBytes+1)+1; Filter := Ord(Input[Src]);
    if Filter > 4 then raise Exception.Create('Filtro predictor PNG invalido.');
    for Col := 0 to RowBytes-1 do
    begin
      Dst := Row*RowBytes+Col+1; V := Ord(Input[Src+Col+1]);
      A := 0; B := 0; C := 0;
      if Col >= BytesPerPixel then A := Ord(Result[Dst-BytesPerPixel]);
      if Row > 0 then B := Ord(Result[Dst-RowBytes]);
      if (Row > 0) and (Col >= BytesPerPixel) then C := Ord(Result[Dst-RowBytes-BytesPerPixel]);
      case Filter of
        1: Inc(V, A);
        2: Inc(V, B);
        3: Inc(V, (A+B) div 2);
        4: begin
          Estimate := A+B-C; PA := Abs(Estimate-A); PB := Abs(Estimate-B); PC := Abs(Estimate-C);
          if (PA <= PB) and (PA <= PC) then Inc(V, A)
          else if PB <= PC then Inc(V, B) else Inc(V, C);
        end;
      end;
      Result[Dst] := AnsiChar(V and $FF);
    end;
  end;
end;

function TPdfDocument.ReadObject(Offset: Integer; out ID, Position: Integer): AnsiString;
begin
  if (Offset < 0) or (Offset >= Length(FData)) then raise Exception.Create('Offset PDF invalido.');
  Position := Offset+1;
  ID := StrToInt(string(Token(FData, Position)));
  if (Token(FData, Position) <> '0') or (Token(FData, Position) <> 'obj') then
    raise Exception.Create('Objeto PDF invalido ou geracao nao suportada.');
  Result := Value(FData, Position);
end;

function TPdfDocument.ReadStream(const Dictionary: AnsiString; Position: Integer): AnsiString;
var V, Filter, Params, Raw: AnsiString; N, ID, Q, RefOffset, P: Integer;
    Source, Dest: TMemoryStream; Inflate: TZDecompressionStream;
    Buffer: array[0..8191] of Byte; Count: Integer;
begin
  V := Entry(Dictionary, '/Length');
  if TRegEx.IsMatch(string(V), '^\s*\d+\s+0\s+R\s*$') then
  begin
    if not FOffsets.TryGetValue(RefID(V), RefOffset) then
      raise Exception.Create('Length indireto nao encontrado.');
    V := ReadObject(RefOffset, ID, Q);
  end;
  N := StrToInt(string(V));
  if (N < 0) or (N > 200*1024*1024) then raise Exception.Create('Stream PDF muito grande.');
  if Token(FData, Position) <> 'stream' then raise Exception.Create('Stream PDF esperado.');
  // The EOL after stream is syntax; whitespace inside the stream is data.
  if (Position <= Length(FData)) and (FData[Position] = #13) then Inc(Position);
  if (Position <= Length(FData)) and (FData[Position] = #10) then Inc(Position)
  else if (Position = 1) or (FData[Position-1] <> #13) then
    raise Exception.Create('Inicio de stream PDF invalido.');
  if N > Length(FData)-Position+1 then raise Exception.Create('Stream PDF truncado.');
  Raw := Copy(FData, Position, N); Q := Position+N;
  if Token(FData, Q) <> 'endstream' then raise Exception.Create('Fim de stream PDF invalido.');
  Filter := Trim(Entry(Dictionary, '/Filter')); Params := Trim(Entry(Dictionary, '/DecodeParms'));
  if Copy(Filter, 1, 1) = '[' then
  begin
    P := 1; Token(Filter, P); V := Token(Filter, P);
    if Token(Filter, P) <> ']' then raise Exception.Create('Multiplos filtros estruturais nao suportados.');
    Filter := V;
    if Copy(Params, 1, 1) = '[' then
    begin
      P := 1; Token(Params, P); V := Value(Params, P);
      if Token(Params, P) <> ']' then raise Exception.Create('DecodeParms invalido.');
      Params := V;
    end;
  end;
  if (Filter = '') or (Filter = 'null') then Exit(Raw);
  if (Filter <> '/FlateDecode') and (Filter <> '/Fl') then
    raise Exception.Create('Filtro estrutural nao suportado: ' + string(Filter));
  Source := TMemoryStream.Create; Dest := TMemoryStream.Create;
  try
    if N > 0 then Source.WriteBuffer(Raw[1], N);
    Source.Position := 0;
    Inflate := TZDecompressionStream.Create(Source);
    try
      repeat
        Count := Inflate.Read(Buffer, SizeOf(Buffer));
        if Dest.Size+Count > 200*1024*1024 then raise Exception.Create('Stream descompactado muito grande.');
        if Count > 0 then Dest.WriteBuffer(Buffer, Count);
      until Count = 0;
    finally Inflate.Free; end;
    SetString(Result, PAnsiChar(Dest.Memory), Integer(Dest.Size));
  finally Dest.Free; Source.Free; end;
  Result := UndoPredictor(Result, Params);
end;

procedure TPdfDocument.Load(const FileName: string);
var B: TBytes; M: TMatch; P, First, Count, I, Offset, Gen, Q, ID,
    StreamID, StreamPosition, Cursor, Kind, Field2, Field3, J, N, Header,
    ObjectPosition, ActualID, ObjectIndex, StreamFirst: Integer;
    T, State, Body, Trailer, Decoded, ObjectData, ObjectBody: AnsiString;
    W, Indexes, ObjectIDs, ObjectOffsets: TArray<Integer>;
    CompressedStreams, CompressedIndexes: TDictionary<Integer, Integer>;
    DecodedStreams: TDictionary<Integer, AnsiString>;
    Pair: TPair<Integer, Integer>;
  function ReadField(Width, Default: Integer): Integer;
  var K: Integer; V: Int64;
  begin
    if Width = 0 then Exit(Default);
    if (Width < 0) or (Width > 8) or (Cursor+Width-1 > Length(Decoded)) then
      raise Exception.Create('Campo xref stream invalido.');
    V := 0;
    for K := 1 to Width do
    begin
      V := V*256 + Ord(Decoded[Cursor]); Inc(Cursor);
      if V > MaxInt then raise Exception.Create('Campo xref excede o limite suportado.');
    end;
    Result := Integer(V);
  end;
  procedure CheckTrailer;
  begin
    if (Entry(Trailer, '/Encrypt') <> '') or (Entry(Trailer, '/Prev') <> '') or
       (Entry(Trailer, '/XRefStm') <> '') then
      raise Exception.Create('PDF criptografado, incremental ou hibrido nao suportado.');
    FSize := StrToInt(string(Entry(Trailer, '/Size')));
    if (FSize <= 0) or (FSize > 1000000) then raise Exception.Create('Size PDF invalido.');
  end;
begin
  FObjects.Clear; FPages.Clear; FOffsets.Clear;
  B := TFile.ReadAllBytes(FileName);
  if Length(B) > 200 * 1024 * 1024 then raise Exception.Create('Limite: 200 MB.');
  SetString(FData, PAnsiChar(Pointer(B)), Length(B));
  if Copy(FData, 1, 5) <> '%PDF-' then raise Exception.Create('Arquivo nao e PDF.');
  M := TRegEx.Match(string(FData), 'startxref\s+(\d+)\s+%%EOF\s*$');
  if not M.Success then raise Exception.Create('Final do PDF nao suportado.');
  FXref := StrToInt(M.Groups[1].Value); P := FXref + 1;
  CompressedStreams := TDictionary<Integer, Integer>.Create;
  CompressedIndexes := TDictionary<Integer, Integer>.Create;
  DecodedStreams := TDictionary<Integer, AnsiString>.Create;
  try
    if Token(FData, P) = 'xref' then
    begin
      while True do
      begin
        T := Token(FData, P);
        if T = 'trailer' then Break;
        First := StrToInt(string(T)); Count := StrToInt(string(Token(FData, P)));
        if (First < 0) or (Count < 0) or (Int64(First)+Count > 1000000) then
          raise Exception.Create('Tabela xref invalida.');
        for I := First to First+Count-1 do
        begin
          Offset := StrToInt(string(Token(FData, P)));
          Gen := StrToInt(string(Token(FData, P))); State := Token(FData, P);
          if State = 'f' then Continue;
          if (State <> 'n') or (Gen <> 0) then raise Exception.Create('Entrada xref nao suportada.');
          FOffsets.Add(I, Offset);
        end;
      end;
      Trailer := Value(FData, P); CheckTrailer;
    end
    else
    begin
      Trailer := ReadObject(FXref, StreamID, StreamPosition);
      if Entry(Trailer, '/Type') <> '/XRef' then raise Exception.Create('Xref stream esperado.');
      CheckTrailer;
      W := IntegerArray(Entry(Trailer, '/W'));
      if Length(W) <> 3 then raise Exception.Create('W de xref deve ter tres campos.');
      for I := 0 to 2 do
        if (W[I] < 0) or (W[I] > 8) then raise Exception.Create('Largura de campo xref invalida.');
      if W[0]+W[1]+W[2] = 0 then raise Exception.Create('Xref sem campos.');
      T := Entry(Trailer, '/Index');
      if T = '' then
      begin SetLength(Indexes, 2); Indexes[0] := 0; Indexes[1] := FSize; end
      else Indexes := IntegerArray(T);
      if Length(Indexes) mod 2 <> 0 then raise Exception.Create('Index de xref invalido.');
      Decoded := ReadStream(Trailer, StreamPosition); Cursor := 1;
      J := 0;
      while J < Length(Indexes) do
      begin
        First := Indexes[J]; Count := Indexes[J+1]; Inc(J, 2);
        if (First < 0) or (Count < 0) or (Int64(First)+Count > FSize) then
          raise Exception.Create('Faixa Index de xref invalida.');
        for I := First to First+Count-1 do
        begin
          Kind := ReadField(W[0], 1); Field2 := ReadField(W[1], 0); Field3 := ReadField(W[2], 0);
          case Kind of
            0: ; // free object
            1: begin
              if Field3 <> 0 then raise Exception.Create('Geracao de objeto nao suportada.');
              FOffsets.Add(I, Field2);
            end;
            2: begin
              CompressedStreams.Add(I, Field2); CompressedIndexes.Add(I, Field3);
            end;
          else raise Exception.Create('Tipo de entrada xref nao suportado.');
          end;
        end;
      end;
      if Cursor <> Length(Decoded)+1 then raise Exception.Create('Comprimento xref stream inconsistente.');
    end;
    for Pair in FOffsets do
    begin
      if Pair.Key >= FSize then raise Exception.Create('Objeto fora de Size.');
      Body := ReadObject(Pair.Value, ID, Q);
      if ID <> Pair.Key then raise Exception.Create('Objeto PDF inconsistente.');
      FObjects.Add(ID, Body);
    end;
    // Type 2 entries point to a stream object and an index in its header.
    for Pair in CompressedStreams do
    begin
      if not FOffsets.TryGetValue(Pair.Value, Offset) then
        raise Exception.Create('ObjStm nao encontrado na tabela xref.');
      Body := ReadObject(Offset, ActualID, Q);
      if Entry(Body, '/Type') <> '/ObjStm' then raise Exception.Create('ObjStm esperado.');
      N := Parameter(Body, '/N', -1); StreamFirst := Parameter(Body, '/First', -1);
      if (N < 0) or (N > 1000000) or (StreamFirst < 0) then
        raise Exception.Create('Cabecalho ObjStm invalido.');
      if not DecodedStreams.TryGetValue(Pair.Value, ObjectData) then
      begin
        ObjectData := ReadStream(Body, Q); DecodedStreams.Add(Pair.Value, ObjectData);
      end;
      if StreamFirst > Length(ObjectData) then raise Exception.Create('First ObjStm invalido.');
      SetLength(ObjectIDs, N); SetLength(ObjectOffsets, N); Header := 1;
      for I := 0 to N-1 do
      begin
        ObjectIDs[I] := StrToInt(string(Token(ObjectData, Header)));
        ObjectOffsets[I] := StrToInt(string(Token(ObjectData, Header)));
        if (ObjectOffsets[I] < 0) or (ObjectOffsets[I] >= Length(ObjectData)-StreamFirst) then
          raise Exception.Create('Offset ObjStm invalido.');
        if (I > 0) and (ObjectOffsets[I] <= ObjectOffsets[I-1]) then
          raise Exception.Create('Ordem ObjStm invalida.');
      end;
      SkipSpace(ObjectData, Header);
      if Header <> StreamFirst+1 then raise Exception.Create('Cabecalho ObjStm inconsistente.');
      ObjectIndex := CompressedIndexes[Pair.Key];
      if (ObjectIndex < 0) or (ObjectIndex >= N) then raise Exception.Create('Indice ObjStm invalido.');
      if ObjectIDs[ObjectIndex] <> Pair.Key then raise Exception.Create('Referencia ObjStm inconsistente.');
      ObjectPosition := StreamFirst+ObjectOffsets[ObjectIndex]+1;
      if ObjectIndex+1 < N then Count := ObjectOffsets[ObjectIndex+1]-ObjectOffsets[ObjectIndex]
      else Count := Length(ObjectData)-ObjectPosition+1;
      ObjectBody := Copy(ObjectData, ObjectPosition, Count); P := 1;
      Body := Value(ObjectBody, P); SkipSpace(ObjectBody, P);
      if P <= Length(ObjectBody) then raise Exception.Create('Objeto compactado invalido.');
      FObjects.Add(Pair.Key, Body);
    end;
  finally
    DecodedStreams.Free; CompressedIndexes.Free; CompressedStreams.Free;
  end;
  for ID in FObjects.Keys do
    if ID >= FSize then raise Exception.Create('Tamanho xref inconsistente.');
  FRoot := RefID(Entry(Trailer, '/Root'));
  Body := FObjects[FRoot];
  // An AcroForm is not a signing restriction. Permissions are evaluated at
  // signing time, so a document can still be opened and previewed.
  WalkPages(RefID(Entry(Body, '/Pages')), 0, '', '');
  if FPages.Count = 0 then raise Exception.Create('PDF sem paginas.');
end;

procedure TPdfDocument.WalkPages(ID, Depth: Integer; Box, Crop: AnsiString);
var Body, V, Kids: AnsiString; P: Integer; Pg: TPdfPage;
    Matches: TMatchCollection; FS: TFormatSettings;
    Media, Visible: array[0..3] of Double; I: Integer;
  procedure ReadBox(const S: AnsiString; var Numbers: array of Double);
  var K: Integer;
  begin
    V := Resolve(S);
    if Copy(Trim(string(V)), 1, 1) <> '[' then raise Exception.Create('Box PDF invalido.');
    Matches := TRegEx.Matches(string(V), '[-+]?\d*\.?\d+');
    if Matches.Count <> 4 then raise Exception.Create('Box PDF deve ter quatro coordenadas.');
    for K := 0 to 3 do Numbers[K] := StrToFloat(Matches[K].Value, FS);
  end;
begin
  if Depth > 50 then raise Exception.Create('Arvore de paginas muito profunda.');
  Body := FObjects[ID];
  V := Entry(Body, '/CropBox');
  if V <> '' then Crop := V;
  V := Entry(Body, '/Rotate');
  if (V <> '') and (Trim(string(V)) <> '0') then
    raise Exception.Create('Paginas rotacionadas nao suportadas nesta versao.');
  if Entry(Body, '/UserUnit') <> '' then raise Exception.Create('UserUnit nao suportado.');
  V := Entry(Body, '/MediaBox'); if V <> '' then Box := V;
  if Entry(Body, '/Type') = '/Pages' then
  begin
    Kids := Resolve(Entry(Body, '/Kids')); P := 1;
    if Token(Kids, P) <> '[' then raise Exception.Create('Kids deve ser um array.');
    while True do
    begin
      SkipSpace(Kids, P);
      if (P > Length(Kids)) then raise Exception.Create('Kids incompleto.');
      if Kids[P] = ']' then Break;
      WalkPages(RefID(Value(Kids, P)), Depth + 1, Box, Crop);
    end;
    Exit;
  end;
  if Entry(Body, '/Type') <> '/Page' then raise Exception.Create('Pagina invalida.');
  FS := TFormatSettings.Create; FS.DecimalSeparator := '.';
  ReadBox(Box, Media);
  if Crop = '' then
    for I := 0 to 3 do Visible[I] := Media[I]
  else ReadBox(Crop, Visible);
  Pg.ObjectID := ID;
  Pg.Left := Max(Media[0], Visible[0]); Pg.Bottom := Max(Media[1], Visible[1]);
  Pg.Width := Min(Media[2], Visible[2]) - Pg.Left;
  Pg.Height := Min(Media[3], Visible[3]) - Pg.Bottom;
  if (Pg.Width <= 0) or (Pg.Height <= 0) then raise Exception.Create('Dimensoes invalidas.');
  FPages.Add(Pg);
end;

function TPdfDocument.PageCount: Integer;
begin Result := FPages.Count; end;

function TPdfDocument.Page(Index: Integer): TPdfPage;
begin Result := FPages[Index]; end;

procedure TPdfDocument.Sign(const OutputFile: string; PageIndex: Integer;
  X, Y, Width, Height: Double; Certificate: TWindowsCertificate);
const Reserve = 32768;
var S, Body, Appearance, BR, Hex, FormDictionary, Fields, Annots,
    Permissions, ObjectBody, FieldName: AnsiString; Pg: TPdfPage;
    Offsets: TDictionary<Integer, Integer>; IDs: TList<Integer>;
    ID, SigID, WidgetID, FormID, ApID, FontID, StartContents, EndContents,
    BRPos, XrefPos, I: Integer; Data, CMS, Output: TBytes;
    Stamp: TDateTime; Handle: THandle; Stream: THandleStream;
    Flags: Integer; NameGUID: TGUID;
  procedure AddObject(N: Integer; const Content: AnsiString);
  begin
    Offsets.Add(N, Length(S)); IDs.Add(N);
    S := S + AnsiString(IntToStr(N)) + ' 0 obj'#10 + Content + #10'endobj'#10;
  end;
begin
  Pg := Page(PageIndex);
  if (X < 0) or (Y < 0) or (Width < 80) or (Height < 30) or
    (X + Width > Pg.Width) or (Y + Height > Pg.Height) then
    raise Exception.Create('Assinatura fora da pagina ou muito pequena.');
  if Certificate.Context = nil then raise Exception.Create('Selecione o certificado.');
  Permissions := Resolve(Entry(FObjects[FRoot], '/Perms'));
  if (Permissions <> '') and (Permissions <> 'null') then
  begin
    if Entry(Permissions, '/DocMDP') <> '' then
      raise Exception.Create('O PDF possui assinatura de certificacao DocMDP. As permissoes de alteracao ainda nao sao interpretadas por esta versao.');
    if (Entry(Permissions, '/UR') <> '') or (Entry(Permissions, '/UR3') <> '') then
      raise Exception.Create('O PDF possui direitos de uso UR/UR3 assinados. Esta versao nao altera esses direitos.');
    // Unknown permission entries are not silently discarded or bypassed.
    if Trim(string(Permissions)) <> '<<>>' then
    begin
      Body := Permissions; I := 1; Token(Body, I);
      if Token(Body, I) <> '>>' then
        raise Exception.Create('O PDF possui permissoes de assinatura ainda nao suportadas.');
    end;
  end;
  FormDictionary := Resolve(Entry(FObjects[FRoot], '/AcroForm'));
  if (FormDictionary = '') or (FormDictionary = 'null') then FormDictionary := '<< >>';
  if Entry(FormDictionary, '/XFA') <> '' then
    raise Exception.Create('Formulario XFA nao suportado para assinatura. Formularios AcroForm sao aceitos.');
  // Existing signatures/locks require policy handling beyond adding a field.
  // Refuse specifically at signing time instead of rejecting all forms on open.
  for ObjectBody in FObjects.Values do
    if Copy(Trim(ObjectBody), 1, 2) = '<<' then
    begin
      if (Entry(ObjectBody, '/Type') = '/Sig') and
         (Entry(ObjectBody, '/ByteRange') <> '') then
        raise Exception.Create('O PDF ja possui assinatura digital. A inclusao de outra assinatura ainda nao e suportada.');
      if Entry(ObjectBody, '/Lock') <> '' then
        raise Exception.Create('O PDF possui bloqueio de campos /Lock. Esta versao nao interpreta esse bloqueio.');
    end;
  Fields := Resolve(Entry(FormDictionary, '/Fields'));
  Annots := Resolve(Entry(FObjects[Pg.ObjectID], '/Annots'));
  Body := Resolve(Entry(FormDictionary, '/SigFlags'));
  Flags := 0;
  if (Body <> '') and (Body <> 'null') then Flags := StrToInt(string(Body));
  CreateGUID(NameGUID);
  FieldName := 'SkySignature_' + AnsiString(StringReplace(StringReplace(
    GUIDToString(NameGUID), '{', '', []), '}', '', []));
  Stamp := Now;
  SigID := FSize; WidgetID := FSize+1; FormID := FSize+2;
  ApID := FSize+3; FontID := FSize+4;
  Offsets := TDictionary<Integer, Integer>.Create; IDs := TList<Integer>.Create;
  try
    S := FData + #10;
    AddObject(FRoot, SetEntry(FObjects[FRoot], '/AcroForm', AnsiString(IntToStr(FormID)) + ' 0 R'));
    AddObject(Pg.ObjectID, SetEntry(FObjects[Pg.ObjectID], '/Annots',
      AppendArray(Annots, AnsiString(IntToStr(WidgetID)) + ' 0 R')));
    FormDictionary := SetEntry(FormDictionary, '/Fields',
      AppendArray(Fields, AnsiString(IntToStr(WidgetID)) + ' 0 R'));
    FormDictionary := SetEntry(FormDictionary, '/SigFlags', AnsiString(IntToStr(Flags or 3)));
    AddObject(FormID, FormDictionary);
    AddObject(FontID, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>');
    Appearance := 'q 0.96 g 0 0 ' + Num(Width) + ' ' + Num(Height) + ' re f 0.2 G 0.5 w 0 0 ' +
      Num(Width) + ' ' + Num(Height) + ' re S 0 g BT /F1 9 Tf 6 ' + Num(Height-14) +
      ' Td (Assinado digitalmente) Tj 0 -13 Td (' + PdfText(Copy(Certificate.Name, 1, 32)) +
      ') Tj 0 -13 Td (' + PdfText(FormatDateTime('dd/mm/yyyy hh:nn:ss', Stamp)) + ') Tj ET Q';
    AddObject(ApID, '<< /Type /XObject /Subtype /Form /BBox [0 0 ' + Num(Width) + ' ' +
      Num(Height) + '] /Resources << /Font << /F1 ' + AnsiString(IntToStr(FontID)) +
      ' 0 R >> >> /Length ' + AnsiString(IntToStr(Length(Appearance))) + ' >>'#10'stream'#10 +
      Appearance + #10'endstream');
    AddObject(WidgetID, '<< /Type /Annot /Subtype /Widget /FT /Sig /T (' + FieldName + ') /F 4 /P ' +
      AnsiString(IntToStr(Pg.ObjectID)) + ' 0 R /Rect [' + Num(Pg.Left+X) + ' ' + Num(Pg.Bottom+Y) +
      ' ' + Num(Pg.Left+X+Width) + ' ' + Num(Pg.Bottom+Y+Height) + '] /V ' +
      AnsiString(IntToStr(SigID)) + ' 0 R /AP << /N ' + AnsiString(IntToStr(ApID)) + ' 0 R >> >>');
    Body := '<< /Type /Sig /Filter /Adobe.PPKLite /SubFilter /adbe.pkcs7.detached /Name (' +
      PdfText(Certificate.Name) + ') /M (D:' + AnsiString(FormatDateTime('yyyymmddhhnnss', Stamp)) +
      ') /ByteRange [000000000000 000000000000 000000000000 000000000000] /Contents <' +
      AnsiString(StringOfChar('0', Reserve*2)) + '> >>';
    AddObject(SigID, Body);
    // Locate placeholders within the new signature object only.
    I := Offsets[SigID] + 1;
    BRPos := I + Pos('/ByteRange [', Copy(S, I, MaxInt)) - 1 + Length('/ByteRange ');
    StartContents := I + Pos('/Contents <', Copy(S, I, MaxInt)) - 1 + Length('/Contents ');
    EndContents := StartContents + Reserve*2 + 2; // one-based position after >
    XrefPos := Length(S); S := S + 'xref'#10;
    IDs.Sort;
    for ID in IDs do
      S := S + AnsiString(IntToStr(ID)) + ' 1'#10 +
        AnsiString(Format('%.10d 00000 n ', [Offsets[ID]])) + #10;
    S := S + 'trailer'#10'<< /Size ' + AnsiString(IntToStr(FSize+5)) + ' /Root ' +
      AnsiString(IntToStr(FRoot)) + ' 0 R /Prev ' + AnsiString(IntToStr(FXref)) +
      ' >>'#10'startxref'#10 + AnsiString(IntToStr(XrefPos)) + #10'%%EOF'#10;
    BR := AnsiString(Format('[%.12d %.12d %.12d %.12d]',
      [0, StartContents-1, EndContents-1, Length(S)-EndContents+1]));
    Move(BR[1], S[BRPos], Length(BR));
    SetLength(Data, StartContents-1 + Length(S)-EndContents+1);
    Move(S[1], Data[0], StartContents-1);
    Move(S[EndContents], Data[StartContents-1], Length(S)-EndContents+1);
    CMS := Certificate.SignDetached(Data);
    if Length(CMS) > Reserve then raise Exception.Create('Assinatura maior que o espaco reservado.');
    Hex := '';
    for I := 0 to High(CMS) do Hex := Hex + AnsiString(IntToHex(CMS[I], 2));
    Move(Hex[1], S[StartContents+1], Length(Hex));
    SetLength(Output, Length(S)); Move(S[1], Output[0], Length(S));
    Handle := CreateFile(PChar(OutputFile), GENERIC_WRITE, 0, nil, CREATE_NEW,
      FILE_ATTRIBUTE_NORMAL, 0);
    if Handle = INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Stream := THandleStream.Create(Handle);
      try Stream.WriteBuffer(Output[0], Length(Output)); finally Stream.Free; end;
    finally CloseHandle(Handle); end;
  finally
    IDs.Free; Offsets.Free;
  end;
end;

end.
