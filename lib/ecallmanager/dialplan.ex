defmodule Ecallmanager.Dialplan do
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
    with {:ok, domain} <- Map.fetch(params, "Caller-Context") do
      if domain == "params" do
        document(:document, %{type: "freeswitch/xml"}, [
          element(:section, %{name: "dialplan"}, [
            dialplanpubliccontextxml(),
          ]),
        ]) |> generate(standalone: false)
      else
      Logger.info "sip_request_host is #{domain}"
        document(:document, %{type: "freeswitch/xml"}, [
          element(:section, %{name: "dialplan"}, [
            dialplansinglecontextxml(domain),
          ]),
        ]) |> generate(standalone: false)
      end
    else
      _->
      [[domains]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT domain FROM domain) t", []).rows
       document(:document, %{type: "freeswitch/xml"}, [
        element(:section, %{name: "dialplan"}, [
          dialplanallcontextxml(domains),
        ]),
      ]) |> generate(standalone: false)
    end
  end

  def dialplansinglecontextxml(domain) do
    Logger.info "dialplansinglecontextxml"
    [[clientparams]] = Postgrex.query!(:accparams, "SELECT json_agg(t) FROM (SELECT * FROM account_params WHERE domain='#{domain}') t", []).rows
    [[acllist]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM address WHERE domain='#{domain}') t", []).rows
    [[subscriberslist]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM subscriber WHERE domain='#{domain}') t", []).rows
    [[outrouteslist]] = Postgrex.query!(:freeswitch, "SELECT json_agg(t) FROM (SELECT * FROM out_routes WHERE domain='#{domain}') t", []).rows
    [[ccqueueextslist]] = Postgrex.query!(:freeswitch, "SELECT json_agg(t) FROM (SELECT * FROM callcenterqueues WHERE domain='#{domain}') t", []).rows
    Logger.info "client params is #{inspect(clientparams)}"
    element(:context, %{name: "#{domain}"}, [
      element(:extension, %{name: "unloop"}, [
        element(:condition, %{field: "${unroll_loops}", expression: "^true$"}),
        element(:condition, %{field: "${sip_looped_call}", expression: "^true$"}, [
          element(:action, %{application: "deflect", data: "${destination_number}"}),
        ]),
      ]),
      element(:extension, %{name: "context_params", continue: "true"}, [
        element(:condition,[
          settimezone(clientparams),
          setlang(clientparams),
        ]),
      ]),
      element(:extension, %{name: "global", continue: "true"}, [
        element(:condition, %{field: "${call_debug}", expression: "^true$", break: "never"}, [
          element(:action, %{application: "info"}),
        ]),
        element(:condition, %{field: "${rtp_has_crypto}", expression: "^($${rtp_sdes_suites})$", break: "never"},[
          element(:action, %{application: "set", data: "rtp_secure_media=true"}),
        ]),
        element(:condition, %{field: "${endpoint_disposition}", expression: "^(DELAYED NEGOTIATION)"}),
        element(:condition, %{field: "${switch_r_sdp}", expression: "(AES_CM_128_HMAC_SHA1_32|AES_CM_128_HMAC_SHA1_80)", break: "never"},[
          element(:action, %{application: "set", data: "rtp_secure_media=true"}),
        ]),
      ]),
      element(:extension, %{name: "refer"},[
        element(:condition, %{field: "${sip_refer_to}"},[element(:expression,["<![CDATA[<sip:${destination_number}@${domain_name}>]]>"])]),
        element(:condition, %{field: "${sip_refer_to}"},[
          element(:expression,["<![CDATA[<sip:(.*)@(.*)>]]>"]),
          element(:action, %{application: "set", data: "refer_user=$1"}),
          element(:action, %{application: "set", data: "refer_domain=$2"}),
          element(:action, %{application: "info"}),
          element(:action, %{application: "brigde", data: "sofia/${use_profile}/${refer_user}@${refer_domain}"}),
        ]),
      ]),
      element(:extension, %{name: "shout"},[
        element(:condition, %{field: "destination_number", expression: "^5500$"},[
          element(:action, %{application: "set", data: "domain_name=#{domain}"}),
          element(:action, %{application: "answer"}),
          element(:action, %{application: "playback", data: "shout://ep256.streamr.ru"}),
        ])
      ]),
      element(:extension, %{name: "security"},[
        element(:condition, %{field: "destination_number", expression: "^5100$"},[
          element(:action, %{application: "set", data: "domain_name=#{domain}"}),
          element(:action, %{application: "lua", data: "security.lua"}),
        ])
      ]),
      element(:extension, %{name: "esl_server_test"},[
        element(:condition, %{field: "destination_number", expression: "^6600$"},[
          element(:action, %{application: "set", data: "domain_name=#{domain}"}),
          element(:action, %{application: "socket", data: "172.16.31.211:8021 async full"}),
        ])
      ]),
      getacls(acllist),
      getccs(ccqueueextslist),
      getsubscribers(subscriberslist),
      getoutroutes(outrouteslist),
    ]) |> generate
  end

  def dialplanallcontextxml(domains) do
    for doms <- domains do
      {:ok, domain} = Map.fetch(doms, "domain")
      Logger.info "dialplan all context current domain is: #{domain}"
      Logger.info "dialplansinglecontextxml"
      [[clientparams]] = Postgrex.query!(:accparams, "SELECT json_agg(t) FROM (SELECT * FROM account_params WHERE domain='#{domain}') t", []).rows
      [[acllist]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM address WHERE domain='#{domain}') t", []).rows
      [[subscriberslist]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT * FROM subscriber WHERE domain='#{domain}') t", []).rows
      [[outrouteslist]] = Postgrex.query!(:freeswitch, "SELECT json_agg(t) FROM (SELECT * FROM out_routes WHERE domain='#{domain}') t", []).rows
      [[ccqueueextslist]] = Postgrex.query!(:freeswitch, "SELECT json_agg(t) FROM (SELECT * FROM callcenterqueues WHERE domain='#{domain}') t", []).rows
      Logger.info "client params is #{inspect(clientparams)}"
      element(:context, %{name: "#{domain}"}, [
        element(:extension, %{name: "unloop"}, [
          element(:condition, %{field: "${unroll_loops}", expression: "^true$"}),
          element(:condition, %{field: "${sip_looped_call}", expression: "^true$"}, [
            element(:action, %{application: "deflect", data: "${destination_number}"}),
          ]),
        ]),
        element(:extension, %{name: "context_params", continue: "true"}, [
          element(:condition,[
            settimezone(clientparams),
            setlang(clientparams),
          ]),
        ]),
        element(:extension, %{name: "global", continue: "true"}, [
          element(:condition, %{field: "${call_debug}", expression: "^true$", break: "never"}, [
            element(:action, %{application: "info"}),
          ]),
          element(:condition, %{field: "${rtp_has_crypto}", expression: "^($${rtp_sdes_suites})$", break: "never"},[
            element(:action, %{application: "set", data: "rtp_secure_media=true"}),
          ]),
          element(:condition, %{field: "${endpoint_disposition}", expression: "^(DELAYED NEGOTIATION)"}),
          element(:condition, %{field: "${switch_r_sdp}", expression: "(AES_CM_128_HMAC_SHA1_32|AES_CM_128_HMAC_SHA1_80)", break: "never"},[
            element(:action, %{application: "set", data: "rtp_secure_media=true"}),
          ]),
        ]),
        element(:extension, %{name: "refer"},[
          element(:condition, %{field: "${sip_refer_to}"},[element(:expression,["<![CDATA[<sip:${destination_number}@${domain_name}>]]>"])]),
          element(:condition, %{field: "${sip_refer_to}"},[
            element(:expression,["<![CDATA[<sip:(.*)@(.*)>]]>"]),
            element(:action, %{application: "set", data: "refer_user=$1"}),
            element(:action, %{application: "set", data: "refer_domain=$2"}),
            element(:action, %{application: "info"}),
            element(:action, %{application: "brigde", data: "sofia/${use_profile}/${refer_user}@${refer_domain}"}),
          ]),
        ]),
        getacls(acllist),
        getccs(ccqueueextslist),
        getsubscribers(subscriberslist),
        getoutroutes(outrouteslist),
      ]) |> generate
    end
  end

  # def getivrs do

  # end

  def getccs(cclists) do
    if cclists do
      for cclist <- cclists do
        {:ok, name} = Map.fetch(cclist, "name")
        {:ok, domain} = Map.fetch(cclist, "domain")
        {:ok, operatorext} = Map.fetch(cclist, "operatorext")
        {:ok, positionannounce} = Map.fetch(cclist, "positionannounce")
        if positionannounce == true do
          if operatorext do
            element(:extension, %{name: "cc_#{name}@#{domain}"}, [
              element(:condition, %{field: "destination_number", expression: "^cc_#{name}@#{domain}$"}, [
                element(:action, %{application: "set", data: "hangup_after_bridge=true"}),
                element(:action, %{application: "set", data: "result=${luarun(callcenter-announce-position.lua ${uuid} #{name}@#{domain} 10000)}"}),
                element(:action, %{application: "callcenter", data: "#{name}@#{domain}"}),
                element(:action, %{application: "ring_ready"}),
                element(:action, %{application: "transfer", data: "#{operatorext} XML #{domain}"}),
                element(:action, %{application: "hangup"}),
              ]),
            ]) |> generate
          else
            element(:extension, %{name: "cc_#{name}@#{domain}"}, [
              element(:condition, %{field: "destination_number", expression: "^cc_#{name}@#{domain}$"}, [
                element(:action, %{application: "set", data: "hangup_after_bridge=true"}),
                element(:action, %{application: "set", data: "result=${luarun(callcenter-announce-position.lua ${uuid} #{name}@#{domain} 10000)}"}),
                element(:action, %{application: "callcenter", data: "#{name}@#{domain}"}),
                element(:action, %{application: "hangup"}),
              ]),
            ]) |> generate
          end
        else
          if operatorext do
            element(:extension, %{name: "cc_#{name}@#{domain}"}, [
              element(:condition, %{field: "destination_number", expression: "^cc_#{name}@#{domain}$"}, [
                element(:action, %{application: "set", data: "hangup_after_bridge=true"}),
                element(:action, %{application: "callcenter", data: "#{name}@#{domain}"}),
                element(:action, %{application: "ring_ready"}),
                element(:action, %{application: "transfer", data: "#{operatorext} XML #{domain}"}),
                element(:action, %{application: "hangup"}),
              ]),
            ]) |> generate
          else
            element(:extension, %{name: "cc_#{name}@#{domain}"}, [
              element(:condition, %{field: "destination_number", expression: "^cc_#{name}@#{domain}$"}, [
                element(:action, %{application: "set", data: "hangup_after_bridge=true"}),
                element(:action, %{application: "callcenter", data: "#{name}@#{domain}"}),
                element(:action, %{application: "hangup"}),
              ]),
            ]) |> generate
          end
        end
      end
    else
      element(:extension) |> generate
    end
  end

  def settimezone(tzparams) do
    if tzparams != nil do
      for tz <- tzparams do
        {:ok, timezone} = Map.fetch(tz, "timezone")
        element(:action, %{application: "set", data: "timezone=#{timezone}"}) |> generate
      end
    else
      element(:action, %{application: "set", data: "timezone=Europe/Moscow"}) |> generate
    end
  end

  def setlang(langparams) do
    if langparams != nil do
      for lg <- langparams do
        {:ok, lang} = Map.fetch(lg, "lang")
        if lang == "en" do
          element(:action, %{application: "set", data: "sound_prefix=/usr/share/freeswitch/sounds/en/us/callie"}) |> generate
        end
        if lang == "ru" do
          element(:action, %{application: "set", data: "sound_prefix=/usr/share/freeswitch/sounds/ru/RU/vika"}) |> generate
        end
      end
    else
      element(:action, %{application: "set", data: "sound_prefix=/usr/share/freeswitch/sounds/ru/RU/vika"}) |> generate
    end
  end

  def getacls(acls) do
    if acls != nil do
      for acl <- acls do
        {:ok, ip} = Map.fetch(acl, "ip")
        {:ok, domain} = Map.fetch(acl, "domain")
        element(:extension, %{name: "from_acl_#{ip}"},[
          element(:condition, %{field: "${sip_h_X-AUTH-IP}", expression: "^#{ip}$"}),
          element(:condition, %{field: "destination_number", expression: "^(.*)$"},[
            element(:action, %{application: "set", data: "sip_from_host=#{domain}"}),
            element(:action, %{application: "transfer", data: "${destination_number} XML #{domain}"})
          ]),
        ]) |>generate
      end
    else
      element(:extension) |>generate
    end
  end
  def getsubscribers(subs) do
    Logger.info "subs list is #{inspect(subs)}"
    if subs != nil do
      for sub <- subs do
        {:ok, cidnum} = Map.fetch(sub, "cidnum")
        #{:ok, username} = Map.fetch(sub, "username")
        {:ok, domain} = Map.fetch(sub, "domain")
        {:ok, ringback} = Map.fetch(sub, "ringback")
        element(:extension, %{name: "#{cidnum}"},[
          element(:condition, %{field: "destination_number", expression: "^(#{cidnum})$"},[
            element(:action, %{application: "export", data: "dialed_extension=$1"}),
            element(:action, %{application: "set", data: "#{ringback}"}),
            element(:action, %{application: "set", data: "transfer_ringback=$${hold_music}"}),
            element(:action, %{application: "set", data: "hangup_after_bridge=true"}),
            element(:action, %{application: "set", data: "continue_on_fail=true"}),
            element(:action, %{application: "set", data: "domain_name=#{domain}"}),
            element(:action, %{application: "bridge", data: "user/#{cidnum}@${domain_name}"}),
            #element(:action, %{application: "bridge", data: "${sofia_contact(sipinterface_1/#{username}@{domain_name})}"}),
            element(:action, %{application: "answer"}),
            element(:action, %{application: "sleep", data: "1000"}),
            element(:action, %{application: "bridge", data: "loopback/app=voicemail:default ${domain_name} ${dialed_extension}"})
          ]),
        ]) |> generate
      end
    else
      element(:extension) |> generate
    end
  end

  def getoutroutes(routes) do
    Logger.info "routes list is #{inspect(routes)}"
    if routes != nil do
      for route <- routes do
        {:ok, callerid} = Map.fetch(route, "callerid")
        {:ok, prefix} = Map.fetch(route, "prefix")
        {:ok, expression} = Map.fetch(route, "expression")
        {:ok, strip} = Map.fetch(route, "strip")
        {:ok, privacy} = Map.fetch(route, "privacy")
        {:ok, gateway} = Map.fetch(route, "gateway")
        {:ok, domain} = Map.fetch(route, "domain")
        Logger.info "gw is #{gateway}"
        [[gwcallerids]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT DISTINCT ON(name) * FROM registrant WHERE binding_uri~'^.*@#{domain}:.*' AND name='#{gateway}' AND state='0') t", []).rows
        Logger.info "callerids list is #{inspect(gwcallerids)}"
        if privacy do
          if prefix do
            element(:extension, %{name: "#{gateway}_#{domain}"},[
              element(:condition, %{field: "${effective_caller_id_number}", expression: "^#{callerid}$"}),
              element(:condition, %{field: "destination_number", expression: "^#{prefix}#{expression}$"},[
                getgwcalleridnum(gwcallerids),
                getgwcalleridname(gwcallerids),
                element(:action, %{application: "privacy", data: "full"}),
                element(:action, %{application: "set", data: "sip_h_Privacy=id"}),
                element(:action, %{application: "set", data: "privacy=yes"}),
                element(:action, %{application: "export", data: "sip_h_X-SIPProvider=#{gateway}"}),
                element(:action, %{application: "export", data: "${sip_from_host}=#{domain}"}),
                element(:action, %{application: "export", data: "nolocal:${sip_from_host}=#{domain}"}),
                getgwstrip(prefix,strip,domain),
              ]),
            ]) |> generate
          else
            element(:extension, %{name: "#{gateway}_#{domain}"},[
              element(:condition, %{field: "${effective_caller_id_number}", expression: "^#{callerid}$"}),
              element(:condition, %{field: "destination_number", expression: "^#{expression}$"},[
                getgwcalleridnum(gwcallerids),
                getgwcalleridname(gwcallerids),
                element(:action, %{application: "privacy", data: "full"}),
                element(:action, %{application: "set", data: "sip_h_Privacy=id"}),
                element(:action, %{application: "set", data: "privacy=yes"}),
                element(:action, %{application: "export", data: "sip_h_X-SIPProvider=#{gateway}"}),
                element(:action, %{application: "export", data: "${sip_from_host}=#{domain}"}),
                element(:action, %{application: "export", data: "nolocal:${sip_from_host}=#{domain}"}),
                getgwstrip(strip,domain),
              ]),
            ]) |> generate
          end
        else
          if prefix do
            element(:extension, %{name: "#{gateway}_#{domain}"},[
              element(:condition, %{field: "${effective_caller_id_number}", expression: "^#{callerid}$"}),
              element(:condition, %{field: "destination_number", expression: "^#{prefix}#{expression}$"},[
                getgwcalleridnum(gwcallerids),
                getgwcalleridname(gwcallerids),
                element(:action, %{application: "export", data: "sip_h_X-SIPProvider=#{gateway}"}),
                element(:action, %{application: "export", data: "${sip_from_host}=#{domain}"}),
                element(:action, %{application: "export", data: "nolocal:${sip_from_host}=#{domain}"}),
                getgwstrip(prefix,strip,domain),
              ]),
            ]) |> generate
          else
            element(:extension, %{name: "#{gateway}_#{domain}"},[
              element(:condition, %{field: "${effective_caller_id_number}", expression: "^#{callerid}$"}),
              element(:condition, %{field: "destination_number", expression: "^#{expression}$"},[
                getgwcalleridnum(gwcallerids),
                getgwcalleridname(gwcallerids),
                element(:action, %{application: "export", data: "sip_h_X-SIPProvider=#{gateway}"}),
                element(:action, %{application: "export", data: "${sip_from_host}=#{domain}"}),
                element(:action, %{application: "export", data: "nolocal:${sip_from_host}=#{domain}"}),
                getgwstrip(strip,domain),
              ]),
            ]) |> generate
          end
        end
      end
    else
      element(:extension) |> generate
    end
  end

  def getgwcalleridnum(gwcidnums) do
    if gwcidnums != nil do
      for gwcidnum <- gwcidnums do
        {:ok, username} = Map.fetch(gwcidnum, "username")
        element(:action, %{application: "set", data: "effective_caller_id_number=#{username}"}) |> generate
      end
    else
      element(:action) |> generate
    end
  end

  def getgwcalleridname(gwcidnames) do
    if gwcidnames != nil do
      for gwcidname <- gwcidnames do
        {:ok, username} = Map.fetch(gwcidname, "username")
        element(:action, %{application: "set", data: "effective_caller_id_name=#{username}"}) |> generate
      end
    else
      element(:action) |> generate
    end
  end

  def getgwstrip(stripnumcount,domain) do
    if stripnumcount do
      element(:action, %{application: "bridge", data: "sofia/sipinterface_2/${destination_number:#{stripnumcount}}@#{domain}:5080"}) |> generate
    else
      element(:action, %{application: "bridge", data: "sofia/sipinterface_2/${destination_number}@#{domain}:5080"}) |> generate
    end
  end

  def getgwstrip(prefix,stripnumcount,domain) do
    if prefix do
      if stripnumcount do
        element(:action, %{application: "bridge", data: "sofia/sipinterface_2/#{prefix}${destination_number:#{stripnumcount}}@#{domain}:5080"}) |> generate
      else
        element(:action, %{application: "bridge", data: "sofia/sipinterface_2/#{prefix}${destination_number}@#{domain}:5080"}) |> generate
      end
    else
      if stripnumcount do
        element(:action, %{application: "bridge", data: "sofia/sipinterface_2/${destination_number:#{stripnumcount}}@#{domain}:5080"}) |> generate
      else
        element(:action, %{application: "bridge", data: "sofia/sipinterface_2/${destination_number}@#{domain}:5080"}) |> generate
      end
    end
  end

  def dialplanpubliccontextxml() do
    [[domains]] = Postgrex.query!(:opensips, "SELECT json_agg(t) FROM (SELECT domain FROM domain) t", []).rows
    if domains != nil do
      element(:context, %{name: "params"}, [
        element(:extension, %{name: "unloop"}, [
          element(:condition, %{field: "${unroll_loops}", expression: "^true$"}),
          element(:condition, %{field: "${sip_looped_call}", expression: "^true$"}, [
            element(:action, %{application: "deflect", data: "${destination_number}"}),
          ]),
        ]),
        element(:extension, %{name: "global", continue: "true"}, [
          element(:condition, %{field: "${call_debug}", expression: "^true$", break: "never"}, [
            element(:action, %{application: "info"}),
          ]),
          element(:condition, %{field: "${rtp_has_crypto}", expression: "^($${rtp_sdes_suites})$", break: "never"},[
            element(:action, %{application: "set", data: "rtp_secure_media=true"}),
          ]),
          element(:condition, %{field: "${endpoint_disposition}", expression: "^(DELAYED NEGOTIATION)"}),
          element(:condition, %{field: "${switch_r_sdp}", expression: "(AES_CM_128_HMAC_SHA1_32|AES_CM_128_HMAC_SHA1_80)", break: "never"},[
            element(:action, %{application: "set", data: "rtp_secure_media=true"}),
          ]),
        ]),
        indids(domains),
      ]) |> generate
    else
      element(:result,%{result: "not found"}) |> generate
    end
  end

  def indids(indomainsdids) do
    if indomainsdids != nil do
      for indomain <- indomainsdids do
        {:ok, domain} = Map.fetch(indomain, "domain")
        [[inrouteslist]] = Postgrex.query!(:freeswitch, "SELECT json_agg(t) FROM (SELECT * FROM in_routes WHERE domain='#{domain}') t", []).rows
        if inrouteslist != nil do
          for inroute <- inrouteslist do
            {:ok, did} = Map.fetch(inroute, "did")
            {:ok, domain} = Map.fetch(inroute, "domain")
            {:ok, label} = Map.fetch(inroute, "label")
            {:ok, application} = Map.fetch(inroute, "application")
            {:ok, routeto} = Map.fetch(inroute, "routeto")
            {:ok, did} = Map.fetch(inroute, "did")
            element(:extension, %{name: "#{did}_#{domain}"},[
              element(:condition, %{field: "destination_number", expression: "^#{did}$"},[
                element(:action, %{application: "set", data: "domain_name=#{domain}"}),
                element(:action, %{application: "set", data: "sip_from_host=#{domain}"}),
                element(:action, %{application: "set", data: "hangup_after_bridge=true"}),
                element(:action, %{application: "set", data: "sip_exclude_contact=${network_addr}"}),
                element(:action, %{application: "export", data: "line_number=#{did}"}),
                element(:action, %{application: "export", data: "nolocal:line_number=#{did}"}),
                indiddo(application,routeto,domain),
              ]),
            ]) |> generate
          end
        else
          element(:extension) |> generate
        end
      end
    else
      element(:extension) |> generate
    end
  end

  def indiddo(app,routeto,dom) do
    Logger.info "app is #{app}"
    if app == "bridge" do
      element(:condition,[
        element(:action, %{application: "ring_ready"}),
        element(:action, %{application: "transfer", data: "#{routeto} XML #{dom}"}),
      ]) |> generate
    else
      if app == "ivr" do
        element(:condition,[
          element(:action, %{application: "ring_ready"}),
          element(:action, %{application: "transfer", data: "ivr_#{routeto}@#{dom} XML #{dom}"}),
        ]) |> generate
      else
        if app == "conference" do
          element(:condition,[
            element(:action, %{application: "ring_ready"}),
            element(:action, %{application: "conference", data: "#{routeto}-#{dom}@video-mcu-stereo"})
          ]) |> generate
        else
          if app == "voicemail" do
            element(:condition,[
              element(:action, %{application: "ring_ready"}),
              element(:action, %{application: "transfer", data: "#{dom} #{dom} #{routeto}"}),
            ]) |> generate
          else
            if app == "callcenter" do
              element(:condition,[
                element(:action, %{application: "ring_ready"}),
                element(:action, %{application: "transfer", data: "cc_#{routeto}@#{dom} XML #{dom}"}),
              ]) |> generate
            # else
            #   if app == "fax" do
            #     element(:condition,[
            #       element(:action, %{application: "ring_ready"}),
            #       element(:action, %{application: "transfer", data: "#{routeto} XML #{dom}"})
            #     ]) |> generate
            #   end
            end
          end
        end
      end
    end
  end

end
