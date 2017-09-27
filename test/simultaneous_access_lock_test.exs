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
    get_lock(@user, @max_locks, tolerance: %{milliseconds: @tolerance_time_limit, max_locks: @tolerance_max_locks})
  end

  def renew_tolerance_lock(lock_id) do
    renew_lock(@user, lock_id, max_locks: @max_locks, tolerance: %{milliseconds: @tolerance_time_limit, max_locks: @tolerance_max_locks})
  end

  setup do
    Redix.command(:redix, ["FLUSHALL"])
    :ok
  end

  describe "getting new lock with no toleration time" do
    test "get new lock when there are free slots" do
      assert {:ok, _} = get_simple_lock()
    end

    test "can not get a new lock when all slots are being used" do
      get_simple_lock()
      assert {:error, :no_slots} = get_simple_lock()
    end

    test "can get new locks after one expires" do
      get_simple_lock(%{max_locks: 2})
      Process.sleep(25)
      get_simple_lock(%{max_locks: 2})
      Process.sleep(30)
      assert {:ok, _} = get_simple_lock(%{max_locks: 2})
      assert {:error, :no_slots} = get_simple_lock(%{max_locks: 2})
    end

    test "the user key disapears if all locks expires" do
      get_simple_lock()
      Process.sleep(55)
      assert {:ok, @redis_false} = Redix.command(:redix, ["EXISTS", "lock:hugo"])
    end
  end

  describe "getting new lock with toleration time" do
    test "get new lock when there are free or extra slots available" do
      assert {:ok, _} = get_tolerance_lock()
      assert {:ok, _} = get_tolerance_lock()
      assert {:ok, _} = get_tolerance_lock()
    end

    test "can not get a new lock when all free and extra slots are being used" do
      get_tolerance_lock()
      get_tolerance_lock()
      get_tolerance_lock()
      assert {:error, :no_slots} = get_tolerance_lock()
    end

    test "can get new locks after one expires" do
      get_tolerance_lock()
      Process.sleep(25)
      get_tolerance_lock()
      get_tolerance_lock()
      Process.sleep(30)
      get_tolerance_lock()
      assert {:error, :no_slots} = get_tolerance_lock()
    end

    test "can not get new locks after tolerance time have been exceeded" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(35)
      {:ok, lock1_id} = renew_tolerance_lock(lock1_id)
      {:ok, lock2_id} = renew_tolerance_lock(lock2_id)
      Process.sleep(35)
      assert {:error, :no_slots} = get_tolerance_lock()
    end

    test "reset tolerance time after extra locks expires" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(35)
      {:ok, lock1_id} = renew_tolerance_lock(lock1_id)
      Process.sleep(35)
      assert {:ok, _} = get_tolerance_lock()
    end

    test "the user key disapears if all locks expires" do
      get_tolerance_lock()
      Process.sleep(55)
      assert {:ok, @redis_false} = Redix.command(:redix, ["EXISTS", "lock:hugo"])
    end
  end

  describe "renewing locks without tolerance" do
    test "can renew a lock that already exist" do
      {:ok, lock_id} = get_lock("hugo", 2)
      assert {:ok, lock_id} = renew_lock("hugo", lock_id)
    end

    test "can not renew a lock that does not exist" do
      get_lock("hugo", 2)
      assert {:error, :not_found} = renew_lock("hugo", "non-existent-lock")
    end

    test "can not renew a expired lock" do
      {:ok, lock_id} = get_lock("hugo", 2)
      Process.sleep(55)
      assert {:error, :not_found} = renew_lock("hugo", lock_id)
    end

    test "a renewed lock expires later" do
      {:ok, lock1_id} = get_lock("hugo", 2)
      {:ok, lock2_id} = get_lock("hugo", 2)
      Process.sleep(30)
      renew_lock("hugo", lock1_id)
      Process.sleep(25)
      assert {:ok, lock1_id} = renew_lock("hugo", lock1_id)
      assert {:error, :not_found} = renew_lock("hugo", lock2_id)
    end
  end

  describe "renewing locks with tolerance" do
    test "can renew a lock that already exist" do
      {:ok, lock_id} = get_tolerance_lock()
      assert {:ok, lock_id} = renew_tolerance_lock(lock_id)
    end

    test "can not renew a lock that does not exist" do
      get_tolerance_lock()
      assert {:error, :not_found} = renew_tolerance_lock("non-existent-lock")
    end

    test "can not renew a expired lock" do
      {:ok, lock_id} = get_tolerance_lock()
      Process.sleep(55)
      assert {:error, :not_found} = renew_tolerance_lock(lock_id)
    end

    test "a renewed lock expires later" do
      {:ok, lock1_id} = get_tolerance_lock()
      {:ok, lock2_id} = get_tolerance_lock()
      Process.sleep(30)
      renew_tolerance_lock(lock1_id)
      Process.sleep(25)
      assert {:ok, lock1_id} = renew_tolerance_lock(lock1_id)
      assert {:error, :not_found} = renew_tolerance_lock(lock2_id)
    end

    test "expires old locks when tolerance time is over" do
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
