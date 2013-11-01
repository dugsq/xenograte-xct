# Copyright Nodally Technologies Inc. 2013
# Licensed under the Open Software License version 3.0
# http://opensource.org/licenses/OSL-3.0

# This node will take defaults for mail account from config, if present.
# It expects them in each message, if not in config.
# It will also set defaults for template to use, subject, and recipient
# from config.
# The message should override or provide any values missing from the config,
# and can contain tokens to be replaced in the template for each message.
#
# Keys accepted in the config are as follows:
#
# user_name
# passwd
# reply_to
# recipients [{ name, email }]
# templates {name => { subject, text, html }}
# attachments [ file_path ]
#
# @version 0.2.0
#
require 'gmail'
require 'csv'

class GmailSenderNode
  include XenoCore::NodeBase

  # Initialization of instance variables and checking of config data will be done in this method.
  # @return []
  def startup
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    do_debug("#{mctx} - config: #{@config.inspect}")

    @user_name = @config[:user_name]
    @passwd = @config[:passwd]
    @reply_to = @config[:reply_to]
    @recipients = @config[:recipients] || []
    @templates = @config[:templates] || {}
    @attachments = @config[:attachments] || {}

    # Verify presence of any template files from config
    @templates.each do |name, template|
      if template
        if template[:text_file] && ( !template[:text] || template[:html].nil? )
          text_path = File.join(Dir.pwd, template[:text_file])
          if File.readable? text_path
            template[:text] = File.read(text_path)
            do_debug("Text part read for template #{name}") if @debug
          end
        end
        if template[:html_file] && ( !template[:html] || template[:html].nil? )
          html_path = File.join(Dir.pwd, template[:html_file])
          if File.readable? html_path
            template[:html] = File.read(html_path)
            do_debug("HTML part read for template #{name}") if @debug
          end
        end
      end
    end
  end

  # Triggers configuration and sending of email messages.
  # Options in message.context can override config options.
  # @param msg [XenoCore::Message]
  def process_message(msg)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    cfg = configure_email(msg)
    do_debug("#{mctx} - cfg out: #{cfg.inspect}")
    if !cfg.nil?

      gmail = Gmail.connect(cfg[:user_name], cfg[:passwd])

      cfg[:recipients].each do |recp|
        email = parse_template(cfg) if cfg[:tokens].is_a?(Hash)
        status = gmail.deliver do
          to recp['email']
          subject email[:subject]
          text_part do
            body email[:text]
          end
          html_part do
            content_type 'text/html; charset=UTF-8'
            body email[:html]
          end
        end
        write_to_children(msg)
        do_debug("mail object returned:\n\n#{status.inspect}")
      end
    end
  end

  # Sets template to use for message output. Looks for template key in context
  # to look up or override template from config. Falls back to default.
  # @param msg [XenoCore::Message]
  # @return [Hash] Template to use for message.
  def set_template(msg)
    mctx = "#{self.class}.#{__method__}()"
    errors = []
    template = nil
    # Check msg for template
    if msg.context.is_a?(Hash) && (msg.context[:template] || msg.context['template'])
      tmpl = msg.context[:template] || msg.context['template']
    end
    if tmpl.is_a?(String)
      # Assume we were passed the name of the template from config to use
      if @templates[tmpl.to_sym]
        template = deep_copy(@templates[tmpl.to_sym])
        template[:name] = tmpl unless template[:name]
      else # template named, but not found
        errors << "Template #{tmpl} not found in config."
      end
    elsif tmpl.is_a?(Hash)
      template = deep_copy(tmpl)
      template[:name] = "msg_template" unless template[:name]
    elsif @templates[:default].is_a?(Hash) # use default template if present
      template = deep_copy(@templates[:default])
      template[:name] = "default"
    else # template not found
      errors << "Template #{tmpl} not found, and no default template in config."
    end
    template.is_a?(Hash) ? template : errors
  end

  # Deep copy used for ensuring template hash is unique.
  # @param obj [Object] must be an object that can be serialized with Marshal.
  # @return [Object] copy of the object passed in.
  def deep_copy(obj)
    mctx = "#{self.class}.#{__method__}()"
    obj_out = Marshal.load(Marshal.dump(obj))
  end

  # Prepares an email message by comparing context and config values to determine
  # settings for email.
  # @param msg [XenoCore::Message]
  # @return [Hash] returns a hash with the settings to use for this email.
  def configure_email(msg)
    mctx = "#{self.class}.#{__method__} [#{@xenode_id}]"
    do_debug("#{mctx} message to configure: #{msg.inspect}")
    cfg = {}
    errors = []

    context = msg.context || {}
    data = msg.data

    tmpl = set_template(msg)
    do_debug("#{mctx} template set: #{tmpl.inspect}")
    if tmpl.is_a?(Array)
      errors + tmpl
    else
      cfg[:user_name] = context['user_name'] || @user_name
      cfg[:passwd] = context['passwd'] || @passwd
      cfg[:reply_to] = context['reply_to'] || @reply_to
      cfg[:recipients] = context['recipients'] || @recipients
      tokens = context['tokens'] || tmpl[:tokens]

      do_debug("tmpl: #{tmpl.inspect}")
      do_debug("cfg: #{cfg}")

      tname = tmpl[:name]

      cfg[:subject] = tmpl['subject'] || tmpl[:subject]

      if !cfg[:subject] || !cfg[:subject].is_a?(String)
        errors << "Subject not found for template #{tname}"
      end

      if data && data.is_a?(Hash) && data['text']
        cfg[:text] = data['text']
      else
        cfg[:text] = tmpl[:text]
      end

      if !cfg[:text] || !cfg[:text].is_a?(String)
        errors << "Text part not found for template #{tname}"
      end

      if data && data.is_a?(Hash) && data['html']
        cfg[:html] = data['html']
      else
        cfg[:html] = tmpl[:html]
      end

      if !cfg[:html] || !cfg[:html].is_a?(String)
        errors << "HTML part not found for template #{tname}"
      end
      if tokens && tokens.is_a?(Hash)
        cfg[:tokens] = {}
        tokens.each do |token, value|
          begin
            cfg[:tokens][token] = eval(value)
          rescue
            errors << "Error resolving data for token: #{token}"
          end
        end
      end
    end
    if errors.length > 0
      err_msg = "Message Failed: Errors configuring mail: #{errors.inspect}\n\n"
      do_debug("#{mctx} - #{err_msg} \n#{e.inspect} #{e.backtrace}")
      #failed_message(msg[:msg_id], err_msg)
      cfg = nil
    end
    cfg
  rescue => e
    catch_error("#{mctx} - #{e.inspect} #{e.backtrace}")
  end

  # Resolves tokens in template from :tokens hash in cfg param.
  # @param cfg [Hash] Final configuration options for message.
  # @return [Hash] Returns input cfg hash with templates rendered.
  def parse_template(cfg)
    email = {}
    email[:text] = cfg[:text]
    email[:html] = cfg[:html]
    email[:subject] = cfg[:subject]

    cfg[:tokens].each do|key, value|
      value = value.to_s
      pattern = "\{\{#{key}\}\}"
      email[:text] = email[:text].gsub!(pattern, value)
      email[:html] = email[:html].gsub!(pattern, value)
    end
    email
  end
end
