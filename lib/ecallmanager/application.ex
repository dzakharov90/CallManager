defmodule Ecallmanager.Application do
  use Application

  alias Ecallmanager.Routes
  alias Ecallmanager.ESLServer

  def start(_type, _args) do
    # Probably want to store this in a config
    # and load via Application.fetch_env!(:myapp, :db)
    opensips = [
      name: :opensips,
      username: Application.fetch_env!(:ecallmanager, :osusername),
      password: Application.fetch_env!(:ecallmanager, :ospassword),
      hostname: Application.fetch_env!(:ecallmanager, :oshostname),
      database: Application.fetch_env!(:ecallmanager, :osdatabase),
    ]

    freeswitch = [
      name: :freeswitch,
      username: Application.fetch_env!(:ecallmanager, :fsusername),
      password: Application.fetch_env!(:ecallmanager, :fspassword),
      hostname: Application.fetch_env!(:ecallmanager, :fshostname),
      database: Application.fetch_env!(:ecallmanager, :fsdatabase),
    ]

    accparams = [
      name: :accparams,
      username: Application.fetch_env!(:ecallmanager, :accusername),
      password: Application.fetch_env!(:ecallmanager, :accpassword),
      hostname: Application.fetch_env!(:ecallmanager, :acchostname),
      database: Application.fetch_env!(:ecallmanager, :accdatabase),
    ]

    children = [
      Supervisor.child_spec({Postgrex, opensips}, id: :my_worker_1),
      Supervisor.child_spec({Postgrex, freeswitch}, id: :my_worker_2),
      Supervisor.child_spec({Postgrex, accparams}, id: :my_worker_3),
      Routes,
      ESLServer,
    ]

    Supervisor.start_link(children, [strategy: :one_for_one, name: __MODULE__])
  end
end
