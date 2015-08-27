unit PipelineTest;

interface

uses
  System.SysUtils, System.Classes,
  DUnitX.TestFramework;

type

  [TestFixture]
  TPipelineTest = class(TObject)
    [Test] procedure test_resolving_after_success_pipe;
    [Test] procedure test_resolving_after_failure_pipe;
    [Test] procedure test_rejecting_after_success_pipe;
    [Test] procedure test_rejecting_after_failure_pipe;
    [Test] procedure test_rejecting_after_fail_through_pipe;
    [Test] procedure test_resolving_after_success_through_pipe;
  end;

  [TestFixture]
  TMultiStepPipelineTest = class(TObject)
    [Test] procedure test_resolve_resolve_pipe;
    [Test] procedure test_resolve_reject_pipe;
    [Test] procedure test_reject_resolve_pipe;
    [Test] procedure test_reject_reject_pipe;
    [Test] procedure test_reject_resolve_pipe_no_wait;
    [Test] procedure test_resolve_resolve_pipe_with_conversion;
    [Test] procedure test_rejecting_after_fail_through_pipe_with_conversio;
    [Test] procedure test_resolving_after_success_through_pipe_with_conversion;
  end;

implementation

uses
  System.SyncObjs,
  Promise.Proto, ValueHolder
;

type EPipelineException = class(Exception);

{ TPiplineTest }

procedure TPipelineTest.test_resolving_after_success_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(100)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.value := value;

        Result := TPromise.Resolve<integer>(value + 1000);
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(100, preValue.value);
  Assert.AreEqual(1100, postValue.Value);
end;

procedure TPipelineTest.test_resolving_after_failure_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(100)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.value := value;

        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(100, preValue.value);

  Assert.IsNotNull(postValue.Error);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when latter calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual(0, postValue.Value);
  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);
end;

procedure TPipelineTest.test_resolving_after_success_through_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(500)
    .Catch(
      function (value: IFailureReason<Exception>): IPromise<integer, Exception>
      begin
        preValue.Error := value;
        preValue.Failed;

        Result := TPromise.Resolve<integer>(1000);
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, preValue.value);

  Assert.AreEqual(0, preValue.SuccessCount);
  Assert.AreEqual(0, preValue.FailureCount);

  Assert.AreEqual(500, postValue.Value);

  Assert.AreEqual(1, postValue.SuccessCount);
  Assert.AreEqual(0, postValue.FailureCount);
end;

procedure TPipelineTest.test_rejecting_after_success_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Reject<integer, Exception>(EPipelineException.Create('when first calls has failed'))
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.value := value;
        preValue.Success;

        Result := TPromise.Resolve<integer>(value + 1000);
      end,
      function (value: IFailureReason<Exception>): IPromise<integer, Exception>
      begin
        preValue.Error := value;
        preValue.Failed;

        Result := TPromise.Resolve<integer>(500);
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, preValue.value);
  Assert.IsNotNull(preValue.Error.Reason);
  Assert.InheritsFrom(preValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when first calls has failed', preValue.Error.Reason.Message);

  Assert.AreEqual(0, preValue.SuccessCount);
  Assert.AreEqual(1, preValue.FailureCount);

  Assert.AreEqual(500, postValue.Value);
end;

procedure TPipelineTest.test_rejecting_after_failure_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Reject<integer, Exception>(EPipelineException.Create('when first calls has failed'))
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.value := value;
        preValue.Success;

        Result := TPromise.Resolve<integer>(value + 1000);
      end,
      function (value: IFailureReason<Exception>): IPromise<integer, Exception>
      begin
        preValue.Error := value;
        preValue.Failed;

        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, preValue.value);
  Assert.IsNotNull(preValue.Error.Reason);
  Assert.InheritsFrom(preValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when first calls has failed', preValue.Error.Reason.Message);

  Assert.AreEqual(0, preValue.SuccessCount);
  Assert.AreEqual(1, preValue.FailureCount);

  Assert.IsNotNull(postValue.Error);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when latter calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual(0, postValue.Value);
  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);
end;

procedure TPipelineTest.test_rejecting_after_fail_through_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Reject<integer, Exception>(EPipelineException.Create('when first calls has failed'))
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Value := 1000;
        preValue.Success;

        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, preValue.value);
  Assert.IsNull(preValue.Error);

  Assert.AreEqual(0, preValue.SuccessCount);
  Assert.AreEqual(0, preValue.FailureCount);

  Assert.IsNotNull(postValue.Error);
  Assert.IsNotNull(postValue.Error.Reason);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when first calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual(0, postValue.Value);
  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);
