# frozen_string_literal: true

require 'csv'

DEFAULT_GETTER = ->(record) { Services::FetchSchema.new.call(record:) }

module Services
  class GenerateDatabase
    class << self
      include Dry::Monads[:try, :result]

      def call(input, schema_getter = DEFAULT_GETTER)
        Try do
          @database = Services::Database.new

          input.each do |record, csv_data|
            parsed_csv_data = csv_data

            schema = get_schema!(schema_getter, record)
            primary_key_name = primary_key_from(schema)

            @database.add_schema(record:, schema:)

            parsed_csv_data.each_with_index do |row_data, index|
              process_row_data!(schema, record, primary_key_name, row_data.to_h, index + 1)
            end
          end

          @database
        end.to_result
      end

      private

      def process_row_data!(schema, record, primary_key, row_data, index)
        index = if primary_key
                  validate_primary_key_exists!(primary_key, row_data)
                  row_data[primary_key]
                else
                  index
                end

        validate_data_against_schema!(schema, row_data)
        primary_key_type = schema.dig(primary_key, :type) || 'Integer'

        insert_row!(record, primary_key_type, index, row_data)
        add_indexes!(schema.except(primary_key), record, row_data, index)
      end

      def insert_row!(record, primary_key_type, index, row_data)
        @database.add_record(
          record:,
          key: parse_value!(index, primary_key_type),
          value: row_data
        )
      end

      def add_indexes!(schema, record, row_data, index)
        schema.each do |key, attributes|
          type = attributes[:type]
          value = row_data[key]

          if value.nil?
            add_index!('String', record, key, '', index)
          else
            add_index!(type, record, key, value, index)
          end
        end
      end

      def add_index!(type, record, key, value, index)
        case type
        in /Array/
          value.each do |each_value|
            each_type = type.gsub('Array[', '').gsub(']', '')
            @database.add_index(record:, paths: [key, *parse_value!(each_value, each_type)], index:)
          end
        in _
          @database.add_index(record:, paths: [key, *parse_value!(value, type)], index:)
        end
      end

      def get_schema!(schema_getter, record)
        schema_getter
          .call(record)
          .value_or { raise Errors::GenerateDatabase, "unknown '#{record}' record error" }
      end

      def parse_value!(value, type)
        Parsers::SearchValue
          .call(value:, type:)
          .value_or { raise Errors::GenerateDatabase, "provided value #{value} for type #{type} is invalid" }
      end

      def primary_key_from(schema)
        schema.select { |attr| schema.dig(attr, 'primary_key') }.keys.first
      end

      def validate_primary_key_exists!(primary_key, data)
        raise Errors::GenerateDatabase, "primary_key is not found in #{data}" if data[primary_key].nil?
      end

      def validate_data_against_schema!(schema, row_data)
        unknown_attributes = row_data.keys - schema.keys

        return if unknown_attributes.empty?

        raise Errors::GenerateDatabase, "unknown attributes #{unknown_attributes} provided"
      end
    end
  end
end
