module Factories
  def build_tune(state: :playing, name: "Aurora", artist: "Phoenix", album: "Bankrupt!")
    { state: state, name: name, artist: artist, album: album }
  end

  def build_config(global: {}, profiles: {})
    { "global" => global, "profiles" => profiles }
  end

  def build_callback_params(code: "auth-code", state: "state", error: nil)
    params = {}
    params["code"] = code unless code.nil?
    params["state"] = state unless state.nil?
    params["error"] = error unless error.nil?
    params
  end

  def build_slack_auth_response(team: "Phoenix HQ", user: "efmcuiti", ok: true)
    {
      "ok" => ok,
      "url" => "https://#{team.downcase.gsub(/\s+/, "-")}.slack.com/",
      "team" => team,
      "user" => user,
      "team_id" => "T0123456789",
      "user_id" => "U0123456789"
    }
  end
end
