# frozen_string_literal: true

module RubyLLM
  # Manages model aliases, allowing users to reference models by simpler names
  # that map to specific model versions across different providers.
  #
  # Aliases are defined in aliases.json and follow the format:
  #   {
  #     "simple-name": {
  #       "provider1": "specific-version-for-provider1",
  #       "provider2": "specific-version-for-provider2"
  #     }
  #   }
  class Aliases
    class << self
      # Resolves a model ID to its provider-specific version
      #
      # @param model_id [String] the model identifier or alias
      # @param provider_slug [String, Symbol, nil] optional provider to resolve for
      # @return [String] the resolved model ID or the original if no alias exists
      def resolve(model_id, provider = nil)
        if provider
          @runtime_aliases.dig(provider.to_s, model_id) || aliases.dig(model_id, provider.to_s) || model_id
        else
          # Get native provider's version
          aliases[model_id]&.values&.first || model_id
        end
      end

      # Returns the loaded aliases mapping
      # @return [Hash] the aliases mapping
      def aliases
        @aliases ||= load_aliases
      end

      # Adds extra runtime-only aliases for a specific provider
      # @return [Hash] the updated aliases mapping
      def register_runtime_aliases(provider, extra_aliases)
        # NOTE: not persisted; will be gone after app restart
        @runtime_aliases ||= {}
        @runtime_aliases[provider.to_s] = extra_aliases
      end

      # Loads aliases from the JSON file
      # @return [Hash] the loaded aliases
      def load_aliases
        file_path = File.expand_path('aliases.json', __dir__)
        if File.exist?(file_path)
          JSON.parse(File.read(file_path))
        else
          {}
        end
      end

      # Reloads aliases from disk
      # @return [Hash] the reloaded aliases
      def reload!
        @aliases = load_aliases
      end
    end
  end
end
