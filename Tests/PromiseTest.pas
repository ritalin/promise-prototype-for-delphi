unit PromiseTest;

interface
uses
  System.SysUtils, System.Classes, System.SyncObjs,
  DUnitX.TestFramework;

type
  TExceptionCalss = class of Exception;

  [TestFixture]
  TSinglePromiseTest = class(TObject)
  private
    function SuccessCall<TResult>(value: TResult; const waitMiliSecs: integer): TFunc<TResult>;
    function FailedCall(const msg: string;
      const waitMiliSecs: integer; const cls: TExceptionCalss = nil): TFunc<integer>;
  public
    [Test] procedure test_success_wait;
    [Test] procedure test_success_const_wait;
    [Test] procedure test_failure_wait;
    [Test] procedure test_failure_const_wait;
    [Test] procedure test_success_no_wait;
    [Test] procedure test_failure_no_wait;
  end;

implementation

uses
  Promise.Proto, Valueholder
;

{ TMyTestObject }

function TSinglePromiseTest.SuccessCall<TResult>(value: TResult;
  const waitMiliSecs: integer): TFunc<TResult>;
begin
  Result :=
    function: TResult
    begin
      TThread.Sleep(waitMiliSecs);

      Result := value;
    end;
end;

type TTestFailure = class(Exception);

function TSinglePromiseTest.FailedCall(const msg: string;
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
        raise TTestFailure.Create(msg);
      end;
    end;
end;

procedure TSinglePromiseTest.test_success_wait;
var
  p: IPromise<integer,Exception>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.When<integer>(Self.SuccessCall<integer>(123, 10))
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
         holder.Failed;
       end
    );

  p.Future.WaitFor;

  Assert.AreEqual(123, holder.Value);
  Assert.AreEqual(1, holder.SuccessCount);
  Assert.AreEqual(0, holder.FailureCount);
end;

procedure TSinglePromiseTest.test_success_const_wait;
var
  p: IPromise<integer,Exception>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(1024)
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
         holder.Failed;
       end
    );

  p.Future.WaitFor;

  Assert.AreEqual(1024, holder.Value);
  Assert.AreEqual(1, holder.SuccessCount);
  Assert.AreEqual(0, holder.FailureCount);
end;

procedure DoTestNoWait(const signal: TEvent; const fn: TFunc<integer>; const holder: IHolder<integer>);
var
  p: IPromise<integer,Exception>;
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

procedure TSinglePromiseTest.test_success_no_wait;
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

procedure TSinglePromiseTest.test_failure_wait;
var
  p: IPromise<integer,Exception>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.When<integer>(Self.FailedCall('Oops', 10))
    .Done(
      procedure (value: integer)
      begin
        holder.Success;
      end
    )
    .Fail(
      procedure (ex: IFailureReason<Exception>)
      begin
        holder.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, holder.SuccessCount);
  Assert.AreEqual(1, holder.FailureCount);
end;

procedure TSinglePromiseTest.test_failure_const_wait;
var
  p: IPromise<TObject,TTestFailure>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.Reject<TTestFailure>(TTestFailure.Create('Rejected'))
    .Done(
      procedure (value: TObject)
      begin
        holder.Success;
      end
    )
    .Fail(
      procedure (ex: IFailureReason<TTestFailure>)
      begin
        holder.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, holder.SuccessCount);
  Assert.AreEqual(1, holder.FailureCount);
end;

procedure TSinglePromiseTest.test_failure_no_wait;
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

initialization

end.
