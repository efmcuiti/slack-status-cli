module Factories
  def build_tune(state: :playing, name: "Aurora", artist: "Phoenix", album: "Bankrupt!")
    { state: state, name: name, artist: artist, album: album }
  end
end
