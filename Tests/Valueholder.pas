unit Valueholder;

interface

uses
  System.SysUtils, System.SyncObjs
;

type
  IHolder<TResult> = interface
    function GetValue: TResult;
    procedure SetValue(const value: TResult);
    function GetReason: Exception;
    procedure SetReason(const value: Exception);
    function GetSuccessCount: integer;
    function GetFailureCount: integer;
    function GetAlwaysCount: integer;
    procedure Success;
    procedure Failed;
    procedure Increment;

    property Value: TResult read GetValue write SetValue;
    property Reason: Exception read GetReason write SetReason;
    property SuccessCount: integer read GetSuccessCount;
    property FailureCount: integer read GetFailureCount;
    property AlwaysCount: integer read GetAlwaysCount;
  end;

  TValueHolder<TResult> = class (TInterfacedObject, IHolder<TResult>)
  private var
    FValue: TResult;
    FReason: Exception;
    FSuccessCount: integer;
    FFailureCount: integer;
    FAlwaysCount: integer;
  private
    function GetValue: TResult;
    procedure SetValue(const value: TResult);
    function GetReason: Exception;
    procedure SetReason(const value: Exception);
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

function TValueHolder<TResult>.GetReason: Exception;
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

procedure TValueHolder<TResult>.SetReason(const value: Exception);
begin
  FReason := value;
end;

procedure TValueHolder<TResult>.SetValue(const value: TResult);
begin
  FValue := value;
end;

end.
