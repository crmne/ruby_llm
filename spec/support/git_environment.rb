# frozen_string_literal: true

# Git exports GIT_DIR, GIT_INDEX_FILE, and related variables to its hooks.
# Git commands meant for a temporary repository act on the checkout running
# the suite unless they are cleared.
module GitEnvironment
  module_function

  def cleared
    ENV.keys.grep(/\AGIT_/).to_h { |name| [name, nil] }
  end

  def without
    saved = ENV.slice(*cleared.keys)
    saved.each_key { |name| ENV.delete(name) }
    yield
  ensure
    ENV.update(saved) if saved
  end
end
