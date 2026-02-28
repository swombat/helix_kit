# frozen_string_literal: true

class Prompt

  include ActiveModel::Model

  DEFAULT_MODEL = "openai/gpt-5"
  SMART_MODEL = "openai/gpt-5"
  LIGHT_MODEL = "google/gemini-2.5-flash"
  CHAT_MODEL = "openai/gpt-5-chat"

  def initialize(model: DEFAULT_MODEL, template: nil)
    @model = map_model(model)
    @template = template
  end

  def map_model(model)
    map = {
      "4o" => "openai/chatgpt-4o-latest",
      "o1" => "openai/o1",
      "4o-mini" => "openai/gpt-4o-mini"
      }

    map.keys.include?(model) ? map[model] : model
  end

  def execute_to_string
    params = render
    provider_config = ResolvesProvider.resolve_provider(@model)

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )
    llm.with_instructions(params[:system]) if params[:system]

    retry_block do
      if block_given?
        incremental = +""
        llm.ask(params[:user]) do |chunk|
          next unless chunk.content
          incremental << chunk.content
          yield incremental, chunk.content
        end
        return incremental
      else
        response = llm.ask(params[:user])
        return response.content
      end
    end
  end

  def execute_to_json(single_object: false)
    params = render
    provider_config = ResolvesProvider.resolve_provider(@model)

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )
    llm.with_instructions(params[:system]) if params[:system]

    retry_block do
      if block_given?
        incremental = +""
        llm.ask(params[:user]) do |chunk|
          next unless chunk.content
          incremental << chunk.content
          # Try to parse accumulated JSON and yield complete objects
          begin
            json_object = JSON.parse(strip_markdown_fences(incremental))
            yield json_object
          rescue JSON::ParserError
            # Not yet a complete JSON object, continue accumulating
          end
        end
        return JSON.parse(strip_markdown_fences(incremental)) rescue incremental
      else
        response = llm.ask(params[:user])
        return JSON.parse(strip_markdown_fences(response.content))
      end
    end
  end

  def execute(output_class:, output_id:, output_property: :ai_summary, json: false)
    info "Executing #{self.class} with output class #{output_class} and id #{output_id} on property #{output_property}"

    params = render
    provider_config = ResolvesProvider.resolve_provider(@model)

    @output = output_class.constantize.find(output_id)

    llm = RubyLLM.chat(
      model: provider_config[:model_id],
      provider: provider_config[:provider],
      assume_model_exists: true
    )
    llm.with_instructions(params[:system]) if params[:system]

    retry_block do
      response_msg = llm.ask(params[:user])
      content = response_msg.content

      if json
        response = JSON.parse(strip_markdown_fences(content))
        add_json(@output, output_property, response)
      else
        @output.update(output_property => content)
        response = content
      end

      info "#{self.class}#execute response (short): #{response.inspect[0..200]}"
      return response
    end
  end

  def render(**args)
    if @template == "conversation"
      params = render_conversation(**args)
    else
      params = render_template(**args)
    end
    params[:model] = @model
    params
  end

  def render_template(**args)
    raise "Must supply a template to the Prompt constructor" if @template.nil?

    args = @args if args.empty?

    args[:model] ||= @model

    result = {}

    system_path = Rails.root.join("app", "prompts", @template, "system.prompt.erb")
    user_path = Rails.root.join("app", "prompts", @template, "user.prompt.erb")

    if File.exist?(system_path)
      system_template = ERB.new(File.read(system_path))
      result[:system] = system_template.result_with_hash(args)
    end
    if File.exist?(user_path)
      user_template = ERB.new(File.read(user_path))
      result[:user] = user_template.result_with_hash(args)
    end

    result
  end

  def render_conversation(**args)
    args = @args if args.empty?

    {
      messages: args[:conversation].messages.sort_by(&:created_at).collect { |message| { role: message.message_role, content: message.contents } }
    }
  end

  def retry_block
    tries_counter = 0

    begin
      yield
    rescue Faraday::TooManyRequestsError => e
      error "Too many requests error: #{e}"
      tries_counter += 1
      if tries_counter < 6
        sleep_time = 2**tries_counter
        info "Sleeping for #{sleep_time} seconds and trying again"
        sleep sleep_time
        info "Done - trying again"
        retry if tries_counter < 6
      end
    rescue Faraday::TimeoutError => e
      error "Timeout error (tries: #{tries_counter}): #{e}"
      tries_counter += 1
      retry if tries_counter < 3
    rescue StandardError => e
      error "StandardError: #{e.message}"
      raise e
    end
  end

  def add_json(object, property, new_object)
    if object.send(property).is_a?(Array)
      object.send("#{property}=", object.send(property) + [ new_object ])
    elsif object.send(property).is_a?(Hash)
      object.send("#{property}=", object.send(property).merge(new_object))
    end
    object.save
  end

  private

  # Strip markdown code fences (```json ... ```) that LLMs sometimes wrap around JSON responses
  def strip_markdown_fences(text)
    text.sub(/\A\s*```\w*\n/, "").sub(/\n```\s*\z/, "")
  end

end
