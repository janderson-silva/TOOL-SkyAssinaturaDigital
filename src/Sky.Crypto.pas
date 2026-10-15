unit Sky.Crypto;

interface

uses Winapi.Windows, System.SysUtils;

type
  TWindowsCertificate = class
  private
    FContext: Pointer;
    FName: string;
  public
    destructor Destroy; override;
    procedure Select(AOwner: HWND);
    function SignDetached(const Data: TBytes): TBytes;
    property Name: string read FName;
    property Context: Pointer read FContext;
  end;

implementation

{$ALIGN 8}
type
  TBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
  TAlgorithm = record
    pszObjId: PAnsiChar;
    Parameters: TBlob;
  end;
  TSignParameters = record
    cbSize, dwMsgEncodingType: DWORD;
    pSigningCert: Pointer;
    HashAlgorithm: TAlgorithm;
    pvHashAuxInfo: Pointer;
    cMsgCert: DWORD;
    rgpMsgCert: Pointer;
    cMsgCrl: DWORD;
    rgpMsgCrl: Pointer;
    cAuthAttr: DWORD;
    rgAuthAttr: Pointer;
    cUnauthAttr: DWORD;
    rgUnauthAttr: Pointer;
    dwFlags, dwInnerContentType: DWORD;
    HashEncryptionAlgorithm: TAlgorithm;
    pvHashEncryptionAuxInfo: Pointer;
  end;

function CertOpenSystemStoreW(Provider: NativeUInt; Name: PWideChar): Pointer; stdcall;
  external 'crypt32.dll';
function CertCloseStore(Store: Pointer; Flags: DWORD): BOOL; stdcall; external 'crypt32.dll';
function CertFreeCertificateContext(Context: Pointer): BOOL; stdcall; external 'crypt32.dll';
function CertGetNameStringW(Context: Pointer; Kind, Flags: DWORD;
  Parameter: Pointer; Buffer: PWideChar; Count: DWORD): DWORD; stdcall; external 'crypt32.dll';
function CryptUIDlgSelectCertificateFromStore(Store: Pointer; Owner: HWND;
  Title, Description: PWideChar; Flags, Reserved: DWORD; Data: Pointer): Pointer; stdcall;
  external 'cryptui.dll';
function CryptSignMessage(Parameters: Pointer; Detached: BOOL; Count: DWORD;
  Buffers, Sizes: Pointer; Output: PByte; var OutputSize: DWORD): BOOL; stdcall;
  external 'crypt32.dll';

destructor TWindowsCertificate.Destroy;
begin
  if FContext <> nil then CertFreeCertificateContext(FContext);
  inherited;
end;

procedure TWindowsCertificate.Select(AOwner: HWND);
var Store, Selected: Pointer; Count: DWORD;
begin
  Store := CertOpenSystemStoreW(0, 'MY');
  if Store = nil then RaiseLastOSError;
  try
    Selected := CryptUIDlgSelectCertificateFromStore(Store, AOwner,
      'Certificado para assinatura', 'Selecione um certificado com chave privada.', 0, 0, nil);
    if Selected = nil then Exit;
    if FContext <> nil then CertFreeCertificateContext(FContext);
    FContext := Selected;
    Count := CertGetNameStringW(FContext, 4, 0, nil, nil, 0);
    SetLength(FName, Count);
    if Count > 0 then
    begin
      CertGetNameStringW(FContext, 4, 0, nil, PWideChar(FName), Count);
      SetLength(FName, Count - 1);
    end;
  finally
    CertCloseStore(Store, 0);
  end;
end;

function TWindowsCertificate.SignDetached(const Data: TBytes): TBytes;
var Params: TSignParameters; Buffer: PByte; Size, OutputSize: DWORD;
    Cert: Pointer; OID: AnsiString;
begin
  if FContext = nil then raise Exception.Create('Selecione o certificado.');
  if Length(Data) = 0 then raise Exception.Create('Documento vazio.');
  FillChar(Params, SizeOf(Params), 0);
  OID := '2.16.840.1.101.3.4.2.1'; // SHA-256
  Cert := FContext;
  Params.cbSize := SizeOf(Params);
  Params.dwMsgEncodingType := $00010001;
  Params.pSigningCert := Cert;
  Params.HashAlgorithm.pszObjId := PAnsiChar(OID);
  Params.cMsgCert := 1;
  Params.rgpMsgCert := @Cert;
  Buffer := @Data[0];
  Size := Length(Data);
  OutputSize := 0;
  if not CryptSignMessage(@Params, True, 1, @Buffer, @Size, nil, OutputSize) then
    RaiseLastOSError;
  SetLength(Result, OutputSize);
  if not CryptSignMessage(@Params, True, 1, @Buffer, @Size, @Result[0], OutputSize) then
    RaiseLastOSError;
  SetLength(Result, OutputSize);
end;

end.
