unit Database.SQL;

interface

uses
  System.Classes,
  System.Generics.Collections,
  System.Types,
  System.SysUtils,
  System.StrUtils,
  System.Variants,
  System.Json,

  FireDAC.Stan.Intf, FireDAC.Comp.UI,
  FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.Phys.Intf,
  FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys,
  FireDAC.ConsoleUI.Wait, FireDAC.Stan.Param, FireDAC.DatS,
  FireDAC.DApt.Intf, FireDAC.DApt, FireDAC.Comp.Client,
  FireDAC.Comp.DataSet, FireDAC.UI.Intf, FireDAC.Phys.ODBCBase,

  Data.DB,

  Database.Interfaces,
  Database.Tipos,
  Database.ParamList;

type
  TDatabaseSQL = class(TInterfacedObject, IDataBaseSQL,
    IDatabaseSQLParamList)
  private
    FConnection: TConnection;
    FConnectionAux : TConnection;
    FQuery: TQuery;
    FParamList: TDatabaseParamList;

    function QueryOpen: TDataSet;
    procedure ExecuteSQL;
    procedure SQLText(pSQL: string);
    procedure ValidaSQL(pSQL: string);
    function PreencherDataSet(PQuery: TQuery): TMemTable;
    function ConvertToParam(aColum: String): String;
    procedure AddNull(pTipo: TFieldType; pNome: string; pValor: variant);
    function VarVoidToNull(pValor: Variant): Variant;

  public
    constructor Create;
    destructor Destroy; override;
    class function New: IDataBaseSQL;

    { IDataBaseSQL }
    function SQL(pSQL: string): IDataBaseSQL;
    function ParamList: IDatabaseSQLParamList;
    function Open: TDataSet; overload;
    function Open(pSQL: string): TDataSet; overload;
    function ExecSQL: IDataBaseSQL; overload;
    function ExecSQL(pSQL: string): IDataBaseSQL; overload;
    function CriaQuery: TQuery;
    function GetConexao: TConnection;
    function QueryGetValueFirstField(pSQLText: String): variant;
    function GeraProximoCodigo(pFieldName, pTable: String; const pWhere: string = '';
      const pIncrement: Integer = 1): Integer; overload;
    function GeraProximoCodigo(PGenerator: string): Integer; overload;
    procedure StartTransaction;
    procedure Commit;
    procedure Rollback;

    { IDataBaseSQLParamList }
    function AddString(pNome: string; pValor: string): IDataBaseSQLParamList; overload;
    function AddString(pNome: string; pValor: variant): IDataBaseSQLParamList; overload;
    function AddInteger(pNome: string; pValor: Integer): IDataBaseSQLParamList; overload;
    function AddInteger(pNome: string; pValor: variant): IDataBaseSQLParamList; overload;
    function AddFloat(pNome: string; pValor: Double): IDataBaseSQLParamList; overload;
    function AddFloat(pNome: string; pValor: Currency): IDataBaseSQLParamList; overload;
    function AddFloat(pNome: string; pValor: variant): IDataBaseSQLParamList; overload;
    function AddDateTime(pNome: string; pValor: tdatetime): IDataBaseSQLParamList; overload;
    function AddDateTime(pNome: string; pValor: variant): IDataBaseSQLParamList; overload;

    function &End: IDataBaseSQL;
  end;


implementation

uses
  Database.Factory;

{ TDatabaseSQL }

function TDatabaseSQL.AddDateTime(pNome: string;
  pValor: tdatetime): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  FQuery.ParamByName(pNome).AsDateTime := pValor;
end;

function TDatabaseSQL.AddDateTime(pNome: string;
  pValor: variant): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  pValor := VarVoidToNull(pValor);

  if not(pValor = null)
  then AddDateTime(pNome, StrToDateTime(pValor))
  else AddNull(ftDateTime, pNome, pValor);
end;

function TDatabaseSQL.AddFloat(pNome: string;
  pValor: variant): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  if pValor > 0 then
    AddFloat(pNome, Double(pValor))
  else
    AddNull(ftFloat, pNome, pValor);
end;

function TDatabaseSQL.AddFloat(pNome: string;
  pValor: Double): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  FQuery.ParamByName(pNome).AsFloat := pValor;
