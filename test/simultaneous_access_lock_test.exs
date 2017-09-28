defmodule SimultaneousAccessLockTest do
  use ExUnit.Case
  doctest SimultaneousAccessLock
  import SimultaneousAccessLock

  @redis_false 0
  @redis_true 1

  @user "hugo"
  @max_locks 1
  @tolerance_max_locks 3
  @tolerance_time_limit 60

  def get_simple_lock(opts \\ %{}) do
    max_locks = Map.get(opts, :max_locks, @max_locks)
    get_lock(@user, max_locks)
  end

  def get_tolerance_lock do
    get_lock(@user, @max_locks, %{tolerance: %{milliseconds: @tolerance_time_limit, max_locks: @tolerance_max_locks}})
  end

  def renew_tolerance_lock(lock_id) do
    renew_lock(@user, lock_id, %{max_locks: @max_locks, tolerance: %{milliseconds: @tolerance_time_limit, max_locks: @tolerance_max_locks}})
  end

  setup do
    Redix.command(:redix, ["FLUSHALL"])
    :ok
  end

  describe "#get_lock\t" do
    test "when there are free slots, it get a new lock" do
      assert {:ok, _} = get_simple_lock()
    end

    test "when all slots are being used, it does not get a new lock" do
      get_simple_lock()
      assert {:error, :no_slots} = get_simple_lock()
    end

    test "after one expires, it get a new one in its place" do
      get_simple_lock(%{max_locks: 2})
      Process.sleep(25)
      get_simple_lock(%{max_locks: 2})
      Process.sleep(30)
      assert {:ok, _} = get_simple_lock(%{max_locks: 2})
      assert {:error, :no_slots} = get_simple_lock(%{max_locks: 2})
    end

    test "when all locks expires, the user key disapears" do
      get_simple_lock()
      Process.sleep(55)
      assert {:ok, @redis_false} = Redix.command(:redix, ["EXISTS", "lock:hugo"])
    end

    test "when pass the lock_id, the lock_id is not generated" do
      assert {:ok, "hugolockid"} = get_lock("hugo", 2, %{lock_id: "hugolockid"})
    end
  end

  describe "#get_lock [with toleration period]\t" do
    test "when there are free or extra slots available, it get a new lock " do
      assert {:ok, _} = get_tolerance_lock()
      assert {:ok, _} = get_tolerance_lock()
      assert {:ok, _} = get_tolerance_lock()
    end

    test "when all free and extra slots are being used, it does not get a new lock" do
      get_tolerance_lock()
      get_tolerance_lock()
      get_tolerance_lock()
      assert {:error, :no_slots} = get_tolerance_lock()
    end

    test "after one expires, it get a new one in its place" do
      get_tolerance_lock()
      Process.sleep(25)
      get_tolerance_lock()
      get_tolerance_lock()
      Process.sleep(30)
      get_tolerance_lock()
      assert {:error, :no_slots} = get_tolerance_lock()
    end

    test "after tolerance time have been exceeded, it does not get a new lock" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(35)
      {:ok, lock1_id} = renew_tolerance_lock(lock1_id)
      {:ok, lock2_id} = renew_tolerance_lock(lock2_id)
      Process.sleep(35)
      assert {:error, :no_slots} = get_tolerance_lock()
    end

    test "after extra locks expires, it reset tolerance time" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(35)
      {:ok, lock1_id} = renew_tolerance_lock(lock1_id)
      Process.sleep(35)
      assert {:ok, _} = get_tolerance_lock()
    end

    test "if all locks expires, the user key disapears " do
      get_tolerance_lock()
      Process.sleep(55)
      assert {:ok, @redis_false} = Redix.command(:redix, ["EXISTS", "lock:hugo"])
    end
  end

  describe "#renew_lock\t" do
    test "when the lock already exist, it renew the lock" do
      {:ok, lock_id} = get_lock("hugo", 2)
      assert {:ok, lock_id} = renew_lock("hugo", lock_id)
    end

    test "when the lock does not exist, it does not renew anything" do
      get_lock("hugo", 2)
      assert {:error, :not_found} = renew_lock("hugo", "non-existent-lock")
    end

    test "when the lock has already expired, it does not renew the lock" do
      {:ok, lock_id} = get_lock("hugo", 2)
      Process.sleep(55)
      assert {:error, :not_found} = renew_lock("hugo", lock_id)
    end

    test "when the lock is renewed, it update the lock expiration time" do
      {:ok, lock1_id} = get_lock("hugo", 2)
      {:ok, lock2_id} = get_lock("hugo", 2)
      Process.sleep(30)
      renew_lock("hugo", lock1_id)
      Process.sleep(25)
      assert {:ok, lock1_id} = renew_lock("hugo", lock1_id)
      assert {:error, :not_found} = renew_lock("hugo", lock2_id)
    end
  end

  describe "#renew_lock [with tolerance period]\t" do
    test "when the lock already exist, it renew the lock" do
      {:ok, lock_id} = get_tolerance_lock()
      assert {:ok, lock_id} = renew_tolerance_lock(lock_id)
    end

    test "when the lock does not exist, it does not renew anything" do
      get_tolerance_lock()
      assert {:error, :not_found} = renew_tolerance_lock("non-existent-lock")
    end

    test "when the lock has already expired, it does not renew the lock" do
      {:ok, lock_id} = get_tolerance_lock()
      Process.sleep(55)
      assert {:error, :not_found} = renew_tolerance_lock(lock_id)
    end

    test "when the lock is renewed, it update the lock expiration time" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(30)
      renew_tolerance_lock(lock1_id)
      Process.sleep(25)
      assert {:ok, lock1_id} = renew_tolerance_lock(lock1_id)
      assert {:error, :not_found} = renew_tolerance_lock(lock2_id)
    end

    test "when tolerance time is over, it expires the elder locks" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(35)
      renew_tolerance_lock(lock1_id)
      renew_tolerance_lock(lock2_id)
      Process.sleep(35)
      assert {:error, :not_found} = renew_tolerance_lock(lock1_id)
      assert {:ok, lock2_id} = renew_tolerance_lock(lock2_id)
    end
  end
end
