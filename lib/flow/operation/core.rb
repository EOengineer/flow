# frozen_string_literal: true

# Operations take a state as input.
module Flow
  module Operation
    module Core
      extend ActiveSupport::Concern

      included do
        attr_reader :state

        delegate :state_proxy_class, to: :class
      end

      class_methods do
        def state_proxy_class
          @state_proxy_class ||= Class.new(StateProxy).tap do |proxy_class|
            delegate_method_names = _state_writers.map { |method_name| "#{method_name}=" } + _state_readers
            proxy_class.delegate(*delegate_method_names, to: :state) if delegate_method_names.any?
          end
        end

        def introspected_state_class
          Class.new(StateBase).tap do |state_class|
            [*_state_readers, *_state_writers, *_state_accessors].each do |method_name|
              state_class.__send__(:attr_accessor, method_name)
            end
          end
        end
      end

      def initialize(state)
        @state = state_proxy_class.new(state)
      end
    end
  end
end
