# weather_tool.rb - API integration example
require 'ruby_llm/tool'
require 'net/http'
require 'json'

module Tools
  class WeatherTool < RubyLLM::Tool
    def self.name = 'weather_tool'

    description <<~DESCRIPTION
      Retrieve comprehensive current weather information for any city worldwide using the OpenWeatherMap API.
      This tool provides real-time weather data including temperature, atmospheric conditions, humidity,
      and wind information. It supports multiple temperature units and can optionally include extended
      forecast data. The tool requires a valid OpenWeatherMap API key to be configured in the
      OPENWEATHER_API_KEY environment variable. All weather data is fetched in real-time and includes
      timestamps for accuracy verification.
    DESCRIPTION

    param :city,
          desc: <<~DESC,
            Name of the city for weather lookup. Can include city name only (e.g., 'London')
            or city with country code for better accuracy (e.g., 'London,UK' or 'Paris,FR').
            For cities with common names in multiple countries, including the country code
            is recommended to ensure accurate results. The API will attempt to find the
            closest match if an exact match is not found.
          DESC
          type: :string,
          required: true

    param :units,
          desc: <<~DESC,
            Temperature unit system for the weather data. Options are:
            - 'metric': Temperature in Celsius, wind speed in m/s, pressure in hPa
            - 'imperial': Temperature in Fahrenheit, wind speed in mph, pressure in hPa
            - 'kelvin': Temperature in Kelvin (scientific standard), wind speed in m/s
            Default is 'metric' which is most commonly used internationally.
          DESC
          type: :string,
          default: "metric",
          enum: ["metric", "imperial", "kelvin"]

    param :include_forecast,
          desc: <<~DESC,
            Boolean flag to include a 3-day weather forecast in addition to current conditions.
            When set to true, the response will include forecast data with daily high/low temperatures,
            precipitation probability, and general weather conditions for the next three days.
            This requires additional API calls and may increase response time slightly.
          DESC
          type: :boolean,
          default: false

    def execute(city:, units: "metric", include_forecast: false)
      begin
        api_key = ENV['OPENWEATHER_API_KEY']
        raise "OpenWeather API key not configured" unless api_key

        current_weather = fetch_current_weather(city, units, api_key)
        result = {
          success:   true,
          city:      city,
          current:   current_weather,
          units:     units,
          timestamp: Time.now.iso8601
        }

        if include_forecast
          forecast_data = fetch_forecast(city, units, api_key)
          result[:forecast] = forecast_data
        end

        result
      rescue => e
        {
          success:    false,
          error:      e.message,
          city:       city,
          suggestion: "Verify city name and API key configuration"
        }
      end
    end

    private

    def fetch_current_weather(city, units, api_key)
      uri = URI("https://api.openweathermap.org/data/2.5/weather")
      params = {
        q:     city,
        appid: api_key,
        units: units
      }
      uri.query = URI.encode_www_form(params)

      response = Net::HTTP.get_response(uri)
      raise "Weather API error: #{response.code}" unless response.code == '200'

      data = JSON.parse(response.body)
      {
        temperature: data['main']['temp'],
        description: data['weather'][0]['description'],
        humidity:    data['main']['humidity'],
        wind_speed:  data['wind']['speed']
      }
    end

    def fetch_forecast(city, units, api_key)
      # TODO: Implementation for forecast data
      #       Similar pattern to current weather
    end
  end
end
