defmodule Ecallmanager.Directory do
  use Plug.Router
  import XmlBuilder
  require Logger
  alias Postgrex
  alias Jason

  plug(:match)
  plug Plug.Parsers,
  parsers: [:urlencoded, {:json, json_decoder: Jason}]
  plug(:dispatch)

  @content_type "application/xml"

  post "/", assigns: %{an_option: :a_value} do
    conn
    |> put_resp_content_type(@content_type)
    |> send_resp(200, buildxml(conn.body_params))
  end

  match _ do
    send_resp(conn, 404, "Requested page not found!")
  end

  def buildxml(params) do
    Logger.info "Body is #{inspect(params)}"
    with {:ok, domain} <- Map.fetch(params, "sip_request_host") do
      Logger.info "sip_request_host is #{domain}"
      with {:ok, sip_to_user} <- Map.fetch(params, "user") do
        document(:document, %{type: "freeswitch/xml"}, [
          element(:section, %{name: "directory"}, [
            directorysinglexml(domain, sip_to_user)
          ]),
        ]) |> generate(standalone: false)
      else
        _->
        document(:document, %{type: "freeswitch/xml"}, [
          element(:section, %{name: "directory"}, [
            directoryxml(domain)
          ]),
        ]) |> generate(standalone: false)
      end
    else
      _->
      [[domains]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT domain FROM domain) t", []).rows
      document(:document, %{type: "freeswitch/xml"}, [
        element(:section, %{name: "directory"}, [
          directoriesxml(domains),
        ]),
      ]) |> generate(standalone: false)
    end
  end

  def directoryxml(domain) do
    Logger.info "directoryxml"
    [[query]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM subscriber WHERE domain=$1) t", [domain]).rows
    element(:domain, %{name: "#{domain}"}, [
      element(:params,[
        element(:param, %{name: "dial-string", value: "{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})},${verto_contact(${dialed_user}@${dialed_domain})}"}),
        element(:param, %{name: "jsonrpc-allowed-methods", value: "verto"}),
        element(:param, %{name: "jsonrpc-allowed-event-channels", value: "demo,conference,presence"}),
        element(:param, %{name: "allow-empty-password", value: "false"}),
      ]),
        element(:users,[
          subscribers(query),
        ]),
    ]) |> generate
  end

  def directorysinglexml(domain,subscriber) do
    Logger.info "directorysinglexml"
    [[query]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM subscriber WHERE domain=$1 AND username=$2) t", [domain,subscriber]).rows
    element(:domain, %{name: "#{domain}"}, [
      element(:params,[
        element(:param, %{name: "dial-string", value: "{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})},${verto_contact(${dialed_user}@${dialed_domain})}"}),
        element(:param, %{name: "jsonrpc-allowed-methods", value: "verto"}),
        element(:param, %{name: "jsonrpc-allowed-event-channels", value: "demo,conference,presence"}),
        element(:param, %{name: "allow-empty-password", value: "false"}),
      ]),
        element(:users,[
          subscribers(query),
        ]),
    ]) |> generate
  end

  def directoriesxml(domainlist) do
    Logger.info "directoriesxml"
    for dom <- domainlist do
      {:ok, domain} = Map.fetch(dom, "domain")
      Logger.info "domain is #{domain}"
      [[query]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM subscriber WHERE domain=$1) t", [domain]).rows
      element(:domain, %{name: "#{domain}"}, [
        element(:params,[
          element(:param, %{name: "dial-string", value: "{^^:sip_invite_domain=${dialed_domain}:presence_id=${dialed_user}@${dialed_domain}}${sofia_contact(*/${dialed_user}@${dialed_domain})},${verto_contact(${dialed_user}@${dialed_domain})}"}),
          element(:param, %{name: "jsonrpc-allowed-methods", value: "verto"}),
          element(:param, %{name: "jsonrpc-allowed-event-channels", value: "demo,conference,presence"}),
          element(:param, %{name: "allow-empty-password", value: "false"}),
        ]),
          element(:users,[
            subscribers(query)
          ]),
      ]) |> generate
    end
  end

  def subscribers(sublist) do
    Logger.info "List is #{inspect(sublist)}"
    if sublist != nil do
      for subscriber <- sublist do
        {:ok, username} = Map.fetch(subscriber, "username")
        {:ok, password} = Map.fetch(subscriber, "password")
        {:ok, domain} = Map.fetch(subscriber, "domain")
        {:ok, cidname} = Map.fetch(subscriber, "cidname")
        {:ok, cidnum} = Map.fetch(subscriber, "cidnum")
        {:ok, toll_allow} = Map.fetch(subscriber, "toll_allow")
        element(:user, %{id: "#{username}", "number-alias": "#{cidnum}"},[
          element(:params,[
            element(:param, %{name: "password", value: "#{password}"}),
          ]),
          element(:variables,[
            element(:variable, %{name: "effective_caller_id_number", value: "#{cidnum}"}),
            element(:variable, %{name: "effective_caller_id_name", value: "#{cidname}"}),
            element(:variable, %{name: "outbound_caller_id_number", value: "#{cidnum}"}),
            element(:variable, %{name: "outbound_caller_id_name", value: "#{cidname}"}),
            element(:variable, %{name: "toll_allow", value: "#{toll_allow}"}),
            element(:variable, %{name: "mailbox", value: "#{cidname}"}),
            #element(:variable, %{name: "sip-force-expires", value: "60"}),
            #element(:variable, %{name: "sip-force-user", value: "#{username}"}),
            element(:variable, %{name: "user_context", value: "#{domain}"}),
          ]),
        ]) |> generate
      end
    else
      element(:result,%{status: "not found"}) |> generate
    end
  end
end
