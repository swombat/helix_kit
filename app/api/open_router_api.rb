require "openai"

class OpenRouterApi

  def initialize(access_token: Rails.application.credentials.dig(:ai, :openrouter, :api_token) || "<OPENROUTER_API_KEY>")
    @access_token = access_token
    @client = OpenAI::Client.new(
      uri_base: "https://openrouter.ai/api/v1",
      access_token: @access_token,
      request_timeout: 20,
      log_errors: true
    )
  end

  def models
    [
      "openai/gpt-5",
      "openai/gpt-5-mini",
      "openai/gpt-5-nano",
      "openai/gpt-5-chat",
      "anthropic/claude-opus-4.6",
      "anthropic/claude-opus-4.5",
      "anthropic/claude-sonnet-4.5",
      "anthropic/claude-3.7-sonnet",
      "anthropic/claude-3.7-sonnet:thinking",
      "anthropic/claude-opus-4",
      "anthropic/claude-sonnet-4",
      "google/gemini-2.5-flash-preview-09-2025",
      "google/gemini-2.5-pro",
      "x-ai/grok-4-fast",
      "x-ai/grok-code-fast-1",
      "x-ai/grok-4",
      "openai/o1",
      "openai/o3",
      "openai/o4-mini",
      "openai/o4-mini-high",
      "openai/gpt-4o-mini",
      "openai/gpt-4.1",
      "openai/gpt-4.1-mini",
      "openai/chatgpt-4o-latest",
      "qwen/qwen3-max",
      "moonshotai/kimi-k2-0905"
    ]
  end

  def is_o_model?(params)
    params[:model].include?("o1") || params[:model].include?("o3") || params[:model].include?("o4")
  end

  def get_response(params:, stream_proc: nil, stream_response_type: :text)
    params = params.transform_keys(&:to_sym)
    incremental_response = ""
    raise "Unsupported stream response type #{stream_response_type}" unless [ :text, :json ].include?(stream_response_type)
    response = {
      usage: {
        input_tokens: OpenAI.rough_token_count("#{params[:system]} #{params[:user]}"),
        output_tokens: 0
      },
      id: nil
    }

    json_stack = ""

    json_matches = []

    parameters = {
      model: params[:model] || @model,
      messages: []
    }

    parameters[:temperature] ||= 0.7 unless is_o_model?(params)

    if stream_proc.present?
      parameters[:stream] = proc do |chunk, _bytesize|
        response[:id] = chunk["id"] if response[:id].nil? && chunk["id"].present?
        delta = chunk.dig("choices", 0, "delta", "content")
        next if delta.nil?
        incremental_response += delta
        if stream_response_type == :text
          response[:usage][:output_tokens] += 1
          stream_proc.call(incremental_response, delta)
        elsif stream_response_type == :json
          json_stack += delta
          begin
            if json_stack.strip.include?("}")
              matches = json_stack.scan(/\{(?:[^{}]|\g<0>)*\}/)
              matches.reject { |match| json_matches.include?(match) }.each do |match|
                stream_proc.call(JSON.parse(match))
                # json_stack.gsub!(match, "")
                json_matches << match
              end
            end
          rescue StandardError => e
            log(e, json_stack, incremental_response, delta)
          ensure
            # json_stack.clear if json_stack.strip.include?("}")
          end
        end
      end
    end

    parameters[:messages] << { role: "system", content: params[:system] } if params[:system]
    parameters[:messages] << { role: "user", content: params[:user] } if params[:user]

    parameters[:messages] = params[:messages] if params[:messages]

    if stream_proc.present?
      @client.chat(parameters: parameters)
      response["choices"] = [ { "index": 0, "message": {
          "role": "assistant",
          "content": incremental_response
        },
        "finish_reason": "stop" } ]

      response = JSON.parse(response.to_json) # Get all keys to be strings
    else
      response = @client.chat(parameters: parameters)
    end

    # Return response in OpenAI format (which OpenRouter already uses)
    JSON.parse(response.to_json)
  end

  def log(error, json_stack, incremental_response, delta)
    logger = Logger.new($stdout)
    logger.formatter = proc do |_severity, _datetime, _progname, msg|
      "\033[31mOpenAI JSON Error (spotted in OpenRouterApi): #{msg}\n\033[0m"
    end
    logger.error("#{error}\njson_stack: #{json_stack}\nincremental_response: #{incremental_response}\ndelta: #{delta}")
  end

end
