unit PromiseTest;

interface
uses
  System.SysUtils, System.Classes, System.SyncObjs,
  DUnitX.TestFramework;

type
  IReason<TFailure: Exception> = interface
    function GetError: TFailure;
    property Error: TFailure read GetError;
  end;

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

  TExceptionCalss = class of Exception;

  [TestFixture]
  TMyTestObject = class(TObject)
  private
    function SuccessCall<TResult>(value: TResult; const waitMiliSecs: integer): TFunc<TResult>;
    function FailedCall(const msg: string;
      const waitMiliSecs: integer; const cls: TExceptionCalss = nil): TFunc<integer>;
  public
    [Test] procedure test_success_wait;
    [Test] procedure test_failure_wait;
    [Test] procedure test_success_no_wait;
    [Test] procedure test_failure_no_wait;
    [Test] procedure test_always_done;
    [Test] procedure test_always_failure;
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

uses

  Promise.Proto
;

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

{ TMyTestObject }

function TMyTestObject.SuccessCall<TResult>(value: TResult;
  const waitMiliSecs: integer): TFunc<TResult>;
begin
  Result :=
    function: TResult
    begin
      TThread.Sleep(waitMiliSecs);

      Result := value;
    end;
end;

function TMyTestObject.FailedCall(const msg: string;
  const waitMiliSecs: integer; const cls: TExceptionCalss): TFunc<integer>;
begin
  Result :=
    function: integer
    begin
      TThread.Sleep(waitMiliSecs);

      if Assigned(cls) then begin
        raise cls.Create(msg);
      end
      else begin
        raise Exception.Create(msg);
      end;
    end;
end;

procedure TMyTestObject.test_success_wait;
var
  p: IPromise<integer,Exception,TNoProgress>;
  holder: IHolder<integer>;
  count: integer;
begin
  holder := TValueHolder<integer>.Create;
  count := 0;

  p :=
    TPromise.When<integer>(Self.SuccessCall<integer>(123, 10))
    .Done(
      procedure (value: integer)
      begin
        holder.Value := value;
      end
    )
    .Fail(
       procedure (ex: IFailureReason<Exception>)
       begin
         TInterlocked.Increment(count);
       end
    );

  p.Future.Value;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(123, holder.Value);
  Assert.AreEqual(0, count);
end;

procedure DoTestNoWait(const signal: TEvent; const fn: TFunc<integer>; const holder: IHolder<integer>);
var
  p: IPromise<integer,Exception,TNoProgress>;
begin
  p :=
    TPromise.When<integer>(fn)
    .Done(
      procedure (value: integer)
      begin
        holder.Value := value;
        holder.Success;
        signal.SetEvent;
      end
    )
    .Fail(
      procedure (ex: IFailureReason<Exception>)
      begin
        holder.Failed;
        signal.SetEvent;
      end
    );
end;

procedure TMyTestObject.test_success_no_wait;
var
  holder: IHolder<integer>;
  signal: TEvent;
begin
  holder := TValueHolder<integer>.Create;

  signal := TEvent.Create;
  try
    DoTestNoWait(signal, Self.SuccessCall<integer>(123, 10), holder);

    signal.WaitFor;
  finally
    signal.Free;
  end;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(123, holder.Value);
  Assert.AreEqual(1, holder.SuccessCount);
  Assert.AreEqual(0, holder.FailureCount);
end;

procedure TMyTestObject.test_failure_wait;
var
  p: IPromise<integer,Exception,TNoProgress>;
  doneCount, failedCount: integer;
begin
  doneCount := 0;
  failedCount := 0;

  p :=
    TPromise.When<integer>(Self.FailedCall('Oops', 10))
    .Done(
      procedure (value: integer)
      begin
         TInterlocked.Increment(doneCount);
      end
    )
    .Fail(
       procedure (ex: IFailureReason<Exception>)
       begin
         TInterlocked.Increment(failedCount);
       end
    );

  p.Future.WaitFor;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(0, doneCount);
  Assert.AreEqual(1, failedCount);
end;

procedure TMyTestObject.test_failure_no_wait;
var
  holder: IHolder<integer>;
  signal: TEvent;
begin
  holder := TValueHolder<integer>.Create;

  signal := TEvent.Create;
  try
    DoTestNoWait(signal, Self.FailedCall('Oops', 10), holder);

    signal.WaitFor;
  finally
    signal.Free;
  end;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(0, holder.SuccessCount);
  Assert.AreEqual(1, holder.FailureCount);
end;

procedure TMyTestObject.test_always_done;
var
  p: IPromise<integer,Exception,TNoProgress>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.When<integer>(Self.SuccessCall<integer>(1024, 10))
    .Done(
      procedure (value: integer)
      begin
         holder.Value := value;
         holder.Success;
      end
    )
    .Fail(
       procedure (ex: IFailureReason<Exception>)
       begin
         holder.Reason := ex.Reason;
         holder.Failed;
       end
    )
    .Always(
       procedure (const state: TState; success: integer; failure: IFailureReason<Exception>)
       begin
         holder.Value := holder.Value + success * 3;
         holder.Increment;
       end
    )
  ;

  p.Future.WaitFor;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(4096, holder.Value);
  Assert.IsNull(holder.Reason);

  Assert.AreEqual(1, holder.SuccessCount);
  Assert.AreEqual(0, holder.FailureCount);
  Assert.AreEqual(1, holder.AlwaysCount);
end;

type
  TCustomException = class(Exception)
  public
    destructor Destroy; override;
  end;

{ TCustomException }

destructor TCustomException.Destroy;
begin
  inherited;
end;

procedure TMyTestObject.test_always_failure;
var
  p: IPromise<integer,Exception,TNoProgress>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.When<integer>(Self.FailedCall('Oops', 10, TCustomException))
    .Done(
      procedure (value: integer)
      begin
         holder.Value := value;
         holder.Success;
      end
    )
    .Fail(
       procedure (ex: IFailureReason<Exception>)
       begin
         holder.Reason := ex.Reason;
         holder.Failed;
       end
    )
    .Always(
       procedure (const state: TState; success: integer; failure: IFailureReason<Exception>)
       begin
         holder.Value := holder.Value + success * 3;
         holder.Increment;
       end
    )
  ;

  p.Future.WaitFor;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(0, holder.Value);
  Assert.IsNotNull(holder.Reason);
  Assert.InheritsFrom(holder.Reason.ClassType, TCustomException);

  Assert.AreEqual(0, holder.SuccessCount);
  Assert.AreEqual(1, holder.FailureCount);
  Assert.AreEqual(1, holder.AlwaysCount);

end;

initialization
  TDUnitX.RegisterTestFixture(TMyTestObject);
end.
