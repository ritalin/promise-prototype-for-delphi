unit Promise.Proto;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs
;

type
  TState = (Pending, Resolved, Rejected);

  TPromiseException = class(Exception);
  TInvalidpromiseStateException = class(TPromiseException);

  IFailureReason<TFailure> = interface
    ['{A7C29DBC-D00B-4B5D-ABD6-3280F9F49971}']
    function GetReason: TFailure;
    property Reason: TFailure read GetReason;
  end;

  TNoProgress = Pointer;

  TPromiseInitProc<TResult, TFailure> = reference to procedure (const resolver: TProc<TResult>; const rejector: TProc<TFailure>);
  TFailureProc<TFailure> = reference to procedure (failure: IFailureReason<TFailure>);
  TAlwaysProc<TSuccess,TFailure> = reference to procedure (const state: TState; success: TSuccess; failure: IFailureReason<TFailure>);

  IFuture<TResult> = interface;

  IPromise<TSuccess, TFailure, TProgress> = interface
    ['{19311A2D-7DDD-41CA-AD42-29FCC27179C5}']
    function GetFuture: IFuture<TSuccess>;
    function Resolve(value: TSuccess): IPromise<TSuccess, TFailure, TProgress>;
    function Reject(value: TFailure): IPromise<TSuccess, TFailure, TProgress>;
    function Done(const proc: TProc<TSuccess>): IPromise<TSuccess, TFailure, TProgress>;
    function Fail(const proc: TFailureProc<TFailure>): IPromise<TSuccess, TFailure, TProgress>;
    function Always(const proc: TAlwaysProc<TSuccess,TFailure>): IPromise<TSuccess, TFailure, TProgress>;

    property Future: IFuture<TSuccess> read GetFuture;
  end;

  IFuture<TResult> = interface
    ['{844488AD-0136-41F8-94B1-B7BA2EB0C019}']
    function GetValue: TResult;
    procedure Cancell;
    function WaitFor: boolean;

    property Value: TResult read GetValue;
  end;

  IFutureTask<TResult, TProgress> = interface(IFuture<TResult>)
    ['{4DB74171-DB77-41B4-9C23-9ED06B017E18}']
  end;

  TPromise = record
  public type
    TPolicy = (Default);
  public
    class function When<TResult>(const fn: TFunc<TResult>): IPromise<TResult, Exception, TNoProgress>; overload; static;
    class function When<TResult>(const initializer: TPromiseInitProc<TResult, Exception>): IPromise<TResult, Exception, TNoProgress>; overload; static;
    class function When<TResult; TFailure:Exception>(const initializer: TPromiseInitProc<TResult, TFailure>): IPromise<TResult, TFailure, TNoProgress>; overload; static;
    class function Resolve<TResult>(value: TResult): IPromise<TResult, Exception, TNoProgress>; static;
    class function Reject<TFailure:Exception>(value: TFailure): IPromise<TObject, TFailure, TNoProgress>; static;
  end;

  TDeferredObject<TSuccess; TFailure:Exception; TProgress> = class (TInterfacedObject, IPromise<TSuccess, TFailure, TProgress>)
  private
    FState: TState;
    FFinished: boolean;
    FSuccess: TSuccess;
    FFailure: IFailureReason<TFailure>;
    FFuture: IFuture<TSuccess>;
    FDoneActions: TList<TProc<TSuccess> >;
    FFailActions: TList<TFailureProc<TFailure>>;
    FAlwaysActions: TList<TAlwaysProc<TSuccess, TFailure>>;
  private
    function Init(const initializer: TPromiseInitProc<TSuccess,TFailure>): IPromise<TSuccess, TFailure, TProgress>;
    function GetFuture: IFuture<TSuccess>;
    function IsPending: boolean;
    function IsResolved: boolean;
    function IsRejected: boolean;
    procedure AssertState(const acceptable: boolean; const msg: string);
    procedure TriggerDone(value: TSuccess);
    procedure TriggerFail(value: IFailureReason<TFailure>);
    procedure TriggerAlways(const state: TState; success: TSuccess; failure: IFailureReason<TFailure>);
  protected
    { IDeferred<TSuccess, TFailure, TProgress> }
    function Resolve(value: TSuccess): IPromise<TSuccess, TFailure, TProgress>;
    function Reject(value: TFailure): IPromise<TSuccess, TFailure, TProgress>;
    function Done(const proc: TProc<TSuccess>): IPromise<TSuccess, TFailure, TProgress>;
    function Fail(const proc: TFailureProc<TFailure>): IPromise<TSuccess, TFailure, TProgress>;
    function Always(const proc: TAlwaysProc<TSuccess,TFailure>): IPromise<TSuccess, TFailure, TProgress>;
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TDeferredTask<TResult; TFailure:Exception; TProgress> = class (TInterfacedObject, IFuture<TResult>)
  strict private var
    FThread: TThread;
    FSignal: TEvent;
    FResult: TResult;
  private var
    FPromise: IPromise<TResult,TFailure,TProgress>;
    FPolicy: TPromise.TPolicy;
  private
    function GetValue: TResult;
    procedure NotifyThreadTerminated(Sender: TObject);
  protected
    { IDeferredTask<TResult, TProgress> }
    procedure Cancell;
    function WaitFor: boolean;
  protected
    procedure DoExecute(const initializer: TPromiseInitProc<TResult, TFailure>);
  public
    constructor Create(const promise: IPromise<TResult,TFailure,TProgress>; const initializer: TPromiseInitProc<TResult,TFailure>); overload;
    destructor Destroy; override;
  end;

  TFailureReason<TFailure: Exception>  = class(TInterfacedObject, IFailureReason<TFailure>)
  private
    FReason: TFailure;
  protected
    function GetReason: TFailure;
  public
    constructor Create(const reason: TFailure);
    destructor Destroy; override;
  end;

