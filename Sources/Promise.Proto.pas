unit Promise.Proto;

interface

uses
  System.SysUtils,
  Promise.Types
;

type
  TPromise = record
  public type
    TPolicy = (Default);
  public
    class function When<TResult>(const fn: TFunc<TResult>): IPromise<TResult, Exception>; overload; static;
    class function When<TResult>(const initializer: TPromiseInitProc<TResult, Exception>): IPromise<TResult, Exception>; overload; static;
    class function When<TResult; TFailure:Exception>(const initializer: TPromiseInitProc<TResult, TFailure>): IPromise<TResult, TFailure>; overload; static;
    class function Resolve<TResult>(value: TResult): IPromise<TResult, Exception>; static;
    class function Reject<TSuccess; TFailure:Exception>(value: TFailure): IPromise<TSuccess, TFailure>; overload; static;
    class function Reject<TFailure:Exception>(value: TFailure): IPromise<TObject, TFailure>; overload; static;
  end;

implementation

uses
  Promise.Core
;

{ TDefferredManager }

class function TPromise.When<TResult>(
  const fn: TFunc<TResult>): IPromise<TResult, Exception>;
begin
  Result :=
    TDeferredObject<TResult,Exception>
    .Create(
      procedure (const resolver: TProc<TResult>; const rejector: TFailureProc<Exception>)
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
  value: TFailure): IPromise<TObject, TFailure>;
begin
  Result := Reject<TObject,TFailure>(value);
end;

class function TPromise.Reject<TSuccess,TFailure>(
  value: TFailure): IPromise<TSuccess, TFailure>;
begin
  Result :=
    When<TSuccess,TFailure>(
      procedure (const resolver: TProc<TSuccess>; const rejector: TFailureProc<TFailure>)
      begin
        rejector(TFailureReason<TFailure>.Create(value));
      end
    );
end;

class function TPromise.Resolve<TResult>(
  value: TResult): IPromise<TResult, Exception>;
begin
  Result := When<TResult>(
    function: TResult
    begin
      Result := value;
    end
  );
end;

class function TPromise.When<TResult, TFailure>(
  const initializer: TPromiseInitProc<TResult, TFailure>): IPromise<TResult, TFailure>;
begin
  Result :=
    TDeferredObject<TResult,TFailure>
    .Create(initializer)
end;

class function TPromise.When<TResult>(
  const initializer: TPromiseInitProc<TResult, Exception>): IPromise<TResult, Exception>;
begin
  Result := When<TResult,Exception>(initializer);
end;

end.
