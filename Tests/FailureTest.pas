unit FailureTest;

interface
uses
  System.SysUtils,
  DUnitX.TestFramework;

type

  [TestFixture]
  TFailureTest = class(TObject) 
  public
    [Test] procedure test_bad_callback_flow;
    [Test] procedure test_resolving_twice;
  end;

implementation

uses
  Promise.Proto, ValueHolder
;

{ TFailureTest }

procedure TFailureTest.test_bad_callback_flow;
var
  p: IPromise<integer,Exception>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p :=
    TPromise.When<integer>(
      function: integer
      begin
        Result := 1024;
      end
    )
    .Done(
      procedure (value: integer)
      begin
        holder.Value := 1024;
        holder.Success;

        raise Exception.Create('Raise into done callback');
      end
    )
    .Fail(
       procedure (ex: IFailureReason<Exception>)
       begin
         holder.Error := ex;
         holder.Failed;
       end
    )
  ;

  p.Future.WaitFor;

  Assert.AreEqual(1024, holder.Value);
  Assert.IsNotNull(holder.Error);
  Assert.InheritsFrom(holder.Error.Reason.ClassType, Exception);
  Assert.AreEqual('Raise into done callback', holder.Error.Reason.Message);

  Assert.AreEqual(1, holder.SuccessCount);
  Assert.AreEqual(1, holder.FailureCount);
end;

procedure TFailureTest.test_resolving_twice;
var
  p: IPromise<integer,Exception>;
  holder: IHolder<integer>;
begin
  holder := TValueHolder<integer>.Create;

  p := TPromise.When<integer>(
    procedure (const resolver: TProc<integer>; const rejector: TFailureProc<Exception>)
    begin
      resolver(1000);
      resolver(1000);
      holder.Success;
    end
  )
  .Fail(
    procedure (failure: IFailureReason<Exception>)
    begin
      holder.Failed;
    end
  );

  p.Future.WaitFor;

  Assert.AreEqual(0, holder.SuccessCount);
  Assert.AreEqual(1, holder.FailureCount);
end;

initialization

end.