implementation

{ TDefferredManager }

class function TPromise.When<TResult>(
  const fn: TFunc<TResult>): IPromise<TResult, Exception, TNoProgress>;
begin
  Result :=
    TDeferredObject<TResult,Exception,TNoProgress>
    .Create
    .Init(
      procedure (const resolver: TProc<TResult>; const rejector: TProc<Exception>)
      var
        r: TResult;
      begin
        if Assigned(fn) then begin
          r := fn;
        end
        else begin
          r := System.Default(TResult);
        end;
        resolver(r);
      end
    );
end;

class function TPromise.Reject<TFailure>(
  value: TFailure): IPromise<TObject, TFailure, TNoProgress>;
begin
  Result :=
    When<TObject,TFailure>(
      procedure (const resolver: TProc<TObject>; const rejector: TProc<TFailure>)
      begin
        rejector(value);
      end
    );
end;

class function TPromise.Resolve<TResult>(
  value: TResult): IPromise<TResult, Exception, TNoProgress>;
begin
  Result := When<TResult>(
    function: TResult
    begin
      Result := value;
    end
  );
end;

class function TPromise.When<TResult, TFailure>(
  const initializer: TPromiseInitProc<TResult, TFailure>): IPromise<TResult, TFailure, TNoProgress>;
begin
  Result :=
    TDeferredObject<TResult,TFailure,TNoProgress>
    .Create
    .Init(initializer)
end;

class function TPromise.When<TResult>(
  const initializer: TPromiseInitProc<TResult, Exception>): IPromise<TResult, Exception, TNoProgress>;
begin
  Result := When<TResult,Exception>(initializer);
end;

{ TDefferredTask<TResult, TProgress> }

procedure TDeferredTask<TResult,TFailure,TProgress>.Cancell;
begin

end;

constructor TDeferredTask<TResult, TFailure, TProgress>.Create(
  const promise: IPromise<TResult,TFailure,TProgress>;
  const initializer: TPromiseInitProc<TResult, TFailure>);
begin
  FPromise := promise;
  FSignal := TEvent.Create;
  FPolicy := TPromise.TPolicy.Default;

  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      Self.DoExecute(initializer);
    end
  );

  FThread.OnTerminate := Self.NotifyThreadTerminated;
  FThread.Start;
end;

destructor TDeferredTask<TResult,TFailure,TProgress>.Destroy;
begin
  FreeAndNil(FSignal);
  inherited;
end;

procedure TDeferredTask<TResult,TFailure,TProgress>.DoExecute(const initializer: TPromiseInitProc<TResult, TFailure>);
var
  obj: TObject;
begin
  try
    initializer(
      procedure (value: TResult)
      begin
        FResult := value;
        FPromise.Resolve(value);
      end,
      procedure (value: TFailure)
      begin
        FPromise.Reject(value);
      end
    );
  except
    obj := AcquireExceptionObject;
    FPromise.Reject(obj as TFailure);
  end;

  FSignal.SetEvent;
end;

function TDeferredTask<TResult,TFailure,TProgress>.GetValue: TResult;
begin
  Self.WaitFor;

  Result := FResult;
end;

procedure TDeferredTask<TResult, TFailure, TProgress>.NotifyThreadTerminated(
  Sender: TObject);
begin
  FPromise := nil;
end;

function TDeferredTask<TResult, TFailure, TProgress>.WaitFor: boolean;
begin
  Result := false;
  if Assigned(FThread) then begin
    if not FThread.Finished then begin
      Result := FSignal.WaitFor = wrSignaled;
    end;
    FPromise := nil;
  end;

  while not CheckSynchronize do TThread.Sleep(100);
