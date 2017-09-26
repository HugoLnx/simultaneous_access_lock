use Mix.Config

config :simultaneous_access_lock,
  ttl: :timer.seconds(30)
