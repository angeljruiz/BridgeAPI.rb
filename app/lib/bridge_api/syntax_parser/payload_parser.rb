# frozen_string_literal: true

module BridgeApi
  module SyntaxParser
    # This class parses user defined headers & payloads into the values we expect
    # to send to the outbound service.
    #
    # Example:
    #
    # ```ruby
    # custom_user_payload = {
    #   'hello' => '$payload.top_level_key',
    #   'environment_variable' => '$env.API_KEY',
    #   'did_you' => '$payload.nested_key_1.nested_key_2.nested_key_3'
    # }
    #
    # incoming_payload_from_service_a = {
    #   'top_level_key' => 'world',
    #   'nested_key_1' => {
    #     'nested_key_2' => {
    #       'nested_key_3' => 'make it!'
    #     }
    #   }
    # }
    #
    # bridge = Bridge.where(user_id: @current_user.id)
    #
    # payload_parser = BridgeApi::SyntaxParser::PayloadParser.new bridge.environment_variables
    #
    # payload_parser.parse(
    #  incoming_payload_from_service_a,
    #  custom_user_payload
    # ) # => Hash(String, String) where $payload & $env are replaced with their respective values
    # ```
    class PayloadParser
      include EnvironmentVariables
      include Interfaces::PayloadParser

      # @param [ActiveRecord::Relation(EnvironmentVariable)] environment_variables
      def initialize(environment_variables)
        @environment_variables = environment_variables
      end

      # Parses the user's custom payload replacing any values containing `$env`
      # or `$payload` with the respective value
      #
      # @param [Hash(String, String | Hash | Array)] incoming_payload
      # @param [Hash(String, String | Hash | Array)] user_data
      #
      # @return [Hash(String, String | Hash | Array)]
      def parse(incoming_payload, user_data)
        @incoming_payload = incoming_payload
        parse_payload!(user_data)
      end

      private

      attr_reader :incoming_payload, # Inbound payload from service A
                  :environment_variables

      # Iterates through user defined payload and parse values containing `$env` or `$payload`
      #
      # @param [Hash(String, String | Hash | Array)] user_data
      #
      # @return [Hash(String, String | Hash | Array)]
      def parse_payload!(user_data)
        outbound_payload = {}
        user_data.each { |key, val| outbound_payload[key] = parse_value(val) }

        outbound_payload
      end

      # Handles parsing a value depending on its value or type.
      # Will call `parse_payload!` recursively if value is a
      # Hash or Array.
      #
      # @param [String | Hash | Array] value
      #
      # @return [String | Hash | Array]
      # rubocop:disable Metrics/MethodLength
      def parse_value(value)
        if value.include?('$env')
          fetch_environment_variable(value)
        elsif value.include?('$payload')
          fetch_payload_data(value)
        elsif value.instance_of?(Hash)
          parse_payload!(value)
        elsif value.instance_of?(Array)
          # TODO: Add support for accessing a single element
          value.map { |i| parse_payload!(i) }
        else
          value
        end
      end
      # rubocop:enable Metrics/MethodLength

      def fetch_payload_data(value)
        values = value.split('.')
        data = incoming_payload # Set data to the incoming request

        values.each_with_index do |val, idx|
          next if idx.zero? # skip the $payload

          data = data[val.to_s] || data[val.to_sym] # dig deeper into the request on each iteration
          raise ::InvalidPayloadKey if data.nil?
        end

        data
      end
    end
  end
end
