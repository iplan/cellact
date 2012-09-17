require 'uuidtools'

module Cellact

  # NOTE: sender_number is always mandatory. if you want to be this gateway ONE way, provide non existing sender number, like 03-1234567
  # NOTE: sender_name is not support on all networks, on those that it is, the sms will be automatically one way
  class Gateway
    attr_reader :username, :password, :company, :cellact_urls, :time_zone, :logger

    attr_reader :sms_sender, :delivery_notification_parser, :sms_replies_parser

    # Create new gateway with given +username+ and +password+
    # +config+ hash with the following keys:
    #   * +username+ - gateway user name
    #   * +password - gateway password
    #   * cellact_urls - api urls to communication with cellact
    # These keys will be used when sending sms messages
    def initialize(config)
      [:username, :password, :company].each do |attr|
        raise ArgumentError.new("Missing required attribute #{attr}") if config[attr].blank?
      end
      @logger = Logging.logger[self.class]

      @username = config[:username]
      @password = config[:password]
      @company = config[:company]

      @cellact_urls = {:send_sms => 'http://la1.cellactpro.com/SendSms.asmx?WSDL'}.update(config[:cellact_urls] || {})
      @time_zone = config[:time_zone] || 'Jerusalem'

      @sms_sender = SmsSender.new(self)
      @delivery_notification_parser = DeliveryNotificationsParser.new(self)
      @sms_replies_parser = SmsRepliesParser.new(self)
    end

    # send +text+ string to the +phones+ array of phone numbers
    # +options+ - is a hash of optional configuration that can be passed to sms sender:
    #  * +sender_name+ - sender name that will override gateway sender name
    #  * +sender_number+ - sender number that will override gateway sender number
    # Returns response OpenStruct that contains:
    #  * +message_id+ - message id string. You must save this id if you want to receive delivery notifications via push/pull
    #  * +status+ - gateway status of sms send
    #  * +number_of_recipients+ - number of recipients the message was sent to
    def send_sms(text, phones, options = {})
      @sms_sender.send_sms(text, phones, options)
    end

    def on_delivery_notification_http_push(params)
      @delivery_notification_parser.http_push(params)
    end

    def on_sms_reply_http_push(params)
      @sms_replies_parser.http_push(params)
    end

  end

end