end;

{ TMultiStepPiplineTest }

procedure TMultiStepPipelineTest.test_resolve_resolve_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(500)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Success;
        Result := TPromise.Resolve<integer>(value+1000);
      end
    )
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Success;
        Result := TPromise.Resolve<integer>(value+2000);
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(2, preValue.SuccessCount);

  Assert.AreEqual(3500, postValue.Value);
  Assert.IsNull(postValue.Error);

  Assert.AreEqual(1, postValue.SuccessCount);
  Assert.AreEqual(0, postValue.FailureCount);
end;

procedure TMultiStepPipelineTest.test_resolve_reject_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(800)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Success;
        Result := TPromise.Resolve<integer>(value+80);
      end
    )
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Success;
        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'))
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(2, preValue.SuccessCount);

  Assert.AreEqual(0, postValue.Value);
  Assert.IsNotNull(postValue.Error);
  Assert.IsNotNull(postValue.Error.Reason);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when latter calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);
end;

procedure TMultiStepPipelineTest.test_reject_resolve_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(2000)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Value := value;
        preValue.Success;
        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
    .Catch(
      function (value: IFailureReason<Exception>): IPromise<integer, Exception>
      begin
        preValue.Error := value;
        preValue.Failed;

        Result := TPromise.Resolve<integer>(1000);
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(2000, preValue.Value);
  Assert.IsNotNull(preValue.Error);
  Assert.IsNotNull(preValue.Error.Reason);
  Assert.InheritsFrom(preValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when latter calls has failed', preValue.Error.Reason.Message);

  Assert.AreEqual(1, preValue.SuccessCount);
  Assert.AreEqual(1, preValue.FailureCount);

  Assert.AreEqual(1000, postValue.Value);
  Assert.IsNull(postValue.Error);

  Assert.AreEqual(1, postValue.SuccessCount);
  Assert.AreEqual(0, postValue.FailureCount);
end;

procedure TMultiStepPipelineTest.test_reject_reject_pipe;
var
  p: IPromise<integer,Exception>;
  preValue, postValue: IHolder<integer>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<integer>.Create;

  p :=
    TPromise.Resolve<integer>(2000)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Value := value;
        preValue.Success;
        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
    .Catch(
      function (value: IFailureReason<Exception>): IPromise<integer, Exception>
      begin
        preValue.Error := value;
        preValue.Failed;

        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when final calls has failed'));
      end
    )
    .Done(
      procedure (value: integer)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(2000, preValue.Value);
  Assert.IsNotNull(preValue.Error);
  Assert.IsNotNull(preValue.Error.Reason);
  Assert.InheritsFrom(preValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when latter calls has failed', preValue.Error.Reason.Message);

  Assert.AreEqual(1, preValue.SuccessCount);
  Assert.AreEqual(1, preValue.FailureCount);

  Assert.AreEqual(0, postValue.Value);
  Assert.IsNotNull(postValue.Error);
  Assert.IsNotNull(postValue.Error.Reason);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when final calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);
end;

procedure DoTestNoWait(const signal: TEvent; const holder: IHolder<integer>);
var
  p: IPromise<integer,Exception>;
begin
  p :=
    TPromise.Resolve<integer>(2000)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        Result := TPromise.Reject<integer,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
    .Catch(
      function (value: IFailureReason<Exception>): IPromise<integer, Exception>
      begin
        Result := TPromise.Resolve<integer>(1000);
      end
    )
    .Done(
      procedure (value: integer)
      begin
        holder.Value := value;
        holder.Success;
        signal.SetEvent;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        holder.Error := value;
        holder.Failed;
        signal.SetEvent;
      end
    );
end;

procedure TMultiStepPipelineTest.test_reject_resolve_pipe_no_wait;
var
  holder: IHolder<integer>;
  signal: TEvent;
begin
  holder := TValueHolder<integer>.Create;

  signal := TEvent.Create;
  try
    DoTestNoWait(signal, holder);

    signal.WaitFor;
  finally
    signal.Free;
  end;
  while not CheckSynchronize do TThread.Sleep(100);

  Assert.AreEqual(1000, holder.Value);
  Assert.IsNull(holder.Error);

  Assert.AreEqual(1, holder.SuccessCount);
  Assert.AreEqual(0, holder.FailureCount);
end;

procedure TMultiStepPipelineTest.test_resolve_resolve_pipe_with_conversion;
var
  p: IPromise<string,Exception>;
  preValue: IHolder<integer>;
  postValue: IHolder<string>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<string>.Create;

  p :=
    TPromise.Resolve<integer>(500)
    .ThenBy(
      function (value: integer): IPromise<integer, Exception>
      begin
        preValue.Value := value;
        preValue.Success;
        Result := TPromise.Resolve<integer>(value+1000);
      end
    )
    .Op.ThenBy<string>(
      function (value: integer): IPromise<string, Exception>
      begin
        preValue.Value := value;
        preValue.Success;
        Result := TPromise.Resolve(value.ToString);
      end
    )
    .Done(
      procedure (value: string)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(1500, preValue.Value);

  Assert.AreEqual(2, preValue.SuccessCount);

  Assert.AreEqual('1500', postValue.Value);
  Assert.IsNull(postValue.Error);

  Assert.AreEqual(1, postValue.SuccessCount);
  Assert.AreEqual(0, postValue.FailureCount);

end;

procedure TMultiStepPipelineTest.test_rejecting_after_fail_through_pipe_with_conversio;
var
  p: IPromise<string,Exception>;
  preValue: IHolder<integer>;
  postValue: IHolder<string>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<string>.Create;

  p :=
    TPromise.Reject<integer, Exception>(EPipelineException.Create('when first calls has failed'))
    .Op.ThenBy<string>(
      function (value: integer): IPromise<string, Exception>
      begin
        preValue.Value := 1000;
        preValue.Success;

        Result := TPromise.Reject<string,Exception>(EPipelineException.Create('when latter calls has failed'));
      end
    )
   .ThenBy(
      function (value: string): IPromise<string, Exception>
      begin
        preValue.Success;

        Result := TPromise.Resolve<string>('[' + value + ']');
      end
   )
   .Done(
      procedure (value: string)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, preValue.value);
  Assert.IsNull(preValue.Error);

  Assert.AreEqual(0, preValue.SuccessCount);
  Assert.AreEqual(0, preValue.FailureCount);

  Assert.IsNotNull(postValue.Error);
  Assert.IsNotNull(postValue.Error.Reason);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when first calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual('', postValue.Value);
  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);end;

procedure TMultiStepPipelineTest.test_resolving_after_success_through_pipe_with_conversion;
var
  p: IPromise<string,Exception>;
  preValue: IHolder<integer>;
  postValue: IHolder<string>;
begin
  preValue := TValueHolder<integer>.Create;
  postValue := TValueHolder<string>.Create;

  p :=
    TPromise.Reject<integer, Exception>(EPipelineException.Create('when first calls has failed'))
    .Op.ThenBy<string>(
      function (value: integer): IPromise<string, Exception>
      begin
        preValue.Value := 1000;
        preValue.Success;

        Result := TPromise.Resolve<string>(value.ToString);
      end
    )
    .ThenBy(
      function (value: string): IPromise<string, Exception>
      begin
        preValue.Success;

        Result := TPromise.Resolve<string>('[' + value + ']');
      end
    )
    .Done(
      procedure (value: string)
      begin
        postValue.Value := value;
        postValue.Success;
      end
    )
    .Fail(
      procedure (value: IFailureReason<Exception>)
      begin
        postValue.Error := value;
        postValue.Failed;
      end
    );

  p.Future.WaitFor;

  Assert.AreEqual(0, preValue.value);
  Assert.IsNull(preValue.Error);

  Assert.AreEqual(0, preValue.SuccessCount);
  Assert.AreEqual(0, preValue.FailureCount);

  Assert.AreEqual('', postValue.Value);
  Assert.IsNotNull(postValue.Error);
  Assert.IsNotNull(postValue.Error.Reason);
  Assert.InheritsFrom(postValue.Error.Reason.ClassType, EPipelineException);
  Assert.AreEqual('when first calls has failed', postValue.Error.Reason.Message);

  Assert.AreEqual(0, postValue.SuccessCount);
  Assert.AreEqual(1, postValue.FailureCount);
end;

initialization

end.