end;

function TDatabaseSQL.AddFloat(pNome: string;
  pValor: Currency): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  FQuery.ParamByName(pNome).AsCurrency := pValor;
end;

function TDatabaseSQL.AddInteger(pNome: string;
  pValor: Integer): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  FQuery.ParamByName(pNome).AsInteger := pValor;
end;

function TDatabaseSQL.AddInteger(pNome: string;
  pValor: variant): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  pValor := VarVoidToNull(pValor);

  if not(pValor = null) then
    AddFloat(pNome, Trunc(pValor))
  else
    AddNull(ftInteger, pNome, pValor);
end;

procedure TDatabaseSQL.AddNull(pTipo: TFieldType; pNome: string;
  pValor: variant);
begin
  if not VarIsNull(pValor) then
    raise EDatabaseException.New
            .Error('O par�metro ('+pNome+') deve ser, obrigatoriamento, do tipo Nulo ou '+ FieldTypeNames[pTipo])
            .&Unit(Self.UnitName);
  FQuery.ParamByName(pNome).DataType := pTipo;
  FQuery.ParamByName(pNome).Value := Null;
end;

function TDatabaseSQL.AddString(pNome, pValor: string): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;

  FQuery.ParamByName(pNome).DataType := ftString;
  FQuery.ParamByName(pNome).AsString := pValor;
end;

function TDatabaseSQL.AddString(pNome: string;
  pValor: variant): IDataBaseSQLParamList;
begin
  Result := Self;
  if FQuery.FindParam(pNome) = nil then Exit;
  pValor := VarVoidToNull(pValor);

  if not(pValor = null)  then
    AddString(pNome, String(pValor))
  else
    AddNull(ftString, pNome, pValor);
end;

procedure TDatabaseSQL.Commit;
begin
  FConnection.Commit;
end;

