# frozen_string_literal: true

module RubyLLM
  module Providers
    module Ollama
      # Models methods for the Ollama API integration
      module Models
        # Methods needed by Provider - must be public
        def models_url
          'api/tags'
        end

        # NOTE: Unlike other providers for well known APIs with stable model
        # offerings, the Ollama provider deals with local servers which
        # might have arbitrarily named models or even zero models installed.
        #
        # Thus, this provider can't ship hardcoded assumptions in models.json
        # and thus no Ollama models will be known at runtime, so you'll need a
        # `RubyLLM.models.refresh!` to populate your instance's models.

        def list_models
          return [] unless enabled?

          response = connection.get('api/tags') do |req|
            req.headers.merge! headers
          end

          parse_list_models_response(response, slug, capabilities)
        end

        private

        def parse_list_models_response(response, slug, capabilities) # rubocop:disable Metrics/MethodLength
          provider_aliases = {}
          list = response.body['models'] || []

          # initial pass: discover Ollama "tags"
          list.each do |model|
            base, tag = model['name'].split(':', 2)
            model['model_name_base'] = base if tag
          end

          # second pass: set aliases for models with multiple sizes
          list.group_by { |m| m['model_name_base'] }.each do |base, models|
            # given these models in the server,
            # - gemma3:27b
            # - gemma3:9b
            # then gemma3:27b will get the 'gemma3' alias since the 27b is larger in bytesize
            largest = models.max_by { |m| m['size'].to_i }
            provider_aliases[base] = largest['name']
          end
          RubyLLM::Aliases.register_runtime_aliases(slug, provider_aliases)

          # final pass: assemble
          list.map do |model|
            model_id = model['name']

            ModelInfo.new(
              id: model_id,
              # NOTE: this is date pulled into ollama, not quite date of introduction of a model
              created_at: model['modified_at'],
              display_name: model_id,
              provider: slug,
              type: capabilities.model_type(model_id),
              family: model['family'],
              context_window: capabilities.context_window_for(model_id),
              max_tokens: capabilities.max_tokens_for(model_id),
              supports_vision: capabilities.supports_vision?(model_id),
              supports_functions: capabilities.supports_functions?(model_id),
              supports_json_mode: capabilities.supports_json_mode?(model_id),
              input_price_per_million: capabilities.input_price_for(model_id),
              output_price_per_million: capabilities.output_price_for(model_id),
              metadata: {
                model_name_base: model['model_name_base'],
                byte_size: model['size']&.to_i,
                parameter_size: model.dig('details', 'parameter_size'),
                quantization_level: model.dig('details', 'quantization_level'),
                format: model.dig('details', 'format'),
                parent_model: model.dig('details', 'parent_model')
              }
            )
          end
        end
      end
    end
  end
end