end;

{ TDeferredObject<TSuccess, TFailure, TProgress> }

procedure TDeferredObject<TSuccess, TFailure, TProgress>.AssertState(
  const acceptable: boolean; const msg: string);
begin
  if not acceptable then begin
    FState := TState.Pending;

    raise TInvalidpromiseStateException.Create(msg);
  end;
end;

constructor TDeferredObject<TSuccess, TFailure, TProgress>.Create;
begin
  FDoneActions := TList<TProc<TSuccess>>.Create;
  FFailActions := TList<TFailureProc<TFailure>>.Create;
  FAlwaysActions := TList<TAlwaysProc<TSuccess,TFailure>>.Create;
end;

destructor TDeferredObject<TSuccess, TFailure, TProgress>.Destroy;
begin
  FDoneActions.Free;
  FFailActions.Free;
  FAlwaysActions.Free;
  inherited;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Init(
  const initializer: TPromiseInitProc<TSuccess, TFailure>): IPromise<TSuccess, TFailure, TProgress>;
begin
  FFuture := TDeferredTask<TSuccess,TFailure,TProgress>.Create(Self, initializer);

  Result := Self;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Done(
  const proc: TProc<TSuccess>): IPromise<TSuccess, TFailure, TProgress>;
begin
  TMonitor.Enter(Self);
  try
    if Self.IsResolved then begin
      proc(Self.GetFuture.Value);
    end
    else begin
      FDoneActions.Add(proc);
    end;
  finally
    TMonitor.Exit(Self);
  end;

  Result := Self;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Fail(
  const proc: TFailureProc<TFailure>): IPromise<TSuccess, TFailure, TProgress>;
begin
  TMonitor.Enter(Self);
  try
    if Self.IsRejected then begin
      proc(FFailure);
    end
    else begin
      FFailActions.Add(proc);
    end;
  finally
    TMonitor.Exit(Self);
  end;

  Result := Self;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Always(
  const proc: TAlwaysProc<TSuccess, TFailure>): IPromise<TSuccess, TFailure, TProgress>;
begin
  TMonitor.Enter(Self);
  try
    if not Self.IsPending then begin
      proc(FState, FSuccess, FFailure);
    end
    else begin
      FAlwaysActions.Add(proc);
    end;
  finally
    TMonitor.Exit(Self);
  end;

  Result := Self;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.GetFuture: IFuture<TSuccess>;
begin
  Result := FFuture;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Resolve(
  value: TSuccess): IPromise<TSuccess, TFailure, TProgress>;
begin
  TMonitor.Enter(Self);
  try
    AssertState(Self.IsPending, 'Deferred object already finished.');

    FSuccess := value;

    Self.TriggerDone(value);
    Self.TriggerAlways(FState, value, nil);

    FState := TState.Resolved;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Reject(
  value: TFailure): IPromise<TSuccess, TFailure, TProgress>;
begin
  TMonitor.Enter(Self);
  try
    AssertState(Self.IsPending, 'Deferred object already finished.');

    FFailure := TFailureReason<TFailure>.Create(value);
    try
      Self.TriggerFail(FFailure);
    finally
      Self.TriggerAlways(FState, System.Default(TSuccess), FFailure);
    end;

    FState := TState.Rejected;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.IsPending: boolean;
begin
  Result := FState = TState.Pending;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.IsResolved: boolean;
begin
  Result := FState = TState.Resolved;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.IsRejected: boolean;
begin
  Result := FState = TState.Rejected;
end;

procedure TDeferredObject<TSuccess, TFailure, TProgress>.TriggerDone(
  value: TSuccess);
var
  proc: TProc<TSuccess>;
begin
  for proc in FDoneActions do begin
    proc(value);
  end;
end;

procedure TDeferredObject<TSuccess, TFailure, TProgress>.TriggerFail(
  value: IFailureReason<TFailure>);
var
  proc: TFailureProc<TFailure>;
begin
  for proc in FFailActions do begin
    proc(value);
  end;
end;

procedure TDeferredObject<TSuccess, TFailure, TProgress>.TriggerAlways(
  const state: TState; success: TSuccess;
  failure: IFailureReason<TFailure>);
var
  proc: TAlwaysProc<TSuccess,TFailure>;
begin
  if not FFinished then begin
    FFinished := true;

    for proc in FAlwaysActions do begin
      proc(state, success, failure);
    end;
  end;
end;

{ TFailureReason<TFailure> }

constructor TFailureReason<TFailure>.Create(const reason: TFailure);
begin
  FReason := reason;
end;

destructor TFailureReason<TFailure>.Destroy;
begin
  FReason.Free;
  inherited;
end;

function TFailureReason<TFailure>.GetReason: TFailure;
begin
  Result := FReason;
end;

end.
