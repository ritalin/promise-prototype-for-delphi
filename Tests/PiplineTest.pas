unit PiplineTest;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework;

type

  [TestFixture]
  TPiplineTest = class(TObject) 
    [Test] procedure test_resolving_after_success_pipe;
    [Test] procedure test_resolving_after_failure_pipe;
    [Test] procedure test_rejecting_after_success_pipe;
    [Test] procedure test_rejecting_after_failure_pipe;
    [Test] procedure test_rejecting_after_fail_through_pipe;
    [Test] procedure test_resolving_after_success_through_pipe;
  end;

implementation

uses
  Promise.Proto, Promise.Types, ValueHolder
;

type EPipelineException = class(Exception);

{ TPiplineTest }

procedure TPiplineTest.test_resolving_after_success_pipe;
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

procedure TPiplineTest.test_resolving_after_failure_pipe;
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

procedure TPiplineTest.test_resolving_after_success_through_pipe;
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

procedure TPiplineTest.test_rejecting_after_success_pipe;
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

procedure TPiplineTest.test_rejecting_after_failure_pipe;
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

procedure TPiplineTest.test_rejecting_after_fail_through_pipe;
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

initialization

end.