function TDatabaseSQL.ConvertToParam(aColum: String): String;

  function ReplaceNonAscii(const s: String) : String;
    var i, pos: Integer;
    const undesiredchars : String = '\/������������������������������������������������������������';
    const replaces : String = '   AAAAAAACEEEEIIIIDNOOOOOxOUUUbBaaaaaaaceeeeiiiionooooo ouuuby';
  Begin
    SetLength(Result, Length(s));
    for i := 1 to Length(s) do
      begin
        pos := ord(s[i]);
        if (s[i] in [#32, #48..#57, #65..#90, #97..#122]) then
          Result[i] := s[i]
        else
          begin
            pos := AnsiPos(s[i], undesiredchars);
            Result[i] := replaces[pos + 1];
          end;
      end;
  end;

var param: string;
begin
  param  := aColum;
  param  := StringReplace(param,' ','',[rfReplaceAll]);
  param  := ReplaceNonAscii(param);
  param  := StringReplace(param,' ','_',[rfReplaceAll]);
  param  := LowerCase(param);
  Result := Trim(param);
end;

function TDatabaseSQL.&End: IDataBaseSQL;
begin
  Result := Self;
end;

constructor TDatabaseSQL.Create;
begin
  FConnection    := TDataBaseFactory.New.Conexao.GetConnection;
  FConnectionAux := TDataBaseFactory.New.Conexao.GetConnection;
  FQuery         := Self.CriaQuery;
  FParamList     := TDatabaseParamList.Create(FQuery.Params);
end;

function TDatabaseSQL.CriaQuery: TQuery;
begin
  Result := TQuery.Create(nil);
  Result.Connection := FConnection;
end;

destructor TDatabaseSQL.Destroy;
begin
  FQuery.Free;
  FConnection.Free;
  FConnectionAux.Free;
  FParamList.Free;
  inherited;
end;

function TDatabaseSQL.ExecSQL: IDataBaseSQL;
begin
  Result := Self;
  ExecuteSQL();
end;

function TDatabaseSQL.ExecSQL(pSQL: string): IDataBaseSQL;
begin
  Result := Self;
  SQLText(IfThen(pSQL <> '', pSQL, ''));
  ExecuteSQL();
end;

procedure TDatabaseSQL.ExecuteSQL;
begin
  try
    FQuery.ExecSQL;
  except
    on E: Exception do
    begin
      raise EDatabaseException.New.Error(E.Message).&Unit(Self.UnitName);
    end;
  end;
end;

function TDatabaseSQL.GeraProximoCodigo(pFieldName, pTable: String;
  const pWhere: string; const pIncrement: Integer): Integer;
var sSQL: String; sWhere: String;
begin
  sWhere := pWhere;
  // verifica se tem o texto 'where' em pWhere
  if (Trim(sWhere) <> '') and (pos('where', LowerCase(sWhere)) = 0) then
    sWhere := 'Where ' + pWhere;
  sSQL := 'select isnull(max(' + pFieldName + '),0)' + ' from ' + pTable + ' ' + sWhere;
  result := QueryGetValueFirstField(sSQL) + pIncrement;
end;

function TDatabaseSQL.GeraProximoCodigo(PGenerator: string): Integer;
begin
  var LSQL := 'SELECT GEN_ID('+PGenerator+', 1) AS VLR FROM RDB$DATABASE';
  Result := QueryGetValueFirstField(LSQL);
end;

function TDatabaseSQL.GetConexao: TConnection;
begin
  Result := FConnection;
end;

class function TDatabaseSQL.New: IDataBaseSQL;
begin
  Result := Self.Create;
end;

function TDatabaseSQL.Open(pSQL: string): TDataSet;
begin
  SQLText(IfThen(pSQL <> '', pSQL, ''));
  Result := QueryOpen();
end;

function TDatabaseSQL.Open: TDataSet;
begin
  Result := QueryOpen();
end;

function TDatabaseSQL.ParamList: IDatabaseSQLParamList;
begin
  Result := Self;
end;

function TDatabaseSQL.PreencherDataSet(PQuery: TQuery): TMemTable;
var
   memTable: TMemTable;
begin
  memTable := TMemTable.Create(nil);
  memTable.Data := PQuery.Data;

  memTable.First;
  while not memTable.Eof do
  begin
    memTable.Edit;
    memTable.FieldByName('dsc_camp').AsString := ConvertToParam(memTable.FieldByName('dsc_camp').AsString);
    memTable.Post;

    memTable.Next;
  end;
  Result := memTable;
end;

function TDatabaseSQL.QueryGetValueFirstField(pSQLText: String): variant;
begin
  try
    FQuery.SQL.Clear;
    FQuery.SQL.Text := pSQLText;
    FQuery.Active := True;
    Result := FQuery.Fields[0].Value;
  except
    on E: Exception do
    begin
      raise EDatabaseException.New
        .Error(E.Message)
        .&Unit(Self.UnitName)
    end;
  end;
end;

function TDatabaseSQL.QueryOpen: TDataSet;
begin
  try
    FQuery.Active := True;
    Result := FQuery;
  except
    on E: Exception do
    begin
      raise EDatabaseException.New
        .Error(E.Message)
        .&Unit(Self.UnitName);
    end;
  end;
end;

procedure TDatabaseSQL.Rollback;
begin
  FConnection.Rollback;
end;

function TDatabaseSQL.SQL(pSQL: string): IDataBaseSQL;
begin
  Result := Self;
  SQLText(pSQL);
end;

procedure TDatabaseSQL.SQLText(pSQL: string);
begin
  ValidaSQL(pSQL);
  FQuery.Params.Clear;
  FQuery.SQL.Clear;
  FQuery.SQL.Text := pSQL;
end;

procedure TDatabaseSQL.StartTransaction;
begin
  FConnection.StartTransaction;
end;

procedure TDatabaseSQL.ValidaSQL(pSQL: string);
begin
  if Trim(pSQL) = '' then
  begin
    raise EDatabaseException.New
      .Error('Script SQL n�o informado!')
      .&Unit(Self.UnitName);
  end;
end;

function TDatabaseSQL.VarVoidToNull(pValor: Variant): Variant;
var i: integer;
begin
  i := VarType(pValor);

  case VarType(pValor) of
    varString, varUString:
      if pValor = ''
      then Result := null
      else Result := pValor;

   varDate, varInteger:
     if pValor = 0
     then Result := null
     else Result := pValor;

  else
    Result := pValor;
  end;
end;

end.
