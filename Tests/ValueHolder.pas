unit ValueHolder;

interface

uses
  System.SysUtils, System.SyncObjs, Promise.Types
;

type
  IHolder<TResult> = interface
    function GetValue: TResult;
    procedure SetValue(const value: TResult);
    function GetReason: IFailureReason<Exception>;
    procedure SetReason(const value: IFailureReason<Exception>);
    function GetSuccessCount: integer;
    function GetFailureCount: integer;
    function GetAlwaysCount: integer;
    procedure Success;
    procedure Failed;
    procedure Increment;

    property Value: TResult read GetValue write SetValue;
    property Error: IFailureReason<Exception> read GetReason write SetReason;
    property SuccessCount: integer read GetSuccessCount;
    property FailureCount: integer read GetFailureCount;
    property AlwaysCount: integer read GetAlwaysCount;
  end;

  TValueHolder<TResult> = class (TInterfacedObject, IHolder<TResult>)
  private var
    FValue: TResult;
    FReason: IFailureReason<Exception>;
    FSuccessCount: integer;
    FFailureCount: integer;
    FAlwaysCount: integer;
  private
    function GetValue: TResult;
    procedure SetValue(const value: TResult);
    function GetReason: IFailureReason<Exception>;
    procedure SetReason(const value: IFailureReason<Exception>);
    function GetSuccessCount: integer;
    function GetFailureCount: integer;
    function GetAlwaysCount: integer;
  protected
    procedure Success;
    procedure Failed;
    procedure Increment;
  end;

implementation

{ TValueHolder<TResult> }

procedure TValueHolder<TResult>.Failed;
begin
  TInterlocked.Increment(FFailureCount);
end;

function TValueHolder<TResult>.GetAlwaysCount: integer;
begin
  Exit(FAlwaysCount);
end;

function TValueHolder<TResult>.GetFailureCount: integer;
begin
  Exit(FFailureCount);
end;

function TValueHolder<TResult>.GetReason: IFailureReason<Exception>;
begin
  Exit(FReason);
end;

function TValueHolder<TResult>.GetSuccessCount: integer;
begin
  Exit(FSuccessCount);
end;

function TValueHolder<TResult>.GetValue: TResult;
begin
  Exit(FValue);
end;

procedure TValueHolder<TResult>.Increment;
begin
  TInterlocked.Increment(FAlwaysCount);
end;

procedure TValueHolder<TResult>.Success;
begin
  TInterlocked.Increment(FSuccessCount);
end;

procedure TValueHolder<TResult>.SetReason(const value: IFailureReason<Exception>);
begin
  FReason := value;
end;

procedure TValueHolder<TResult>.SetValue(const value: TResult);
begin
  FValue := value;
end;

end.
