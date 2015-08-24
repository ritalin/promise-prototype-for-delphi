unit Promise.Proto;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.SyncObjs
;

type
  TState = (Pending, Resolved, Rejected);

  IFailureReason<TFailure> = interface
    ['{A7C29DBC-D00B-4B5D-ABD6-3280F9F49971}']
    function GetReason: TFailure;
    property Reason: TFailure read GetReason;
  end;

  TNoProgress = Pointer;

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
  end;

  TDeferredObject<TSuccess; TFailure:Exception; TProgress> = class (TInterfacedObject, IPromise<TSuccess, TFailure, TProgress>)
  private
    FState: TState;
    FSuccess: TSuccess;
    FFailure: IFailureReason<TFailure>;
    FFuture: IFuture<TSuccess>;
    FDoneActions: TList<TProc<TSuccess> >;
    FFailActions: TList<TFailureProc<TFailure>>;
    FAlwaysActions: TList<TAlwaysProc<TSuccess, TFailure>>;
  private
    function GetFuture: IFuture<TSuccess>;
    function IsPending: boolean;
    function IsResolved: boolean;
    function IsRejected: boolean;
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
    constructor Create(const fn: TFunc<TSuccess>);
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
    procedure DoExecute(const fn: TFunc<TResult>);
  public
    constructor Create(const promise: IPromise<TResult,TFailure,TProgress>; const fn: TFunc<TResult>);
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
  Result := TDeferredObject<TResult,Exception,TNoProgress>.Create(fn);
end;

{ TDefferredTask<TResult, TProgress> }

procedure TDeferredTask<TResult,TFailure,TProgress>.Cancell;
begin

end;

constructor TDeferredTask<TResult,TFailure,TProgress>.Create(
  const promise: IPromise<TResult,TFailure,TProgress>;
  const fn: TFunc<TResult>);
begin
  FPromise := promise;
  FPolicy := TPromise.TPolicy.Default;
  FSignal := TEvent.Create;

  FThread := TThread.CreateAnonymousThread(
    procedure
    begin
      Self.DoExecute(fn);
    end
  );
//  FThread.FreeOnTerminate := false;
  FThread.OnTerminate := Self.NotifyThreadTerminated;
  FThread.Start;
end;

destructor TDeferredTask<TResult,TFailure,TProgress>.Destroy;
begin
  FreeAndNil(FSignal);
  inherited;
end;

procedure TDeferredTask<TResult,TFailure,TProgress>.DoExecute(const fn: TFunc<TResult>);
var
  obj: TObject;
begin
  try
    FResult := fn;

    FPromise.Resolve(FResult);
  except
    obj := AcquireExceptionObject;
    FPromise.Reject(obj as TFailure);
  end;

  FSignal.SetEvent;
end;

function TDeferredTask<TResult,TFailure,TProgress>.GetValue: TResult;
begin
  if Assigned(FThread) then begin
    if not FThread.Finished then begin
      FSignal.WaitFor;
    end;
    FPromise := nil;
  end;

  Result := FResult;
end;

procedure TDeferredTask<TResult, TFailure, TProgress>.NotifyThreadTerminated(
  Sender: TObject);
begin
  FPromise := nil;
end;

function TDeferredTask<TResult, TFailure, TProgress>.WaitFor: boolean;
begin
  Result := FSignal.WaitFor = wrSignaled;
end;

{ TDeferredObject<TSuccess, TFailure, TProgress> }

constructor TDeferredObject<TSuccess, TFailure, TProgress>.Create(const fn: TFunc<TSuccess>);
begin
  FFuture := TDeferredTask<TSuccess,TFailure,TProgress>.Create(Self, fn);

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
    Assert(Self.IsPending, 'Deferred object already finished.');

    FState := TState.Resolved;
    FSuccess := value;

    try
      Self.TriggerDone(value);
    finally
      Self.TriggerAlways(FState, value, nil);
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TDeferredObject<TSuccess, TFailure, TProgress>.Reject(
  value: TFailure): IPromise<TSuccess, TFailure, TProgress>;
begin
  TMonitor.Enter(Self);
  try
    Assert(Self.IsPending, 'Deferred object already finished.');

    FState := TState.Rejected;
    FFailure := TFailureReason<TFailure>.Create(value);

    try
      Self.TriggerFail(FFailure);
    finally
      Self.TriggerAlways(FState, System.Default(TSuccess), FFailure);
    end;
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
  for proc in FAlwaysActions do begin
    proc(state, success, failure);
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
