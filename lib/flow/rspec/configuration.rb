# frozen_string_literal: true

::RSpec.configure do |config|
  config.include Flow::CustomMatchers
  config.include Flow::RSpec::DSL
end
