module Factories
  def build_tune(state: :playing, name: "Aurora", artist: "Phoenix", album: "Bankrupt!")
    { state: state, name: name, artist: artist, album: album }
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
