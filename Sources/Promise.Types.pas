unit Promise.Types;

interface

uses
  System.SysUtils
;

type
  TState = (Pending, Resolved, Rejected, Finished);

  EPromiseException = class(Exception);
  EInvalidPromiseStateException = class(EPromiseException);

  IFailureReason<TFailure> = interface
    ['{A7C29DBC-D00B-4B5D-ABD6-3280F9F49971}']
    function GetReason: TFailure;
    property Reason: TFailure read GetReason;
  end;

  IPromise<TSuccess, TFailure> = interface;

  TFailureProc<TFailure> = reference to procedure (failure: IFailureReason<TFailure>);
  TAlwaysProc<TSuccess,TFailure> = reference to procedure (const state: TState; success: TSuccess; failure: IFailureReason<TFailure>);
  TPromiseInitProc<TResult, TFailure> = reference to procedure (const resolver: TProc<TResult>; const rejector: TFailureProc<TFailure>);
  TPipelineFunc<TSource, TSuccess, TFailure> = reference to function (value: TSource): IPromise<TSuccess, TFailure>;
  IFuture<TResult> = interface;

  TPromiseOp<TSuccess, TFailure> = record

  end;

  IPromise<TSuccess, TFailure> = interface
    ['{19311A2D-7DDD-41CA-AD42-29FCC27179C5}']
    function GetFuture: IFuture<TSuccess>;
    function Done(const proc: TProc<TSuccess>): IPromise<TSuccess, TFailure>;
    function Fail(const proc: TFailureProc<TFailure>): IPromise<TSuccess, TFailure>;
    function ThenBy(const fn: TPipelineFunc<TSuccess, TSuccess, TFailure>): IPromise<TSuccess, TFailure>; overload;
    function ThenBy(
      const whenSuccess: TPipelineFunc<TSuccess, TSuccess, TFailure>;
      const whenfailure: TPipelineFunc<IFailureReason<TFailure>, TSuccess, TFailure>): IPromise<TSuccess, TFailure>; overload;
    function Catch(const whenfailure: TPipelineFunc<IFailureReason<TFailure>, TSuccess, TFailure>): IPromise<TSuccess, TFailure>;

    property Future: IFuture<TSuccess> read GetFuture;
  end;

  IPromiseAccess<TSuccess, TFailure> = interface
    ['{D6A8317E-CF96-41A5-80EE-5FFB2D1D7676}']
    function GetValue: TSuccess;
    function GetFailure: IFailureReason<TFailure>;
    function GetState: TState;
    function GetSelf: IPromise<TSuccess, TFailure>;

    property State: TState read GetState;
    property Self: IPromise<TSuccess, TFailure> read GetSelf;
  end;

  IPromiseResolvable<TSuccess, TFailure> = interface
    function Resolve(value: TSuccess): IPromise<TSuccess, TFailure>;
    function Reject(value: IFailureReason<TFailure>): IPromise<TSuccess, TFailure>;
  end;

  IFuture<TResult> = interface
    ['{844488AD-0136-41F8-94B1-B7BA2EB0C019}']
    function GetValue: TResult;
    procedure Cancell;
    function WaitFor: boolean;

    property Value: TResult read GetValue;
  end;

implementation

end.
